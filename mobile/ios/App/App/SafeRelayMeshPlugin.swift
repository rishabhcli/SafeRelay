import AVFAudio
import Capacitor
import CoreBluetooth
import CoreLocation
import Foundation
import Network
import OSLog
import UIKit
import UserNotifications

private let meshServiceUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
private let meshPacketUUID = CBUUID(string: "12345678-1234-1234-1234-123456789ABD")
private let distressNotificationCategory = "SAFERELAY_DISTRESS"
private let viewIncidentAction = "SAFERELAY_VIEW_INCIDENT"
private let signalSoundName = UNNotificationSoundName(rawValue: "SafeRelaySignal.caf")

private struct PendingCloudSignal: Codable {
    let messageID: String
    let originDeviceID: String
    let latitude: Double
    let longitude: Double
    let statusCode: Int
    let packetTimestamp: UInt32
    let rssi: Int
    let deliveredBy: String
    let hopCount: Int
    let queuedAt: Date

    var payload: [String: Any] {
        [
            "message_id": messageID,
            "origin_device_id": originDeviceID,
            "latitude": latitude,
            "longitude": longitude,
            "status_code": statusCode,
            "packet_timestamp": Int(packetTimestamp),
            "rssi": rssi,
            "delivered_by": deliveredBy,
            "hop_count": hopCount,
        ]
    }
}

private struct CloudRelayConfiguration {
    let baseURL: URL
    let previewToken: String
    let previewCookie: String
}

private struct MeshPacketEvent {
    let bytes: [UInt8]
    let rssi: Int
    let source: String

    var dictionary: [String: Any] {
        ["bytes": bytes.map(Int.init), "rssi": rssi, "source": source]
    }
}

private struct PendingPeerWrite {
    let data: Data
    var attempts: Int = 0
}

private enum MeshPacket {
    static let currentSize = 27
    static let currentVersion: UInt8 = 1
    static let maxRelayHops: UInt8 = 5
    static let maxAge: TimeInterval = 86_400

    static func isValid(_ data: Data) -> Bool {
        (data.count == 21 || data.count == 25 || data.count == currentSize)
            && data[0] == 0xff
            && data[1] == 0xff
            && data[16] <= 5
            && (-900_000_000...900_000_000).contains(signedInteger(data, at: 8))
            && (-1_800_000_000...1_800_000_000).contains(signedInteger(data, at: 12))
            && (
                data.count != currentSize
                    || (data[25] == currentVersion && data[26] <= maxRelayHops)
            )
    }

    static func key(_ data: Data) -> String? {
        guard isValid(data) else { return nil }
        let user = data[2..<6].map { String(format: "%02x", $0) }.joined()
        let sequence = data[6..<8].map { String(format: "%02x", $0) }.joined()
        return "\(user)-\(sequence)"
    }

    private static func unsignedInteger(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    private static func signedInteger(_ data: Data, at offset: Int) -> Int32 {
        Int32(bitPattern: unsignedInteger(data, at: offset))
    }

    static func relayHopCount(_ data: Data) -> UInt8 {
        data.count == currentSize ? data[26] : 0
    }

    static func senderID(_ data: Data) -> UInt32 {
        unsignedInteger(data, at: 2)
    }

    static func sequence(_ data: Data) -> UInt16 {
        UInt16(data[6]) << 8 | UInt16(data[7])
    }

    static func reportedAt(_ data: Data) -> UInt32 {
        unsignedInteger(data, at: 17)
    }

    static func priority(_ data: Data) -> Int {
        switch data[16] {
        case 0, 1, 3: return 3
        case 2: return 2
        case 4, 5: return 1
        default: return 0
        }
    }

    static func relayComesBefore(_ left: Data, _ right: Data) -> Bool {
        let leftPriority = priority(left)
        let rightPriority = priority(right)
        if leftPriority != rightPriority {
            return leftPriority > rightPriority
        }
        let leftTimestamp = reportedAt(left)
        let rightTimestamp = reportedAt(right)
        if leftTimestamp != rightTimestamp {
            return leftTimestamp > rightTimestamp
        }
        let leftSender = senderID(left)
        let rightSender = senderID(right)
        if leftSender != rightSender {
            return leftSender < rightSender
        }
        return sequence(left) > sequence(right)
    }

    static func orderedForRelay(_ frames: [Data]) -> [Data] {
        var newestBySender: [UInt32: Data] = [:]
        for frame in frames where isFresh(frame) {
            let sender = senderID(frame)
            if let existing = newestBySender[sender] {
                let existingTimestamp = reportedAt(existing)
                let candidateTimestamp = reportedAt(frame)
                if existingTimestamp > candidateTimestamp {
                    continue
                }
                if existingTimestamp == candidateTimestamp {
                    if sequence(existing) > sequence(frame) {
                        continue
                    }
                    if sequence(existing) == sequence(frame),
                       relayHopCount(existing) <= relayHopCount(frame) {
                        continue
                    }
                }
            }
            newestBySender[sender] = frame
        }
        return newestBySender.values.sorted(by: relayComesBefore)
    }

    static func isFresh(_ data: Data, now: Date = Date()) -> Bool {
        guard isValid(data) else { return false }
        let reportedAt = TimeInterval(MeshPacket.reportedAt(data))
        let age = now.timeIntervalSince1970 - reportedAt
        return age >= -300 && age <= maxAge
    }

    static func forwarded(_ data: Data, now: Date = Date()) -> Data? {
        guard isFresh(data, now: now),
              data[16] != 0,
              relayHopCount(data) < maxRelayHops else {
            return nil
        }

        var frame = data
        if frame.count == 21 {
            frame.append(contentsOf: [0, 0, 0, 0])
        }
        if frame.count == 25 {
            frame.append(currentVersion)
            frame.append(1)
        } else {
            frame[26] += 1
        }
        return frame
    }

    static func notificationUserInfo(_ data: Data) -> [AnyHashable: Any]? {
        guard isValid(data) else { return nil }
        let userID = senderID(data)
        let packetSequence = MeshPacket.sequence(data)
        return [
            "kind": "mesh-distress",
            "packetKey": key(data) ?? "unknown",
            "packetId": "\(userID)_\(packetSequence)",
            "userId": String(userID),
            "sequence": Int(packetSequence),
            "latitude": Double(signedInteger(data, at: 8)) / 10_000_000,
            "longitude": Double(signedInteger(data, at: 12)) / 10_000_000,
            "statusCode": Int(data[16]),
            "reportedAt": Double(unsignedInteger(data, at: 17)),
            "relayHops": Int(relayHopCount(data)),
            "relaySource": "Nearby Bluetooth mesh",
        ]
    }

    static func cloudSignal(
        _ data: Data,
        rssi: Int,
        deliveredBy: String
    ) -> PendingCloudSignal? {
        guard isValid(data) else { return nil }
        let userID = senderID(data)
        let packetSequence = MeshPacket.sequence(data)
        let originDeviceID = String(format: "%08x", userID)
        return PendingCloudSignal(
            messageID: "\(originDeviceID)_\(packetSequence)",
            originDeviceID: originDeviceID,
            latitude: Double(signedInteger(data, at: 8)) / 10_000_000,
            longitude: Double(signedInteger(data, at: 12)) / 10_000_000,
            statusCode: Int(data[16]),
            packetTimestamp: unsignedInteger(data, at: 17),
            rssi: max(-127, min(20, rssi)),
            deliveredBy: deliveredBy,
            hopCount: Int(relayHopCount(data)),
            queuedAt: Date()
        )
    }

    static func notificationContent(_ data: Data) -> UNMutableNotificationContent? {
        guard isValid(data), data[16] != 0 else { return nil }
        let labels = [
            1: ("Rescue needed", "A nearby SafeRelay node requested immediate rescue."),
            2: ("Medical emergency", "A nearby SafeRelay node reported a medical emergency."),
            3: ("Person trapped", "A nearby SafeRelay node reported someone trapped or pinned."),
            4: ("Supplies needed", "A nearby SafeRelay node requested water, food, or supplies."),
            5: ("Shelter report", "A nearby SafeRelay node shared a shelter status report."),
        ]
        guard let (title, body) = labels[Int(data[16])] else { return nil }
        let content = UNMutableNotificationContent()
        content.title = "SafeRelay: \(title)"
        content.body = body
        content.sound = UNNotificationSound(named: signalSoundName)
        content.interruptionLevel = .timeSensitive
        content.relevanceScore = 1
        content.categoryIdentifier = distressNotificationCategory
        content.userInfo = notificationUserInfo(data) ?? [:]
        return content
    }
}

private final class SafeRelayAlertSoundPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = SafeRelayAlertSoundPlayer()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.development.saferelay",
        category: "AlertSound"
    )
    private var player: AVAudioPlayer?

    func play() {
        guard let soundURL = Bundle.main.url(
            forResource: "SafeRelaySignal",
            withExtension: "caf"
        ) else {
            logger.error("SafeRelaySignal.caf is missing from the app bundle")
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)

            let player = try AVAudioPlayer(contentsOf: soundURL)
            player.delegate = self
            player.volume = 1
            player.numberOfLoops = -1
            player.prepareToPlay()
            self.player = player
            player.play()
        } catch {
            logger.error(
                "Alert sound failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    func stop() {
        player?.stop()
        player = nil
        deactivateSession()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        deactivateSession()
    }

    private func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: [.notifyOthersOnDeactivation]
            )
        } catch {
            logger.error(
                "Alert audio session cleanup failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

final class SafeRelayMeshService: NSObject {
    static let shared = SafeRelayMeshService()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.development.saferelay",
        category: "Mesh"
    )
    private let defaults = UserDefaults.standard
    private let enabledKey = "saferelay.mesh.enabled"
    private let packetKey = "saferelay.mesh.latestPacket"
    private let relayQueueKey = "saferelay.mesh.relayQueue.v1"
    private let seenPacketsKey = "saferelay.mesh.seenPackets.v1"
    private let cloudOutboxKey = "saferelay.cloud.nativeOutbox"
    private let relayDeviceIDKey = "saferelay.cloud.relayDeviceID"
    private let centralRestoreID = "com.development.saferelay.mesh.central"
    private let peripheralRestoreID = "com.development.saferelay.mesh.peripheral"
    private let maxTrackedPeers = 64
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(
        label: "com.development.saferelay.cloud-reachability"
    )

    private var centralManager: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var localPacketCharacteristic: CBMutableCharacteristic?
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private var pendingEvents: [MeshPacketEvent] = []
    private var seenPackets: [String: Date] = [:]
    private var pendingWrites: [UUID: [PendingPeerWrite]] = [:]
    private var inFlightWrites: [UUID: PendingPeerWrite] = [:]
    private var pendingNotifications: [Data] = []
    private var connectionFailures: [UUID: Int] = [:]
    private var reconnectScheduled: Set<UUID> = []
    private var relayStateRestored = false
    private var started = false
    private var serviceAdded = false
    private var startCompletions: [(Result<Void, Error>) -> Void] = []
    private var cloudMonitorStarted = false
    private var cloudUploadInFlight = false
    private var cloudAuthorized = false

    fileprivate var eventHandler: ((MeshPacketEvent) -> Void)?

    var isEnabled: Bool { defaults.bool(forKey: enabledKey) }
    var isScanning: Bool { centralManager?.isScanning == true }
    var isAdvertising: Bool { peripheralManager?.isAdvertising == true }
    var connectedPeerCount: Int { connectedPeripherals.count }
    var pendingCloudUploadCount: Int { loadCloudOutbox().count }

    var bluetoothAuthorization: String {
        switch CBManager.authorization {
        case .allowedAlways: return "granted"
        case .denied, .restricted: return "denied"
        case .notDetermined: return "prompt"
        @unknown default: return "unknown"
        }
    }

    var bluetoothState: String {
        let states = [centralManager?.state, peripheralManager?.state].compactMap { $0 }
        if states.count == 2 && states.allSatisfy({ $0 == .poweredOn }) {
            return "poweredOn"
        }
        if states.contains(.poweredOff) { return "poweredOff" }
        if states.contains(.unauthorized) { return "unauthorized" }
        if states.contains(.unsupported) { return "unsupported" }
        if states.contains(.resetting) { return "resetting" }
        return "unknown"
    }

    func configureAtLaunch() {
        registerNotificationCategory()
        startCloudReachability()
        restoreRelayState()
        logger.notice("Starting always-on mesh service at launch")
        start()
        flushCloudOutbox()
    }

    func start(completion: ((Result<Void, Error>) -> Void)? = nil) {
        defaults.set(true, forKey: enabledKey)
        restoreRelayState()
        if let completion {
            startCompletions.append(completion)
        }
        guard !started else {
            configureRadioIfReady()
            return
        }

        started = true
        requestNotificationAuthorization()
        centralManager = CBCentralManager(
            delegate: self,
            queue: .main,
            options: [
                CBCentralManagerOptionRestoreIdentifierKey: centralRestoreID,
                CBCentralManagerOptionShowPowerAlertKey: true,
            ]
        )
        peripheralManager = CBPeripheralManager(
            delegate: self,
            queue: .main,
            options: [
                CBPeripheralManagerOptionRestoreIdentifierKey: peripheralRestoreID,
                CBPeripheralManagerOptionShowPowerAlertKey: true,
            ]
        )
        logger.notice("Native mesh managers started")
    }

    func publish(_ data: Data) throws {
        guard MeshPacket.isFresh(data) else {
            throw NSError(
                domain: "SafeRelayMesh",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Packet must be a fresh, valid 21-, 25-, or 27-byte SafeRelay frame."
                ]
            )
        }
        enqueueRelayFrame(data)
        remember(data)
        queueCloudUpload(data, rssi: -127)
        relay(data, excluding: nil)
        logger.notice("Published packet \(MeshPacket.key(data) ?? "unknown", privacy: .public)")
    }

    func drainPendingEvents() -> [[String: Any]] {
        let events = pendingEvents.map(\.dictionary)
        pendingEvents.removeAll()
        return events
    }

    func scheduleNotificationTest(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            let allowed: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                allowed = true
            case .notDetermined, .denied:
                allowed = false
            @unknown default:
                allowed = false
            }
            guard allowed else {
                completion(.failure(NSError(
                    domain: "SafeRelayNotifications",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Notification display is not authorized in device settings."
                    ]
                )))
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "SafeRelay alerts are working"
            content.body = "This device can show incoming distress notifications."
            content.sound = UNNotificationSound(named: signalSoundName)
            content.interruptionLevel = .active
            content.threadIdentifier = "saferelay-distress"
            content.categoryIdentifier = distressNotificationCategory
            var userInfo = self.latestPacket()
                .flatMap(MeshPacket.notificationUserInfo) ?? [:]
            userInfo["kind"] = "notification-test"
            userInfo["packetKey"] = "notification-self-test"
            userInfo["statusCode"] = 0
            userInfo["reportedAt"] = Date().timeIntervalSince1970
            userInfo["relaySource"] = "SafeRelay self-test"
            content.userInfo = userInfo
            self.enqueueNotification(
                identifier: "saferelay-notification-test",
                content: content,
                completion: completion
            )
        }
    }

    private func configureRadioIfReady() {
        if centralManager?.state == .poweredOn && centralManager?.isScanning == false {
            centralManager?.scanForPeripherals(
                withServices: [meshServiceUUID],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
            logger.notice("Scanning for SafeRelay service")
        }
        if centralManager?.state == .poweredOn {
            let disconnectedPeers = connectedPeripherals.values.filter {
                $0.state == .disconnected
            }
            for peripheral in disconnectedPeers {
                scheduleReconnect(peripheral, immediate: true)
            }
        }

        guard peripheralManager?.state == .poweredOn else {
            completeStartIfNeeded()
            return
        }
        if !serviceAdded {
            installGattService()
        } else if peripheralManager?.isAdvertising == false {
            startAdvertising()
        }
        completeStartIfNeeded()
    }

    private func installGattService() {
        guard let peripheralManager, localPacketCharacteristic == nil else { return }
        let characteristic = CBMutableCharacteristic(
            type: meshPacketUUID,
            properties: [.read, .write, .writeWithoutResponse, .notify, .indicate],
            value: nil,
            permissions: [.readable, .writeable]
        )
        let service = CBMutableService(type: meshServiceUUID, primary: true)
        service.characteristics = [characteristic]
        localPacketCharacteristic = characteristic
        peripheralManager.add(service)
    }

    private func startAdvertising() {
        peripheralManager?.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [meshServiceUUID],
            CBAdvertisementDataLocalNameKey: "SafeRelay",
        ])
    }

    private func completeStartIfNeeded() {
        guard centralManager?.state != .unknown,
              peripheralManager?.state != .unknown else {
            return
        }
        if centralManager?.state == .poweredOn && peripheralManager?.state == .poweredOn {
            guard isScanning, serviceAdded else { return }
            finishStart(.success(()))
            return
        }
        let blocked: Set<CBManagerState> = [.poweredOff, .unauthorized, .unsupported]
        if let state = [centralManager?.state, peripheralManager?.state]
            .compactMap({ $0 })
            .first(where: { blocked.contains($0) }) {
            let error = NSError(
                domain: "SafeRelayMesh",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Bluetooth is \(state.label)."]
            )
            finishStart(.failure(error))
        }
    }

    private func finishStart(_ result: Result<Void, Error>) {
        let completions = startCompletions
        startCompletions.removeAll()
        completions.forEach { $0(result) }
    }

    private func latestPacket() -> Data? {
        if let queued = relayFrames().first {
            return queued
        }
        guard let legacy = defaults.data(forKey: packetKey),
              MeshPacket.isFresh(legacy) else {
            return nil
        }
        return legacy
    }

    private func restoreRelayState() {
        guard !relayStateRestored else { return }
        relayStateRestored = true

        let cutoff = Date().addingTimeInterval(-MeshPacket.maxAge)
        let storedSeen = defaults.dictionary(forKey: seenPacketsKey) ?? [:]
        seenPackets = storedSeen.reduce(into: [:]) { result, entry in
            guard let timestamp = entry.value as? NSNumber else { return }
            let date = Date(timeIntervalSince1970: timestamp.doubleValue)
            if date > cutoff {
                result[entry.key] = date
            }
        }

        let legacyLatest = defaults.data(forKey: packetKey)
        var frames = relayFrames()
        if frames.isEmpty,
           let legacyLatest,
           MeshPacket.isFresh(legacyLatest) {
            frames = [legacyLatest]
            saveRelayFrames(frames)
        }
        frames.forEach(remember)
    }

    private func relayFrames() -> [Data] {
        let stored = defaults.array(forKey: relayQueueKey) as? [Data] ?? []
        let normalized = Array(MeshPacket.orderedForRelay(stored).prefix(100))
        if normalized != stored {
            saveRelayFrames(normalized)
        }
        return normalized
    }

    private func saveRelayFrames(_ frames: [Data]) {
        let bounded = Array(MeshPacket.orderedForRelay(frames).prefix(100))
        defaults.set(bounded, forKey: relayQueueKey)
        if let latest = bounded.first {
            defaults.set(latest, forKey: packetKey)
        } else {
            defaults.removeObject(forKey: packetKey)
        }
    }

    private func enqueueRelayFrame(_ data: Data) {
        guard let key = MeshPacket.key(data), MeshPacket.isFresh(data) else { return }
        var frames = relayFrames().filter { MeshPacket.key($0) != key }
        frames.append(data)
        saveRelayFrames(frames)
    }

    private func remember(_ data: Data) {
        guard let key = MeshPacket.key(data) else { return }
        let cutoff = Date().addingTimeInterval(-MeshPacket.maxAge)
        seenPackets = seenPackets.filter { $0.value > cutoff }
        seenPackets[key] = Date()
        if seenPackets.count > 500 {
            let newest = seenPackets.sorted { $0.value > $1.value }.prefix(500)
            seenPackets = Dictionary(uniqueKeysWithValues: newest.map { ($0.key, $0.value) })
        }
        defaults.set(
            seenPackets.mapValues(\.timeIntervalSince1970),
            forKey: seenPacketsKey
        )
    }

    private func acceptIncoming(
        _ data: Data,
        rssi: Int,
        source: String,
        excluding sourcePeripheral: CBPeripheral?
    ) {
        guard let key = MeshPacket.key(data), MeshPacket.isFresh(data) else {
            logger.error("Rejected malformed packet from \(source, privacy: .public)")
            return
        }
        guard seenPackets[key] == nil else { return }

        remember(data)
        let event = MeshPacketEvent(bytes: Array(data), rssi: rssi, source: source)
        if let eventHandler {
            eventHandler(event)
        } else {
            pendingEvents.append(event)
            if pendingEvents.count > 100 {
                pendingEvents.removeFirst(pendingEvents.count - 100)
            }
        }
        scheduleNotification(for: data)
        queueCloudUpload(data, rssi: rssi)
        if let forwarded = MeshPacket.forwarded(data) {
            enqueueRelayFrame(forwarded)
            relay(forwarded, excluding: sourcePeripheral)
        }
        logger.notice("Received packet \(key, privacy: .public) via \(source, privacy: .public)")
    }

    private func relay(_ data: Data, excluding sourcePeripheral: CBPeripheral?) {
        if let localPacketCharacteristic {
            let delivered = peripheralManager?.updateValue(
                data,
                for: localPacketCharacteristic,
                onSubscribedCentrals: nil
            ) ?? false
            if !delivered {
                enqueueNotification(data)
            }
        }
        for peripheral in connectedPeripherals.values
        where peripheral !== sourcePeripheral && peripheral.state == .connected {
            enqueueWrite(data, to: peripheral)
        }
    }

    private func enqueueWrite(_ data: Data, to peripheral: CBPeripheral) {
        let identifier = peripheral.identifier
        var queued = pendingWrites[identifier] ?? []
        let packetKey = MeshPacket.key(data)
        let inFlightKey = inFlightWrites[identifier].flatMap {
            MeshPacket.key($0.data)
        }
        guard MeshPacket.isFresh(data),
              !queued.contains(where: { MeshPacket.key($0.data) == packetKey }),
              inFlightKey != packetKey else {
            return
        }
        let sender = MeshPacket.senderID(data)
        queued.removeAll { MeshPacket.senderID($0.data) == sender }
        queued.append(PendingPeerWrite(data: data))
        queued.sort { MeshPacket.relayComesBefore($0.data, $1.data) }
        queued = Array(queued.prefix(100))
        pendingWrites[identifier] = queued
        drainWrites(to: peripheral)
    }

    private func enqueueRelayFrames(to peripheral: CBPeripheral) {
        for frame in relayFrames() {
            enqueueWrite(frame, to: peripheral)
        }
    }

    private func drainWrites(to peripheral: CBPeripheral) {
        let identifier = peripheral.identifier
        guard peripheral.state == .connected,
              inFlightWrites[identifier] == nil,
              let characteristic = remotePacketCharacteristic(on: peripheral) else {
            return
        }
        var queued = pendingWrites[peripheral.identifier] ?? []
        guard !queued.isEmpty else { return }

        let write = queued.removeFirst()
        pendingWrites[identifier] = queued
        if characteristic.properties.contains(.write) {
            inFlightWrites[identifier] = write
            peripheral.writeValue(write.data, for: characteristic, type: .withResponse)
        } else {
            queued.insert(write, at: 0)
            pendingWrites[identifier] = queued
            logger.error("Peer does not expose acknowledged packet writes")
        }
    }

    private func enqueueNotification(_ data: Data) {
        guard let key = MeshPacket.key(data),
              !pendingNotifications.contains(where: { MeshPacket.key($0) == key }) else {
            return
        }
        pendingNotifications.append(data)
        pendingNotifications = Array(
            MeshPacket.orderedForRelay(pendingNotifications).prefix(100)
        )
    }

    private func drainNotifications() {
        guard let localPacketCharacteristic else { return }
        while let data = pendingNotifications.first {
            let delivered = peripheralManager?.updateValue(
                data,
                for: localPacketCharacteristic,
                onSubscribedCentrals: nil
            ) ?? false
            if !delivered { return }
            pendingNotifications.removeFirst()
        }
    }

    private func replayRelayFrames(to central: CBCentral) {
        guard let localPacketCharacteristic else { return }
        let frames = relayFrames()
        for (index, frame) in frames.enumerated() {
            let delivered = peripheralManager?.updateValue(
                frame,
                for: localPacketCharacteristic,
                onSubscribedCentrals: [central]
            ) ?? false
            if !delivered {
                for pending in frames[index...] {
                    enqueueNotification(pending)
                }
                return
            }
        }
    }

    private func remotePacketCharacteristic(on peripheral: CBPeripheral) -> CBCharacteristic? {
        peripheral.services?
            .first(where: { $0.uuid == meshServiceUUID })?
            .characteristics?
            .first(where: { $0.uuid == meshPacketUUID })
    }

    private func configure(_ peripheral: CBPeripheral) {
        peripheral.delegate = self
        connectedPeripherals[peripheral.identifier] = peripheral
        switch peripheral.state {
        case .connected:
            peripheral.discoverServices([meshServiceUUID])
        case .connecting:
            break
        default:
            centralManager?.connect(
                peripheral,
                options: [
                    CBConnectPeripheralOptionNotifyOnConnectionKey: true,
                    CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
                    CBConnectPeripheralOptionEnableAutoReconnect: true,
                ]
            )
        }
    }

    private func scheduleReconnect(
        _ peripheral: CBPeripheral,
        immediate: Bool = false
    ) {
        let identifier = peripheral.identifier
        guard isEnabled, reconnectScheduled.insert(identifier).inserted else { return }
        let delay: TimeInterval
        if immediate {
            delay = 0
        } else {
            let failures = min(6, (connectionFailures[identifier] ?? 0) + 1)
            connectionFailures[identifier] = failures
            delay = min(30.0, pow(2.0, Double(failures - 1)))
        }
        connectedPeripherals[identifier] = peripheral
        logger.notice(
            "Peer reconnect scheduled in \(delay, privacy: .public) seconds"
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak peripheral] in
            guard let self else { return }
            reconnectScheduled.remove(identifier)
            guard isEnabled,
                  centralManager?.state == .poweredOn,
                  let peripheral,
                  peripheral.state == .disconnected else {
                return
            }
            configure(peripheral)
        }
    }

    private func scheduleNotification(for data: Data) {
        guard let content = MeshPacket.notificationContent(data),
              let key = MeshPacket.key(data) else {
            return
        }
        if UIApplication.shared.applicationState == .active {
            SafeRelayAlertSoundPlayer.shared.play()
            logger.notice("Played in-app alert sound for \(key, privacy: .public)")
            return
        }
        content.threadIdentifier = "saferelay-distress"
        enqueueNotification(
            identifier: "saferelay-\(key)",
            content: content
        )
    }

    private func enqueueNotification(
        identifier: String,
        content: UNNotificationContent,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { [logger] error in
            if let error {
                logger.error(
                    "Notification scheduling failed: \(error.localizedDescription, privacy: .public)"
                )
                completion?(.failure(error))
            } else {
                logger.notice("Notification scheduled: \(identifier, privacy: .public)")
                completion?(.success(()))
            }
        }
    }

    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { [logger] _, error in
            if let error {
                logger.error(
                    "Notification authorization failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func registerNotificationCategory() {
        let openIncident = UNNotificationAction(
            identifier: viewIncidentAction,
            title: "Open Incident Map",
            options: [.foreground]
        )
        let distress = UNNotificationCategory(
            identifier: distressNotificationCategory,
            actions: [openIncident],
            intentIdentifiers: [],
            options: []
        )
        let center = UNUserNotificationCenter.current()
        center.getNotificationCategories { categories in
            var updated = Set(
                categories.filter { $0.identifier != distressNotificationCategory }
            )
            updated.insert(distress)
            center.setNotificationCategories(updated)
        }
    }

    private func bundledCloudValue(_ key: String) -> String {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.contains("$(") ? "" : value
    }

    private func cloudConfiguration() -> CloudRelayConfiguration? {
        let baseURLText = bundledCloudValue("SafeRelayCloudURL")
        guard !baseURLText.isEmpty, let baseURL = URL(string: baseURLText) else {
            return nil
        }
        return CloudRelayConfiguration(
            baseURL: baseURL,
            previewToken: bundledCloudValue("SafeRelayCloudPreviewToken"),
            previewCookie: bundledCloudValue("SafeRelayCloudPreviewCookie")
        )
    }

    private func relayDeviceID() -> String {
        if let existing = defaults.string(forKey: relayDeviceIDKey), !existing.isEmpty {
            return existing
        }
        let identifier = UIDevice.current.identifierForVendor?.uuidString
            ?? UUID().uuidString
        let normalized = identifier.lowercased()
        defaults.set(normalized, forKey: relayDeviceIDKey)
        return normalized
    }

    private func loadCloudOutbox() -> [PendingCloudSignal] {
        guard let data = defaults.data(forKey: cloudOutboxKey),
              let signals = try? JSONDecoder().decode(
                [PendingCloudSignal].self,
                from: data
              ) else {
            return []
        }
        return signals
    }

    private func saveCloudOutbox(_ signals: [PendingCloudSignal]) {
        guard let data = try? JSONEncoder().encode(signals) else { return }
        defaults.set(data, forKey: cloudOutboxKey)
    }

    private func queueCloudUpload(_ data: Data, rssi: Int) {
        guard let signal = MeshPacket.cloudSignal(
            data,
            rssi: rssi,
            deliveredBy: relayDeviceID()
        ) else {
            return
        }
        var outbox = loadCloudOutbox()
        guard !outbox.contains(where: { $0.messageID == signal.messageID }) else {
            flushCloudOutbox()
            return
        }
        outbox.append(signal)
        if outbox.count > 2_048 {
            outbox.removeFirst(outbox.count - 2_048)
            logger.warning("Native cloud outbox reached its 2048-signal safety bound")
        }
        saveCloudOutbox(outbox)
        logger.notice(
            "Queued cloud signal \(signal.messageID, privacy: .public); \(outbox.count) pending"
        )
        flushCloudOutbox()
    }

    private func startCloudReachability() {
        guard !cloudMonitorStarted else { return }
        cloudMonitorStarted = true
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            DispatchQueue.main.async {
                self?.flushCloudOutbox()
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    private func authorizeCloud(
        _ configuration: CloudRelayConfiguration,
        completion: @escaping (Bool) -> Void
    ) {
        guard !configuration.previewToken.isEmpty else {
            completion(true)
            return
        }
        guard !cloudAuthorized else {
            completion(true)
            return
        }
        guard var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent("__auth"),
            resolvingAgainstBaseURL: false
        ) else {
            completion(false)
            return
        }
        components.queryItems = [
            URLQueryItem(name: "t", value: configuration.previewToken),
            URLQueryItem(name: "embed", value: "1"),
            URLQueryItem(name: "theme", value: "dark"),
        ]
        guard let url = components.url else {
            completion(false)
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        URLSession.shared.dataTask(with: request) {
            [weak self] _, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let authorized = error == nil && (200..<400).contains(status)
            DispatchQueue.main.async {
                self?.cloudAuthorized = authorized
                completion(authorized)
            }
        }.resume()
    }

    private func uploadCloudSignal(
        _ signal: PendingCloudSignal,
        configuration: CloudRelayConfiguration,
        completion: @escaping (Bool) -> Void
    ) {
        let endpoint = configuration.baseURL
            .appendingPathComponent("function")
            .appendingPathComponent("ingest_mobile_signal")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !configuration.previewCookie.isEmpty {
            request.setValue(
                configuration.previewCookie,
                forHTTPHeaderField: "Cookie"
            )
        }
        guard let body = try? JSONSerialization.data(
            withJSONObject: signal.payload
        ) else {
            completion(false)
            return
        }
        request.httpBody = body
        URLSession.shared.dataTask(with: request) {
            [weak self] data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 {
                self?.cloudAuthorized = false
            }
            let accepted: Bool
            if error == nil,
               (200..<300).contains(status),
               let data,
               let envelope = try? JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
               let responseData = envelope["data"] as? [String: Any],
               let result = responseData["result"] as? [String: Any] {
                accepted = result["success"] as? Bool == true
            } else {
                accepted = false
            }
            DispatchQueue.main.async {
                completion(accepted)
            }
        }.resume()
    }

    func flushCloudOutbox() {
        guard !cloudUploadInFlight,
              let configuration = cloudConfiguration(),
              let signal = loadCloudOutbox().first else {
            return
        }
        cloudUploadInFlight = true
        authorizeCloud(configuration) { [weak self] authorized in
            guard let self else { return }
            guard authorized else {
                cloudUploadInFlight = false
                logger.warning("Jac cloud preview authorization is unavailable")
                return
            }
            uploadCloudSignal(signal, configuration: configuration) {
                [weak self] accepted in
                guard let self else { return }
                cloudUploadInFlight = false
                guard accepted else {
                    logger.warning(
                        "Cloud upload deferred for \(signal.messageID, privacy: .public)"
                    )
                    return
                }
                var outbox = loadCloudOutbox()
                outbox.removeAll { $0.messageID == signal.messageID }
                saveCloudOutbox(outbox)
                logger.notice(
                    "Cloud receipted \(signal.messageID, privacy: .public); \(outbox.count) pending"
                )
                flushCloudOutbox()
            }
        }
    }
}

extension SafeRelayMeshService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.notice("Central state: \(central.state.label, privacy: .public)")
        configureRadioIfReady()
    }

    func centralManager(
        _ central: CBCentralManager,
        willRestoreState dict: [String: Any]
    ) {
        let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey]
            as? [CBPeripheral] ?? []
        peripherals.forEach(configure)
        logger.notice("Restored \(peripherals.count) central peer(s)")
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        guard connectedPeripherals[peripheral.identifier] == nil else { return }
        guard connectedPeripherals.count < maxTrackedPeers else {
            logger.warning("Peer limit reached; ignoring additional discovery")
            return
        }
        configure(peripheral)
        logger.notice(
            "Discovered peer \(peripheral.identifier.uuidString, privacy: .public) at \(RSSI.intValue) dBm"
        )
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionFailures.removeValue(forKey: peripheral.identifier)
        reconnectScheduled.remove(peripheral.identifier)
        configure(peripheral)
        logger.notice("Connected peer \(peripheral.identifier.uuidString, privacy: .public)")
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        pendingWrites.removeValue(forKey: peripheral.identifier)
        inFlightWrites.removeValue(forKey: peripheral.identifier)
        logger.error(
            "Peer connection failed: \(error?.localizedDescription ?? "unknown", privacy: .public)"
        )
        scheduleReconnect(peripheral)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        timestamp: CFAbsoluteTime,
        isReconnecting: Bool,
        error: Error?
    ) {
        guard isEnabled else {
            connectedPeripherals.removeValue(forKey: peripheral.identifier)
            pendingWrites.removeValue(forKey: peripheral.identifier)
            inFlightWrites.removeValue(forKey: peripheral.identifier)
            reconnectScheduled.remove(peripheral.identifier)
            return
        }
        pendingWrites.removeValue(forKey: peripheral.identifier)
        inFlightWrites.removeValue(forKey: peripheral.identifier)
        scheduleReconnect(peripheral, immediate: true)
        logger.notice("Peer disconnected; reconnect queued")
    }
}

extension SafeRelayMeshService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            logger.error(
                "Service discovery failed: \(error!.localizedDescription, privacy: .public)"
            )
            centralManager?.cancelPeripheralConnection(peripheral)
            return
        }
        for service in peripheral.services ?? [] where service.uuid == meshServiceUUID {
            peripheral.discoverCharacteristics([meshPacketUUID], for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil,
              let characteristic = service.characteristics?.first(where: {
                  $0.uuid == meshPacketUUID
              }) else {
            logger.error(
                "Characteristic discovery failed: \(error?.localizedDescription ?? "missing packet characteristic", privacy: .public)"
            )
            centralManager?.cancelPeripheralConnection(peripheral)
            return
        }
        peripheral.setNotifyValue(true, for: characteristic)
        peripheral.readValue(for: characteristic)
        enqueueRelayFrames(to: peripheral)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, let data = characteristic.value else { return }
        acceptIncoming(
            data,
            rssi: -127,
            source: characteristic.isNotifying ? "GATT notification" : "GATT read",
            excluding: peripheral
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == meshPacketUUID,
              var write = inFlightWrites.removeValue(
                forKey: peripheral.identifier
              ) else {
            return
        }

        if let error {
            write.attempts += 1
            if write.attempts < 3, peripheral.state == .connected {
                var queued = pendingWrites[peripheral.identifier] ?? []
                let sender = MeshPacket.senderID(write.data)
                if queued.contains(where: {
                    MeshPacket.senderID($0.data) == sender
                }) {
                    pendingWrites[peripheral.identifier] = queued
                    drainWrites(to: peripheral)
                    return
                }
                queued.append(write)
                queued.sort {
                    MeshPacket.relayComesBefore($0.data, $1.data)
                }
                pendingWrites[peripheral.identifier] = queued
                let delay = 0.4 * Double(write.attempts)
                logger.warning(
                    "Peer write was not acknowledged; retry \(write.attempts, privacy: .public)"
                )
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak peripheral] in
                    guard let self, let peripheral else { return }
                    drainWrites(to: peripheral)
                }
            } else {
                logger.error(
                    "Peer write failed after retries: \(error.localizedDescription, privacy: .public)"
                )
                centralManager?.cancelPeripheralConnection(peripheral)
            }
            return
        }

        drainWrites(to: peripheral)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard characteristic.uuid == meshPacketUUID, error != nil else { return }
        logger.error(
            "Peer notification subscription failed: \(error?.localizedDescription ?? "unknown", privacy: .public)"
        )
        centralManager?.cancelPeripheralConnection(peripheral)
    }

}

extension SafeRelayMeshService: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        logger.notice("Peripheral state: \(peripheral.state.label, privacy: .public)")
        configureRadioIfReady()
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        willRestoreState dict: [String: Any]
    ) {
        let services = dict[CBPeripheralManagerRestoredStateServicesKey]
            as? [CBMutableService] ?? []
        if let service = services.first(where: { $0.uuid == meshServiceUUID }),
           let characteristic = service.characteristics?.first(where: {
               $0.uuid == meshPacketUUID
           }) as? CBMutableCharacteristic {
            localPacketCharacteristic = characteristic
            serviceAdded = true
        }
        logger.notice("Restored \(services.count) peripheral service(s)")
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: Error?
    ) {
        guard error == nil else {
            logger.error(
                "GATT service add failed: \(error!.localizedDescription, privacy: .public)"
            )
            finishStart(.failure(error!))
            return
        }
        serviceAdded = true
        startAdvertising()
        completeStartIfNeeded()
        logger.notice("SafeRelay GATT service published")
    }

    func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: Error?
    ) {
        if let error {
            logger.error("Advertising failed: \(error.localizedDescription, privacy: .public)")
        } else {
            logger.notice("Advertising SafeRelay service")
        }
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        drainNotifications()
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        guard characteristic.uuid == meshPacketUUID else { return }
        replayRelayFrames(to: central)
        logger.notice(
            "Replayed relay queue to subscribed central \(central.identifier.uuidString, privacy: .public)"
        )
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveRead request: CBATTRequest
    ) {
        guard request.characteristic.uuid == meshPacketUUID,
              let packet = latestPacket() else {
            peripheral.respond(to: request, withResult: .unlikelyError)
            return
        }
        guard request.offset <= packet.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = packet.subdata(in: request.offset..<packet.count)
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        for request in requests {
            guard request.characteristic.uuid == meshPacketUUID,
                  let data = request.value,
                  MeshPacket.isFresh(data) else {
                if request.characteristic.properties.contains(.write) {
                    peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
                }
                continue
            }
            acceptIncoming(data, rssi: -127, source: "peer write", excluding: nil)
            if request.characteristic.properties.contains(.write) {
                peripheral.respond(to: request, withResult: .success)
            }
        }
    }
}

private extension CBManagerState {
    var label: String {
        switch self {
        case .unknown: return "unknown"
        case .resetting: return "resetting"
        case .unsupported: return "unsupported"
        case .unauthorized: return "unauthorized"
        case .poweredOff: return "powered off"
        case .poweredOn: return "powered on"
        @unknown default: return "unknown"
        }
    }
}

private final class SafeRelayCompassService: NSObject, CLLocationManagerDelegate {
    static let shared = SafeRelayCompassService()

    private let locationManager = CLLocationManager()
    private(set) var isUpdating = false
    var eventHandler: ((CLHeading) -> Void)?

    override private init() {
        super.init()
        locationManager.delegate = self
        locationManager.headingFilter = 1
        locationManager.headingOrientation = .portrait
    }

    func start() throws {
        guard CLLocationManager.headingAvailable() else {
            throw NSError(
                domain: "SafeRelayCompass",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "Magnetic heading is unavailable on this device."
                ]
            )
        }
        isUpdating = true
        locationManager.startUpdatingHeading()
    }

    func stop() {
        locationManager.stopUpdatingHeading()
        isUpdating = false
    }

    func locationManager(
        _ manager: CLLocationManager,
        didUpdateHeading newHeading: CLHeading
    ) {
        guard isUpdating, newHeading.headingAccuracy >= 0 else { return }
        eventHandler?(newHeading)
    }
}

@objc(SafeRelayNativeMeshPlugin)
public final class SafeRelayNativeMeshPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "SafeRelayNativeMeshPlugin"
    public let jsName = "SafeRelayNativeMesh"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "start", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "status", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "publish", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "drain", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "testNotification", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startAlert", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "dismissAlert", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "presentIncident", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "startCompass", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "stopCompass", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cloudPost", returnType: CAPPluginReturnPromise),
    ]

    public override func load() {
        SafeRelayMeshService.shared.eventHandler = { [weak self] event in
            self?.notifyListeners(
                "packetReceived",
                data: event.dictionary,
                retainUntilConsumed: true
            )
        }
        SafeRelayCompassService.shared.eventHandler = { [weak self] heading in
            self?.notifyListeners(
                "headingChanged",
                data: [
                    "heading": heading.magneticHeading,
                    "accuracy": heading.headingAccuracy,
                    "timestamp": heading.timestamp.timeIntervalSince1970,
                ]
            )
        }
    }

    @objc func start(_ call: CAPPluginCall) {
        SafeRelayMeshService.shared.start { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    call.resolve(self?.statusDictionary() ?? [:])
                case .failure(let error):
                    call.reject(error.localizedDescription)
                }
            }
        }
    }

    @objc func status(_ call: CAPPluginCall) {
        call.resolve(statusDictionary())
    }

    @objc func publish(_ call: CAPPluginCall) {
        guard let values = call.getArray("value") else {
            call.reject("Missing packet bytes.")
            return
        }
        let bytes: [UInt8]
        do {
            bytes = try values.map { value in
                if let value = value as? Int, (0...255).contains(value) {
                    return UInt8(value)
                }
                if let value = value as? NSNumber {
                    let integer = value.intValue
                    guard (0...255).contains(integer) else {
                        throw NSError(
                            domain: "SafeRelayMesh",
                            code: 3,
                            userInfo: [NSLocalizedDescriptionKey: "Packet byte is outside 0...255."]
                        )
                    }
                    return UInt8(integer)
                }
                throw NSError(
                    domain: "SafeRelayMesh",
                    code: 4,
                    userInfo: [NSLocalizedDescriptionKey: "Packet contains a non-numeric byte."]
                )
            }
            let service = SafeRelayMeshService.shared
            try service.publish(Data(bytes))
            call.resolve([
                "published": true,
                "persisted": true,
                "connectedPeers": service.connectedPeerCount,
                "scanning": service.isScanning,
                "advertising": service.isAdvertising,
            ])
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func drain(_ call: CAPPluginCall) {
        call.resolve(["packets": SafeRelayMeshService.shared.drainPendingEvents()])
    }

    @objc func testNotification(_ call: CAPPluginCall) {
        SafeRelayMeshService.shared.scheduleNotificationTest { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    call.resolve(["scheduled": true])
                case .failure(let error):
                    call.reject(error.localizedDescription)
                }
            }
        }
    }

    @objc func startAlert(_ call: CAPPluginCall) {
        SafeRelayAlertSoundPlayer.shared.play()
        call.resolve()
    }

    @objc func dismissAlert(_ call: CAPPluginCall) {
        SafeRelayAlertSoundPlayer.shared.stop()
        call.resolve()
    }

    @objc func presentIncident(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .safeRelayPresentIncident, object: nil)
            call.resolve()
        }
    }

    @objc func startCompass(_ call: CAPPluginCall) {
        do {
            try SafeRelayCompassService.shared.start()
            call.resolve([
                "active": true,
                "message": "Live magnetic heading active.",
            ])
        } catch {
            call.reject(error.localizedDescription)
        }
    }

    @objc func stopCompass(_ call: CAPPluginCall) {
        SafeRelayCompassService.shared.stop()
        call.resolve([
            "active": false,
            "message": "Compass paused.",
        ])
    }

    @objc func cloudPost(_ call: CAPPluginCall) {
        guard let baseURLText = call.getString("baseUrl"),
              let baseURL = URL(string: baseURLText),
              let path = call.getString("path"),
              path.hasPrefix("/function/") else {
            call.reject("Invalid Jac cloud endpoint.")
            return
        }

        let previewToken = call.getString("previewToken")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallbackCookie = call.getString("previewCookie")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let payload = call.getObject("data") ?? [:]

        let post: (Bool) -> Void = { useFallbackCookie in
            guard let endpoint = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
                DispatchQueue.main.async {
                    call.reject("Invalid Jac cloud function URL.")
                }
                return
            }
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.timeoutInterval = 15
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if useFallbackCookie && !fallbackCookie.isEmpty {
                request.setValue(fallbackCookie, forHTTPHeaderField: "Cookie")
            }
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                DispatchQueue.main.async {
                    call.reject("Jac cloud payload could not be encoded.")
                }
                return
            }

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error {
                    DispatchQueue.main.async {
                        call.reject(error.localizedDescription)
                    }
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let responseData: Any
                if let data,
                   let decoded = try? JSONSerialization.jsonObject(with: data) {
                    responseData = decoded
                } else if let data {
                    responseData = String(data: data, encoding: .utf8) ?? ""
                } else {
                    responseData = ""
                }
                DispatchQueue.main.async {
                    call.resolve([
                        "status": status,
                        "data": responseData,
                    ])
                }
            }.resume()
        }

        guard !previewToken.isEmpty else {
            post(!fallbackCookie.isEmpty)
            return
        }
        guard var auth = URLComponents(
            url: baseURL.appendingPathComponent("__auth"),
            resolvingAgainstBaseURL: false
        ) else {
            call.reject("Invalid Jac cloud authorization URL.")
            return
        }
        auth.queryItems = [
            URLQueryItem(name: "t", value: previewToken),
            URLQueryItem(name: "embed", value: "1"),
            URLQueryItem(name: "theme", value: "dark"),
        ]
        guard let authURL = auth.url else {
            call.reject("Invalid Jac cloud authorization token.")
            return
        }

        var authRequest = URLRequest(url: authURL)
        authRequest.timeoutInterval = 10
        URLSession.shared.dataTask(with: authRequest) { _, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let authorized = error == nil && (200..<400).contains(status)
            post(!authorized && !fallbackCookie.isEmpty)
        }.resume()
    }

    private func statusDictionary() -> [String: Any] {
        let service = SafeRelayMeshService.shared
        let backgroundRefresh: String
        switch UIApplication.shared.backgroundRefreshStatus {
        case .available: backgroundRefresh = "available"
        case .denied: backgroundRefresh = "denied"
        case .restricted: backgroundRefresh = "restricted"
        @unknown default: backgroundRefresh = "unknown"
        }
        return [
            "enabled": service.isEnabled,
            "scanning": service.isScanning,
            "advertising": service.isAdvertising,
            "bluetoothPermission": service.bluetoothAuthorization,
            "bluetoothState": service.bluetoothState,
            "backgroundRefresh": backgroundRefresh,
            "connectedPeers": service.connectedPeerCount,
            "pendingCloudUploads": service.pendingCloudUploadCount,
            "version": "native-ios-3",
        ]
    }
}
