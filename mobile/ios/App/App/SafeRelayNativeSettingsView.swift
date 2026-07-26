import Combine
import SwiftUI

@MainActor
final class SafeRelaySettingsModel: ObservableObject {
    @Published var meshActive = false
    @Published var busy = false
    @Published var meshMessage = "Mesh relay has not been started."
    @Published var privacyMode = "Relay Only"
    @Published var batteryMode = "Bridge"
    @Published var themeMode = "System"
    @Published var autoDownloadMaps = true
    @Published var autoActivate = true
    @Published var showNotifications = true
    @Published var bluetoothPermission = "unknown"
    @Published var notificationPermission = "unknown"
    @Published var backgroundState = "unknown"
    @Published var networkState = "unknown"
    @Published var locationReady = false
    @Published var locationMessage = "Location not sampled."
    @Published var foundationAvailable = false
    @Published var foundationStatus = "not checked"
    @Published var offlineTiles = 0
    @Published var queuedPackets = 0
    @Published var syncReceipts = 0
    @Published var packetCount = 0
    @Published var syncRecordCount = 0
    @Published var platform = "ios"
    @Published var pluginVersion = "unknown"

    var readinessScore: Int {
        var score = 15
        if bluetoothPermission == "granted" { score += 25 }
        if notificationPermission == "granted" { score += 15 }
        if backgroundState == "available" { score += 15 }
        if locationReady { score += 15 }
        if meshActive { score += 15 }
        return score
    }

    var readinessTitle: String {
        switch readinessScore {
        case 85...:
            return "Ready for field relay"
        case 60...:
            return "A few systems need attention"
        default:
            return "Complete device readiness"
        }
    }

    var readinessColor: Color {
        switch readinessScore {
        case 85...:
            return .green
        case 60...:
            return .orange
        default:
            return .red
        }
    }

    func apply(_ values: [String: Any]) {
        meshActive = values.bool("meshActive", fallback: meshActive)
        busy = values.bool("busy", fallback: busy)
        meshMessage = values.string("meshMessage", fallback: meshMessage)
        privacyMode = values.string("privacyMode", fallback: privacyMode)
        batteryMode = values.string("batteryMode", fallback: batteryMode)
        themeMode = values.string("themeMode", fallback: themeMode)
        autoDownloadMaps = values.bool(
            "autoDownloadMaps",
            fallback: autoDownloadMaps
        )
        autoActivate = values.bool("autoActivate", fallback: autoActivate)
        showNotifications = values.bool(
            "showNotifications",
            fallback: showNotifications
        )
        bluetoothPermission = values.string(
            "bluetoothPermission",
            fallback: bluetoothPermission
        )
        notificationPermission = values.string(
            "notificationPermission",
            fallback: notificationPermission
        )
        backgroundState = values.string(
            "backgroundState",
            fallback: backgroundState
        )
        networkState = values.string("networkState", fallback: networkState)
        locationReady = values.bool("locationReady", fallback: locationReady)
        locationMessage = values.string(
            "locationMessage",
            fallback: locationMessage
        )
        foundationAvailable = values.bool(
            "foundationAvailable",
            fallback: foundationAvailable
        )
        foundationStatus = values.string(
            "foundationStatus",
            fallback: foundationStatus
        )
        offlineTiles = values.int("offlineTiles", fallback: offlineTiles)
        queuedPackets = values.int("queuedPackets", fallback: queuedPackets)
        syncReceipts = values.int("syncReceipts", fallback: syncReceipts)
        packetCount = values.int("packetCount", fallback: packetCount)
        syncRecordCount = values.int(
            "syncRecordCount",
            fallback: syncRecordCount
        )
        platform = values.string("platform", fallback: platform)
        pluginVersion = values.string(
            "pluginVersion",
            fallback: pluginVersion
        )
    }
}

private extension Dictionary where Key == String, Value == Any {
    func string(_ key: String, fallback: String) -> String {
        self[key] as? String ?? fallback
    }

    func bool(_ key: String, fallback: Bool) -> Bool {
        if let value = self[key] as? Bool {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.boolValue
        }
        return fallback
    }

    func int(_ key: String, fallback: Int) -> Int {
        if let value = self[key] as? Int {
            return value
        }
        if let value = self[key] as? NSNumber {
            return value.intValue
        }
        return fallback
    }
}

private enum PendingDestructiveAction: String, Identifiable {
    case clearMapCache = "settings-clear-map-cache"
    case clearPacketHistory = "settings-clear-packets"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clearMapCache:
            return "Clear Map Cache?"
        case .clearPacketHistory:
            return "Clear SOS History?"
        }
    }

    var message: String {
        switch self {
        case .clearMapCache:
            return "Downloaded offline map tiles will be removed from this iPhone."
        case .clearPacketHistory:
            return "All cached SOS packets will be removed from this iPhone."
        }
    }

    var buttonTitle: String {
        switch self {
        case .clearMapCache:
            return "Clear Map Cache"
        case .clearPacketHistory:
            return "Clear SOS History"
        }
    }
}

@MainActor
struct SafeRelayNativeSettingsView: View {
    @ObservedObject var model: SafeRelaySettingsModel
    let performAction: (String) -> Void

    @State private var showingHowItWorks = false
    @State private var pendingDestructiveAction: PendingDestructiveAction?

    private let batteryDescriptions = [
        "SOS Active": "Always ready for urgent field traffic.",
        "Bridge": "Balanced local relay policy.",
        "Battery Saver": "Preserves reserve for urgent packets.",
        "Custom": "Custom relay policy; iOS manages radio scheduling."
    ]

    var body: some View {
        NavigationStack {
            List {
                    readinessCard
                        .listRowBackground(Color.clear)
                        .listRowInsets(
                            EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
                        )

                    Section {
                        Picker("Privacy bridge", selection: privacyBinding) {
                            Text("Local").tag("Local Only")
                            Text("Relay").tag("Relay Only")
                            Text("Cloud").tag("Cloud Bridge")
                        }
                        .pickerStyle(.segmented)

                        LabeledContent("Bluetooth relay") {
                            Text(model.privacyMode == "Local Only" ? "Blocked" : "Allowed")
                                .foregroundStyle(
                                    model.privacyMode == "Local Only"
                                        ? Color.secondary
                                        : Color.green
                                )
                        }
                        LabeledContent("Cloud upload") {
                            Text(model.privacyMode == "Cloud Bridge" ? "Allowed" : "Blocked")
                                .foregroundStyle(
                                    model.privacyMode == "Cloud Bridge"
                                        ? Color.green
                                        : Color.secondary
                                )
                        }
                        LabeledContent("Pending sync", value: "\(model.queuedPackets) packets")
                    } header: {
                        Text("Privacy and Bridge Mode")
                    } footer: {
                        Text(privacyDescription)
                    }

                    Section("Display") {
                        Picker("Theme Mode", selection: themeBinding) {
                            Label("Auto", systemImage: "circle.lefthalf.filled")
                                .tag("System")
                            Label("Light", systemImage: "sun.max.fill")
                                .tag("Light")
                            Label("Dark", systemImage: "moon.fill")
                                .tag("Dark")
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        Picker("Relay profile", selection: batteryBinding) {
                            Text("SOS Active").tag("SOS Active")
                            Text("Bridge Mode").tag("Bridge")
                            Text("Battery Saver").tag("Battery Saver")
                            Text("Custom").tag("Custom")
                        }

                        LabeledContent(
                            "Current behavior",
                            value: batteryDescriptions[model.batteryMode]
                                ?? "Balanced local relay policy."
                        )
                    } header: {
                        Text("Battery Mode")
                    } footer: {
                        Text(
                            "iOS controls Bluetooth scan and advertising intervals. "
                            + "SafeRelay applies this choice to local relay policy."
                        )
                    }

                    Section("Data and Storage") {
                        settingsButton(
                            "Download Offline Region",
                            subtitle: model.offlineTiles > 0
                                ? "\(model.offlineTiles) map tiles cached"
                                : "Save the area around your current position",
                            symbol: "arrow.down.circle",
                            action: "settings-download-map"
                        )
                        settingsButton(
                            "Alert History",
                            subtitle: "\(model.packetCount) packet records on this device",
                            symbol: "clock.arrow.circlepath",
                            action: "nav-home"
                        )
                        settingsButton(
                            "Clear Map Cache",
                            subtitle: "Remove downloaded offline tiles",
                            symbol: "map.fill",
                            role: .destructive,
                            action: nil
                        ) {
                            pendingDestructiveAction = .clearMapCache
                        }
                        settingsButton(
                            "Clear SOS History",
                            subtitle: "Remove all cached packets",
                            symbol: "trash",
                            role: .destructive,
                            action: nil
                        ) {
                            pendingDestructiveAction = .clearPacketHistory
                        }
                    }

                    Section {
                        Toggle(
                            "Auto-download Maps",
                            systemImage: "square.and.arrow.down",
                            isOn: autoDownloadBinding
                        )
                    } header: {
                        Text("Offline Settings")
                    } footer: {
                        Text("Updates the local map around your position on launch.")
                    }

                    Section {
                        LabeledContent {
                            Text("BLE 5.x")
                        } label: {
                            Label("Radio compatibility", systemImage: "wave.3.right")
                        }
                        LabeledContent("Permission", value: model.bluetoothPermission.capitalized)
                        LabeledContent("Background refresh", value: model.backgroundState.capitalized)

                        if model.backgroundState != "available" {
                            settingsButton(
                                "Open iOS Settings",
                                subtitle: "Enable Background App Refresh",
                                symbol: "gear",
                                action: "settings-open-ios"
                            )
                        }
                    } header: {
                        Text("Bluetooth")
                    } footer: {
                        Text(
                            "BLE 4.x and BLE 5.x transport selection is managed by "
                            + "iOS and the connected hardware."
                        )
                    }

                    Section("Automation") {
                        Toggle(
                            "Auto-activate on disaster",
                            systemImage: "exclamationmark.triangle",
                            isOn: autoActivateBinding
                        )
                        Toggle(
                            "Auto-upload when online",
                            systemImage: "icloud.and.arrow.up",
                            isOn: autoUploadBinding
                        )
                        Toggle(
                            "Show notifications",
                            systemImage: "bell.badge",
                            isOn: notificationsBinding
                        )
                    }

                    Section("Cloud Sync") {
                        settingsButton(
                            "Sync Relayed Packets",
                            subtitle: "\(model.queuedPackets) queued, \(model.syncReceipts) receipts",
                            symbol: "arrow.triangle.2.circlepath.icloud",
                            action: "settings-sync"
                        )
                    }

                    Section("Location Reference") {
                        LabeledContent {
                            Text(model.locationReady ? "Ready" : "Needs attention")
                                .foregroundStyle(
                                    model.locationReady
                                        ? Color.green
                                        : Color.orange
                                )
                        } label: {
                            Label("Current Location", systemImage: "location.fill")
                        }
                        Text(model.locationMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        settingsButton(
                            "Refresh Location",
                            subtitle: "Update the position used for SOS and offline maps",
                            symbol: "location.circle",
                            action: "settings-refresh-location"
                        )
                    }

                    Section("Diagnostics") {
                        diagnosticRow(
                            "Mesh Radio",
                            value: model.meshActive ? "Active" : "Off",
                            ready: model.meshActive,
                            symbol: "antenna.radiowaves.left.and.right"
                        )
                        diagnosticRow(
                            "Native Permissions",
                            value: permissionsReady ? "Ready" : "Needs attention",
                            ready: permissionsReady,
                            symbol: "checkmark.shield"
                        )
                        diagnosticRow(
                            "Network",
                            value: model.networkState.capitalized,
                            ready: model.networkState != "offline",
                            symbol: "network"
                        )
                        diagnosticRow(
                            "On-device Guide",
                            value: model.foundationStatus,
                            ready: model.foundationAvailable,
                            symbol: "apple.intelligence"
                        )
                        settingsButton(
                            "Test Distress Notification",
                            subtitle: "Banner, sound, and Notification Center",
                            symbol: "bell.and.waves.left.and.right",
                            action: "settings-test-notification"
                        )
                    }

                    Section("About") {
                        LabeledContent("Version") {
                            Text(model.pluginVersion)
                        }
                        settingsButton(
                            "How it works",
                            symbol: "questionmark.circle",
                            action: nil
                        ) {
                            showingHowItWorks = true
                        }
                        settingsButton(
                            "Redo Onboarding",
                            subtitle: "Review permissions and setup again",
                            symbol: "arrow.counterclockwise",
                            action: "settings-redo-onboarding"
                        )
                        LabeledContent("Runtime", value: model.platform.uppercased())
                    }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        performAction("settings-refresh")
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Refresh device status")
                }
            }
        }
        .alert("How SafeRelay Works", isPresented: $showingHowItWorks) {
            Button("Done", role: .cancel) {}
        } message: {
            Text(howItWorksDescription)
        }
        .confirmationDialog(
            pendingDestructiveAction?.title ?? "Confirm",
            isPresented: destructiveConfirmationPresented,
            titleVisibility: .visible
        ) {
            if let pendingDestructiveAction {
                Button(pendingDestructiveAction.buttonTitle, role: .destructive) {
                    performAction(pendingDestructiveAction.rawValue)
                    self.pendingDestructiveAction = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDestructiveAction = nil
            }
        } message: {
            Text(pendingDestructiveAction?.message ?? "")
        }
    }

    private var readinessCard: some View {
        GlassEffectContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Label("Readiness and Systems", systemImage: "checklist.checked")
                        .font(.headline)
                    Spacer()
                    Text("\(model.readinessScore)%")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(model.readinessColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(model.readinessTitle)
                        .font(.title3.weight(.semibold))
                    Text(model.meshMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack(spacing: 12) {
                    Button {
                        performAction("settings-mesh-toggle")
                    } label: {
                        Label(
                            model.meshActive ? "Stop Mesh" : "Start Mesh",
                            systemImage: model.meshActive
                                ? "stop.fill"
                                : "antenna.radiowaves.left.and.right"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(model.meshActive ? .orange : .blue)
                    .disabled(model.busy)

                    Button {
                        performAction("settings-refresh")
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .disabled(model.busy)
                    .accessibilityLabel("Refresh readiness")
                }
            }
            .padding(18)
            .glassEffect(
                .regular
                    .tint(model.readinessColor.opacity(0.12))
                    .interactive(),
                in: .rect(
                    cornerRadius: SafeRelayMetrics.componentCornerRadius,
                    style: .continuous
                )
            )
        }
    }

    private var permissionsReady: Bool {
        model.bluetoothPermission == "granted"
            && model.notificationPermission == "granted"
    }

    private var destructiveConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingDestructiveAction != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDestructiveAction = nil
                }
            }
        )
    }

    private var howItWorksDescription: String {
        "SafeRelay stores SOS packets on this iPhone, relays eligible packets "
            + "over nearby Bluetooth, and uploads received packets only when "
            + "Cloud Bridge is enabled and internet is reachable. A local send "
            + "or cloud receipt is not responder confirmation."
    }

    private var privacyDescription: String {
        switch model.privacyMode {
        case "Local Only":
            return "Packets stay on this phone. Nearby relay and cloud upload are blocked."
        case "Cloud Bridge":
            return "Nearby relay is allowed. Received packets may upload when internet returns."
        default:
            return "Nearby Bluetooth relay is allowed while cloud upload stays disabled."
        }
    }

    private var privacyBinding: Binding<String> {
        Binding(
            get: { model.privacyMode },
            set: { value in
                model.privacyMode = value
                let action = switch value {
                case "Local Only": "settings-privacy-local"
                case "Cloud Bridge": "settings-privacy-cloud"
                default: "settings-privacy-relay"
                }
                performAction(action)
            }
        )
    }

    private var themeBinding: Binding<String> {
        Binding(
            get: { model.themeMode },
            set: { value in
                model.themeMode = value
                let action = switch value {
                case "Light": "settings-theme-light"
                case "Dark": "settings-theme-dark"
                default: "settings-theme-system"
                }
                performAction(action)
            }
        )
    }

    private var batteryBinding: Binding<String> {
        Binding(
            get: { model.batteryMode },
            set: { value in
                model.batteryMode = value
                let action = switch value {
                case "SOS Active": "settings-battery-sos"
                case "Battery Saver": "settings-battery-saver"
                case "Custom": "settings-battery-custom"
                default: "settings-battery-bridge"
                }
                performAction(action)
            }
        )
    }

    private var autoDownloadBinding: Binding<Bool> {
        Binding(
            get: { model.autoDownloadMaps },
            set: { value in
                model.autoDownloadMaps = value
                performAction("settings-auto-download")
            }
        )
    }

    private var autoActivateBinding: Binding<Bool> {
        Binding(
            get: { model.autoActivate },
            set: { value in
                model.autoActivate = value
                performAction("settings-auto-activate")
            }
        )
    }

    private var autoUploadBinding: Binding<Bool> {
        Binding(
            get: { model.privacyMode == "Cloud Bridge" },
            set: { value in
                model.privacyMode = value ? "Cloud Bridge" : "Relay Only"
                performAction("settings-auto-upload")
            }
        )
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { model.showNotifications },
            set: { value in
                model.showNotifications = value
                performAction("settings-show-notifications")
            }
        )
    }

    private func diagnosticRow(
        _ title: String,
        value: String,
        ready: Bool,
        symbol: String
    ) -> some View {
        LabeledContent {
            HStack(spacing: 7) {
                Circle()
                    .fill(ready ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(value)
                    .foregroundStyle(
                        ready ? Color.primary : Color.secondary
                    )
            }
        } label: {
            Label(title, systemImage: symbol)
        }
    }

    private func settingsButton(
        _ title: String,
        subtitle: String? = nil,
        symbol: String,
        role: ButtonRole? = nil,
        action: String?,
        customAction: (() -> Void)? = nil
    ) -> some View {
        Button(role: role) {
            if let customAction {
                customAction()
            } else if let action {
                performAction(action)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .foregroundStyle(role == .destructive ? Color.red : Color.primary)
    }
}
