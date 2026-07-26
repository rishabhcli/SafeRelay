import Capacitor
import UIKit
import WebKit

enum SafeRelayMetrics {
    static let componentCornerRadius: CGFloat = 18
    static let nativeTabBarContentHeight: CGFloat = 49
}

final class SafeRelayBridgeViewController:
    CAPBridgeViewController,
    UITabBarDelegate,
    UITextViewDelegate {
    private struct NativeTab {
        let elementID: String
        let title: String
        let symbol: String
        let isSOS: Bool
    }

    private struct NativeMapAction {
        let elementID: String
        let label: String
        let symbol: String
    }

    private let nativeTabs = [
        NativeTab(elementID: "nav-home", title: "Home", symbol: "house.fill", isSOS: false),
        NativeTab(elementID: "nav-map", title: "Map", symbol: "map.fill", isSOS: false),
        NativeTab(elementID: "nav-sos", title: "SOS", symbol: "sos.circle.fill", isSOS: true),
        NativeTab(elementID: "nav-tools", title: "Tools", symbol: "wrench.and.screwdriver.fill", isSOS: false),
        NativeTab(elementID: "nav-settings", title: "Settings", symbol: "gearshape.fill", isSOS: false)
    ]
    private let fieldTools = [
        (elementID: "tool-guide", title: "Guide"),
        (elementID: "tool-compass", title: "Compass"),
        (elementID: "tool-beacon", title: "Beacon"),
        (elementID: "tool-sonic", title: "Sonic")
    ]
    private let sosTypes = [
        (elementID: "sos-rescue", title: "Rescue"),
        (elementID: "sos-medical", title: "Medical"),
        (elementID: "sos-trapped", title: "Trapped"),
        (elementID: "sos-supplies", title: "Supplies")
    ]
    private let nativeMapActions = [
        NativeMapAction(elementID: "map-zoom-in", label: "Zoom in", symbol: "plus.magnifyingglass"),
        NativeMapAction(elementID: "map-zoom-out", label: "Zoom out", symbol: "minus.magnifyingglass"),
        NativeMapAction(elementID: "map-locate", label: "Locate me", symbol: "location.fill"),
        NativeMapAction(elementID: "map-fit-signals", label: "Fit active signals", symbol: "scope")
    ]

    private var nativeTabBar: UITabBar?
    private var fieldToolsControl: UISegmentedControl?
    private var sosTypeControl: UISegmentedControl?
    private var nativeMapControls: UIStackView?
    private var nativeMapLocateButton: UIButton?
    private var nativeSOSButton: UIButton?
    private var nativeSOSButtonTopConstraint: NSLayoutConstraint?
    private var nativeSOSButtonWidthConstraint: NSLayoutConstraint?
    private var nativeSOSButtonHeightConstraint: NSLayoutConstraint?
    private var nativeBeaconButton: UIButton?
    private var nativeBeaconButtonLeadingConstraint: NSLayoutConstraint?
    private var nativeBeaconButtonTopConstraint: NSLayoutConstraint?
    private var nativeBeaconButtonWidthConstraint: NSLayoutConstraint?
    private var nativeBeaconButtonHeightConstraint: NSLayoutConstraint?
    private var nativeSonicSlider: UISlider?
    private var nativeSonicSendButton: UIButton?
    private var nativeSonicListenButton: UIButton?
    private var survivalComposerContainer: UIView?
    private var survivalTextView: UITextView?
    private var survivalPlaceholder: UILabel?
    private var survivalSendButton: UIButton?
    private var installedNativeChromeUserScript = false
    private var signalTint: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 73 / 255, green: 168 / 255, blue: 1, alpha: 1)
                : UIColor(red: 0, green: 111 / 255, blue: 185 / 255, alpha: 1)
        }
    }

    override func capacitorDidLoad() {
        bridge?.registerPluginInstance(SafeRelayFoundationModelsPlugin())
        bridge?.registerPluginInstance(SafeRelayNativeMeshPlugin())
        installNativeChrome()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        installNativeChrome()
        if let nativeTabBar {
            view.bringSubviewToFront(nativeTabBar)
        }
        if let fieldToolsControl {
            view.bringSubviewToFront(fieldToolsControl)
        }
        if let sosTypeControl {
            view.bringSubviewToFront(sosTypeControl)
        }
        if let nativeSOSButton {
            view.bringSubviewToFront(nativeSOSButton)
        }
        if let nativeMapControls, !nativeMapControls.isHidden {
            view.bringSubviewToFront(nativeMapControls)
        }
        if let nativeBeaconButton {
            view.bringSubviewToFront(nativeBeaconButton)
        }
        bringNativeSonicControlsToFront()
        if let survivalComposerContainer {
            view.bringSubviewToFront(survivalComposerContainer)
        }
        exposeNativeChromeToJac()
        scheduleNativeControlSync()
    }

    private func installNativeChrome() {
        installNativeTabBar()
        installNativeMapControls()
        installFieldToolsControl()
        installSOSTypeControl()
        installNativeSOSButton()
        installNativeBeaconButton()
        installNativeSonicControls()
        installNativeSurvivalComposer()
    }

    private func installNativeTabBar() {
        guard nativeTabBar == nil else { return }

        let tabBar = UITabBar()
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.delegate = self
        tabBar.itemPositioning = .automatic
        tabBar.isTranslucent = true
        tabBar.tintColor = signalTint
        tabBar.unselectedItemTintColor = .secondaryLabel
        tabBar.items = nativeTabs.enumerated().map(makeTabBarItem)
        tabBar.selectedItem = tabBar.items?.first

        view.addSubview(tabBar)
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tabBar.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -SafeRelayMetrics.nativeTabBarContentHeight
            )
        ])

        nativeTabBar = tabBar
        exposeNativeChromeToJac()
    }

    private func installNativeMapControls() {
        guard nativeMapControls == nil else { return }

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 7
        stack.isHidden = true
        stack.accessibilityIdentifier = "native-map-controls"

        for (index, action) in nativeMapActions.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.accessibilityIdentifier = "native-\(action.elementID)"
            button.accessibilityLabel = action.label
            button.configuration = nativeMapButtonConfiguration(
                symbol: action.symbol,
                highlighted: action.elementID == "map-locate"
            )
            button.layer.shadowColor = UIColor.black.cgColor
            button.layer.shadowOpacity = 0.2
            button.layer.shadowRadius = 12
            button.layer.shadowOffset = CGSize(width: 0, height: 6)
            button.addTarget(
                self,
                action: #selector(nativeMapControlPressed(_:)),
                for: .touchUpInside
            )
            button.heightAnchor.constraint(equalToConstant: 42).isActive = true
            stack.addArrangedSubview(button)
            if action.elementID == "map-locate" {
                nativeMapLocateButton = button
            }
        }

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 12
            ),
            stack.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -12
            ),
            stack.widthAnchor.constraint(equalToConstant: 42)
        ])

        nativeMapControls = stack
        updateNativeMapLocateButton(locationReady: false, locating: false)
    }

    private func nativeMapButtonConfiguration(
        symbol: String,
        highlighted: Bool = false
    ) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.glass()
        configuration.buttonSize = .medium
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = highlighted ? signalTint : .label
        configuration.image = UIImage(systemName: symbol)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 17,
            weight: .semibold
        )
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 9,
            leading: 9,
            bottom: 9,
            trailing: 9
        )
        return configuration
    }

    private func updateNativeMapLocateButton(
        locationReady: Bool,
        locating: Bool
    ) {
        guard let button = nativeMapLocateButton else { return }
        var configuration = nativeMapButtonConfiguration(
            symbol: locationReady ? "location.fill" : "location",
            highlighted: true
        )
        configuration.image = locating ? nil : configuration.image
        configuration.showsActivityIndicator = locating
        button.configuration = configuration
        button.isEnabled = !locating
        button.accessibilityValue = locating
            ? "Locating"
            : (locationReady ? "Location available" : "Location unavailable")
    }

    @objc private func nativeMapControlPressed(_ sender: UIButton) {
        guard nativeMapActions.indices.contains(sender.tag) else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let action = nativeMapActions[sender.tag]
        clickJacElement(action.elementID) { [weak sender] accepted in
            guard !accepted else { return }
            sender?.accessibilityValue = "Map action unavailable"
        }
    }

    private func installFieldToolsControl() {
        guard fieldToolsControl == nil else { return }

        let control = UISegmentedControl(items: fieldTools.map(\.title))
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        configureSegmentedControl(control)
        control.isHidden = true
        control.accessibilityIdentifier = "native-field-tool"
        control.accessibilityLabel = "Field tool"
        control.addTarget(
            self,
            action: #selector(fieldToolSelectionChanged(_:)),
            for: .valueChanged
        )

        view.addSubview(control)
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            control.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            control.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 72
            ),
            control.heightAnchor.constraint(equalToConstant: 34)
        ])

        fieldToolsControl = control
    }

    private func installSOSTypeControl() {
        guard sosTypeControl == nil else { return }

        let control = UISegmentedControl(items: sosTypes.map(\.title))
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegmentIndex = 0
        configureSegmentedControl(control)
        control.isHidden = true
        control.accessibilityIdentifier = "native-sos-type"
        control.accessibilityLabel = "Emergency type"
        control.addTarget(
            self,
            action: #selector(sosTypeSelectionChanged(_:)),
            for: .valueChanged
        )

        view.addSubview(control)
        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            control.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            control.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: 70
            ),
            control.heightAnchor.constraint(equalToConstant: 44)
        ])

        sosTypeControl = control
        updateSOSTypeTint(for: 0)
    }

    private func installNativeSOSButton() {
        guard nativeSOSButton == nil else { return }

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        button.alpha = 0
        button.accessibilityIdentifier = "native-sos-action"
        button.accessibilityLabel = "SOS"
        button.accessibilityHint = "Tap to start broadcasting. Tap again to stop."
        button.addTarget(
            self,
            action: #selector(nativeSOSButtonPressed),
            for: .touchUpInside
        )
        button.addTarget(
            self,
            action: #selector(nativeSOSButtonTouchDown),
            for: .touchDown
        )

        view.addSubview(button)
        let topConstraint = button.topAnchor.constraint(
            equalTo: view.topAnchor,
            constant: 330
        )
        let widthConstraint = button.widthAnchor.constraint(equalToConstant: 272)
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 272)
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topConstraint,
            widthConstraint,
            heightConstraint
        ])

        nativeSOSButton = button
        nativeSOSButtonTopConstraint = topConstraint
        nativeSOSButtonWidthConstraint = widthConstraint
        nativeSOSButtonHeightConstraint = heightConstraint
        updateNativeSOSButton(
            active: false,
            busy: false,
            status: "Rescue"
        )
    }

    private func updateNativeSOSButton(
        active: Bool,
        busy: Bool,
        status: String,
        stage: String = "idle",
        message: String = ""
    ) {
        guard let button = nativeSOSButton else { return }

        var configuration = UIButton.Configuration.prominentGlass()
        configuration.buttonSize = .large
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = sosColor(for: status)
        configuration.baseForegroundColor = .white
        configuration.title = "SOS"
        configuration.subtitle = nativeSOSSubtitle(
            active: active,
            status: status,
            stage: stage
        )
        configuration.titleAlignment = .center
        configuration.image = busy
            ? nil
            : UIImage(
                systemName: active
                    ? "stop.fill"
                    : "antenna.radiowaves.left.and.right"
            )
        configuration.imagePlacement = .top
        configuration.imagePadding = 12
        configuration.showsActivityIndicator = busy
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 42,
            weight: .bold
        )
        configuration.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 46, weight: .black)
                return outgoing
            }
        configuration.subtitleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 12, weight: .bold)
                return outgoing
            }

        button.configuration = configuration
        button.isEnabled = !busy
        button.accessibilityValue = message.isEmpty
            ? (busy ? "Working" : (active ? "Broadcasting, tap to stop" : "Ready"))
            : message
        setNativeSOSPulseAnimation(active || busy)
    }

    private func sosColor(for status: String) -> UIColor {
        switch status.lowercased() {
        case "medical":
            return UIColor(red: 1, green: 123 / 255, blue: 84 / 255, alpha: 1)
        case "trapped":
            return UIColor(red: 1, green: 176 / 255, blue: 32 / 255, alpha: 1)
        case "supplies":
            return UIColor(red: 72 / 255, green: 199 / 255, blue: 142 / 255, alpha: 1)
        default:
            return UIColor(red: 1, green: 77 / 255, blue: 94 / 255, alpha: 1)
        }
    }

    private func installNativeBeaconButton() {
        guard nativeBeaconButton == nil else { return }

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        button.accessibilityIdentifier = "native-strobe-action"
        button.accessibilityLabel = "Visual beacon"
        button.accessibilityHint = "Starts or stops the device torch strobe"
        button.addTarget(
            self,
            action: #selector(nativeBeaconButtonPressed),
            for: .touchUpInside
        )

        view.addSubview(button)
        let leadingConstraint = button.leadingAnchor.constraint(
            equalTo: view.leadingAnchor,
            constant: 16
        )
        let topConstraint = button.topAnchor.constraint(
            equalTo: view.topAnchor,
            constant: 260
        )
        let widthConstraint = button.widthAnchor.constraint(equalToConstant: 320)
        let heightConstraint = button.heightAnchor.constraint(equalToConstant: 76)
        NSLayoutConstraint.activate([
            leadingConstraint,
            topConstraint,
            widthConstraint,
            heightConstraint
        ])

        nativeBeaconButton = button
        nativeBeaconButtonLeadingConstraint = leadingConstraint
        nativeBeaconButtonTopConstraint = topConstraint
        nativeBeaconButtonWidthConstraint = widthConstraint
        nativeBeaconButtonHeightConstraint = heightConstraint
        updateNativeBeaconButton(active: false)
    }

    private func updateNativeBeaconButton(active: Bool) {
        guard let button = nativeBeaconButton else { return }

        var configuration = UIButton.Configuration.prominentGlass()
        configuration.buttonSize = .large
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = active ? .systemRed : .systemYellow
        configuration.baseForegroundColor = active ? .white : .black
        configuration.title = active ? "STOP STROBE" : "START STROBE"
        configuration.image = UIImage(
            systemName: active ? "stop.fill" : "flashlight.on.fill"
        )
        configuration.imagePadding = 9
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: 19,
            weight: .bold
        )
        configuration.titleTextAttributesTransformer =
            UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 15, weight: .bold)
                return outgoing
            }

        button.configuration = configuration
        button.accessibilityValue = active ? "Active" : "Ready"
        button.accessibilityTraits = active ? [.button, .selected] : .button
    }

    @objc private func nativeBeaconButtonPressed() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        clickJacElement("strobe-action") { [weak self] accepted in
            guard !accepted else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            self?.nativeBeaconButton?.accessibilityValue = "App action unavailable"
        }
    }

    private func installNativeSonicControls() {
        guard nativeSonicSlider == nil else { return }

        let slider = UISlider(frame: .zero)
        slider.isHidden = true
        slider.minimumValue = 15_000
        slider.maximumValue = 19_000
        slider.value = 17_000
        slider.isContinuous = true
        slider.minimumTrackTintColor = signalTint
        slider.accessibilityIdentifier = "native-sonic-base-frequency"
        slider.accessibilityLabel = "Sonic base frequency"
        slider.addTarget(
            self,
            action: #selector(nativeSonicSliderChanged(_:)),
            for: .valueChanged
        )

        let sendButton = UIButton(type: .system)
        sendButton.isHidden = true
        sendButton.accessibilityIdentifier = "native-sonic-send"
        sendButton.accessibilityLabel = "Send sonic SOS"
        sendButton.accessibilityHint = "Transmits the SOS packet ultrasonically"
        sendButton.addTarget(
            self,
            action: #selector(nativeSonicSendPressed),
            for: .touchUpInside
        )

        let listenButton = UIButton(type: .system)
        listenButton.isHidden = true
        listenButton.accessibilityIdentifier = "native-sonic-listen"
        listenButton.accessibilityLabel = "Listen for sonic packets"
        listenButton.accessibilityHint = "Starts or stops the ultrasonic receiver"
        listenButton.addTarget(
            self,
            action: #selector(nativeSonicListenPressed),
            for: .touchUpInside
        )

        view.addSubview(slider)
        view.addSubview(sendButton)
        view.addSubview(listenButton)
        nativeSonicSlider = slider
        nativeSonicSendButton = sendButton
        nativeSonicListenButton = listenButton
        updateNativeSonicControls(baseFrequency: 17_000, listening: false)
    }

    private func updateNativeSonicControls(
        baseFrequency: Float,
        listening: Bool
    ) {
        let steppedFrequency = (baseFrequency / 250).rounded() * 250
        nativeSonicSlider?.setValue(steppedFrequency, animated: false)
        nativeSonicSlider?.accessibilityValue = String(
            format: "%.2f kilohertz",
            steppedFrequency / 1_000
        )

        var sendConfiguration = UIButton.Configuration.prominentGlass()
        sendConfiguration.buttonSize = .medium
        sendConfiguration.cornerStyle = .capsule
        sendConfiguration.baseBackgroundColor = .systemRed
        sendConfiguration.baseForegroundColor = .white
        sendConfiguration.title = "SEND SOS"
        sendConfiguration.image = UIImage(systemName: "waveform.path")
        sendConfiguration.imagePadding = 7
        nativeSonicSendButton?.configuration = sendConfiguration

        var listenConfiguration = listening
            ? UIButton.Configuration.prominentGlass()
            : UIButton.Configuration.glass()
        listenConfiguration.buttonSize = .medium
        listenConfiguration.cornerStyle = .capsule
        listenConfiguration.baseBackgroundColor = listening
            ? .systemRed
            : signalTint
        listenConfiguration.baseForegroundColor = listening
            ? .white
            : signalTint
        listenConfiguration.title = listening ? "STOP RX" : "LISTEN"
        listenConfiguration.image = UIImage(
            systemName: listening ? "stop.fill" : "headphones"
        )
        listenConfiguration.imagePadding = 7
        nativeSonicListenButton?.configuration = listenConfiguration
        nativeSonicListenButton?.accessibilityValue = listening
            ? "Listening"
            : "Stopped"
        nativeSonicListenButton?.accessibilityTraits = listening
            ? [.button, .selected]
            : .button
    }

    @objc private func nativeSonicSliderChanged(_ sender: UISlider) {
        let steppedFrequency = (sender.value / 250).rounded() * 250
        sender.value = steppedFrequency
        sender.accessibilityValue = String(
            format: "%.2f kilohertz",
            steppedFrequency / 1_000
        )
        setJacRangeValue(
            elementID: "sonic-base-frequency",
            value: steppedFrequency
        )
    }

    @objc private func nativeSonicSendPressed() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
        clickJacElement("sonic-send-action") { [weak self] accepted in
            guard !accepted else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            self?.nativeSonicSendButton?.accessibilityValue = "App action unavailable"
        }
    }

    @objc private func nativeSonicListenPressed() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        clickJacElement("sonic-listen-action") { [weak self] accepted in
            guard !accepted else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            self?.nativeSonicListenButton?.accessibilityValue = "App action unavailable"
        }
    }

    @objc private func nativeSOSButtonTouchDown() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.72)
        animateNativeSOSTap()
    }

    @objc private func nativeSOSButtonPressed() {
        clickJacElement("distress-command") { [weak self] accepted in
            guard !accepted else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            self?.showNativeSOSBridgeFailure()
        }
    }

    private func nativeSOSSubtitle(
        active: Bool,
        status: String,
        stage: String
    ) -> String {
        if active && stage == "accepted" {
            return "BROADCASTING • TAP TO STOP"
        }
        if active && stage == "queued" {
            return "SOS ACTIVE • TAP TO STOP"
        }
        if active && (stage == "blocked" || stage == "failed") {
            return "SOS ACTIVE • TAP TO STOP"
        }
        switch stage {
        case "locating": return "ACQUIRING POSITION"
        case "saving": return "SAVING ON DEVICE"
        case "stopping": return "STOPPING BROADCAST"
        case "starting-radio": return "STARTING RADIO"
        case "broadcasting": return "BROADCASTING"
        case "accepted": return "BROADCAST ACTIVE"
        case "queued": return "SOS ACTIVE • RETRY QUEUED"
        case "stopped": return "BROADCAST STOPPED"
        case "stop-queued": return "STOPPED • RADIO RETRY QUEUED"
        case "blocked": return "POSITION REQUIRED"
        case "failed": return "TAP TO RETRY"
        default: return "START \(status.uppercased()) BROADCAST"
        }
    }

    private func animateNativeSOSTap() {
        guard let button = nativeSOSButton else { return }
        button.layer.removeAnimation(forKey: "saferelay-sos-tap")
        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [1, 0.92, 1.08, 1]
        pulse.keyTimes = [0, 0.2, 0.62, 1]
        pulse.duration = 0.52
        pulse.timingFunctions = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .easeOut),
            CAMediaTimingFunction(name: .easeInEaseOut),
        ]
        button.layer.add(pulse, forKey: "saferelay-sos-tap")
    }

    private func setNativeSOSPulseAnimation(_ active: Bool) {
        guard let button = nativeSOSButton else { return }
        let key = "saferelay-sos-pulse"
        if !active {
            button.layer.removeAnimation(forKey: key)
            return
        }
        guard button.layer.animation(forKey: key) == nil else { return }
        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [1, 1.055, 0.995, 1.035, 1, 1]
        pulse.keyTimes = [0, 0.12, 0.25, 0.36, 0.5, 1]
        pulse.duration = 1.35
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        button.layer.add(pulse, forKey: key)
    }

    private func showNativeSOSBridgeFailure() {
        guard let button = nativeSOSButton else { return }
        var configuration = button.configuration
        configuration?.showsActivityIndicator = false
        configuration?.subtitle = "APP ACTION UNAVAILABLE"
        button.configuration = configuration
        button.accessibilityValue = "The app action did not accept the tap"
    }

    private func installNativeSurvivalComposer() {
        guard survivalComposerContainer == nil, let nativeTabBar else { return }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isHidden = true
        container.accessibilityIdentifier = "native-survival-composer"
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.24
        container.layer.shadowRadius = 18
        container.layer.shadowOffset = CGSize(width: 0, height: 9)

        let glassEffect = UIGlassEffect(style: .regular)
        glassEffect.isInteractive = true
        glassEffect.tintColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.18, alpha: 0.46)
                : UIColor(white: 1, alpha: 0.3)
        }
        let glassView = UIVisualEffectView(effect: glassEffect)
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.layer.cornerCurve = .continuous
        glassView.layer.cornerRadius = SafeRelayMetrics.componentCornerRadius
        glassView.clipsToBounds = true

        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textColor = .label
        textView.tintColor = signalTint
        textView.returnKeyType = .send
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 11, left: 5, bottom: 9, right: 2)
        textView.textContainer.lineFragmentPadding = 0
        textView.accessibilityLabel = "Message Survival Guide"

        let placeholder = UILabel()
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        placeholder.text = "Message Survival Guide"
        placeholder.font = .preferredFont(forTextStyle: .body)
        placeholder.textColor = .placeholderText
        placeholder.isUserInteractionEnabled = false

        let sendButton = UIButton(type: .system)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.glass()
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: "arrow.up")
        configuration.baseForegroundColor = .label
        sendButton.configuration = configuration
        sendButton.isEnabled = false
        sendButton.accessibilityLabel = "Send message"
        sendButton.addTarget(
            self,
            action: #selector(sendNativeSurvivalMessage),
            for: .touchUpInside
        )

        view.addSubview(container)
        container.addSubview(glassView)
        glassView.contentView.addSubview(textView)
        glassView.contentView.addSubview(placeholder)
        glassView.contentView.addSubview(sendButton)

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            container.bottomAnchor.constraint(equalTo: nativeTabBar.topAnchor, constant: -18),
            container.heightAnchor.constraint(equalToConstant: 60),

            glassView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            glassView.topAnchor.constraint(equalTo: container.topAnchor),
            glassView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            sendButton.trailingAnchor.constraint(equalTo: glassView.contentView.trailingAnchor, constant: -8),
            sendButton.centerYAnchor.constraint(equalTo: glassView.contentView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 44),
            sendButton.heightAnchor.constraint(equalToConstant: 44),

            textView.leadingAnchor.constraint(equalTo: glassView.contentView.leadingAnchor, constant: 14),
            textView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            textView.topAnchor.constraint(equalTo: glassView.contentView.topAnchor, constant: 4),
            textView.bottomAnchor.constraint(equalTo: glassView.contentView.bottomAnchor, constant: -4),

            placeholder.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 5),
            placeholder.centerYAnchor.constraint(equalTo: textView.centerYAnchor)
        ])

        survivalComposerContainer = container
        survivalTextView = textView
        survivalPlaceholder = placeholder
        survivalSendButton = sendButton
    }

    private func configureSegmentedControl(_ control: UISegmentedControl) {
        control.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 20 / 255, green: 27 / 255, blue: 35 / 255, alpha: 1)
                : UIColor(white: 0.97, alpha: 1)
        }
        control.isOpaque = true
        control.selectedSegmentTintColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 42 / 255, green: 53 / 255, blue: 65 / 255, alpha: 1)
                : .white
        }
        control.layer.cornerCurve = .continuous
        control.layer.cornerRadius = SafeRelayMetrics.componentCornerRadius
        control.layer.shadowColor = UIColor.black.cgColor
        control.layer.shadowOpacity = 0.16
        control.layer.shadowRadius = 12
        control.layer.shadowOffset = CGSize(width: 0, height: 6)
        control.setTitleTextAttributes(
            [.foregroundColor: UIColor.secondaryLabel],
            for: .normal
        )
        control.setTitleTextAttributes(
            [.foregroundColor: UIColor.label],
            for: .selected
        )
    }

    private func makeTabBarItem(index: Int, tab: NativeTab) -> UITabBarItem {
        let symbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: 19,
            weight: tab.isSOS ? .bold : .medium
        )
        var image = UIImage(
            systemName: tab.symbol,
            withConfiguration: symbolConfiguration
        )
        if tab.isSOS {
            image = image?.withTintColor(.systemRed, renderingMode: .alwaysOriginal)
        }

        let item = UITabBarItem(
            title: tab.title,
            image: image,
            selectedImage: image
        )
        item.tag = index
        item.accessibilityIdentifier = "native-\(tab.elementID)"
        item.accessibilityHint = tab.isSOS
            ? "Opens distress broadcasting controls"
            : "Opens the \(tab.title) workspace"
        if tab.isSOS {
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.systemRed
            ]
            item.setTitleTextAttributes(titleAttributes, for: .normal)
            item.setTitleTextAttributes(titleAttributes, for: .selected)
        }
        return item
    }

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        activateNativeTab(at: item.tag)
    }

    private func activateNativeTab(at index: Int) {
        guard nativeTabs.indices.contains(index) else { return }
        let tab = nativeTabs[index]
        updateNativeControlVisibility(for: index)

        if tab.isSOS {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }

        clickJacElement(tab.elementID)
    }

    private func updateNativeControlVisibility(for index: Int) {
        guard nativeTabs.indices.contains(index) else { return }
        let tab = nativeTabs[index]
        nativeTabBar?.selectedItem = nativeTabBar?.items?[index]
        nativeTabBar?.tintColor = tab.isSOS ? .systemRed : signalTint
        fieldToolsControl?.isHidden = tab.elementID != "nav-tools"
        sosTypeControl?.isHidden = !tab.isSOS
        nativeMapControls?.isHidden = tab.elementID != "nav-map"
        setNativeBeaconButtonVisible(
            tab.elementID == "nav-tools"
                && fieldToolsControl?.selectedSegmentIndex == 2
        )
        setNativeSonicControlsVisible(
            tab.elementID == "nav-tools"
                && fieldToolsControl?.selectedSegmentIndex == 3
        )
        webView?.isUserInteractionEnabled = true
        setNativeSOSButtonVisible(tab.isSOS)
        if tab.elementID == "nav-tools", let fieldToolsControl {
            view.bringSubviewToFront(fieldToolsControl)
        }
        if tab.isSOS, let sosTypeControl {
            view.bringSubviewToFront(sosTypeControl)
        }
        if tab.isSOS, let nativeSOSButton {
            view.bringSubviewToFront(nativeSOSButton)
        }
        if tab.elementID == "nav-map", let nativeMapControls {
            view.bringSubviewToFront(nativeMapControls)
        }
        if tab.elementID == "nav-tools",
           fieldToolsControl?.selectedSegmentIndex == 2,
           let nativeBeaconButton {
            view.bringSubviewToFront(nativeBeaconButton)
        }
        if tab.elementID == "nav-tools",
           fieldToolsControl?.selectedSegmentIndex == 3 {
            bringNativeSonicControlsToFront()
        }
        updateSurvivalComposerVisibility(activeTabID: tab.elementID)
    }

    private func setNativeBeaconButtonVisible(_ visible: Bool) {
        guard let button = nativeBeaconButton else { return }
        button.isHidden = !visible
        if visible {
            view.bringSubviewToFront(button)
        }
    }

    private func setNativeSonicControlsVisible(_ visible: Bool) {
        let controls = [
            nativeSonicSlider,
            nativeSonicSendButton,
            nativeSonicListenButton,
        ].compactMap({ $0 })
        let shouldShow = visible && controls.allSatisfy { !$0.frame.isEmpty }
        controls.forEach { $0.isHidden = !shouldShow }
        if shouldShow {
            bringNativeSonicControlsToFront()
        }
    }

    private func bringNativeSonicControlsToFront() {
        for control in [
            nativeSonicSlider,
            nativeSonicSendButton,
            nativeSonicListenButton,
        ].compactMap({ $0 }) {
            view.bringSubviewToFront(control)
        }
    }

    private func setNativeSOSButtonVisible(_ visible: Bool) {
        guard let button = nativeSOSButton else { return }

        if visible {
            guard button.isHidden else { return }
            button.isHidden = false
            button.alpha = 0
            button.transform = CGAffineTransform(scaleX: 0.82, y: 0.82)
            UIView.animate(
                withDuration: 0.46,
                delay: 0,
                usingSpringWithDamping: 0.72,
                initialSpringVelocity: 0.55,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                button.alpha = 1
                button.transform = .identity
            }
            return
        }

        guard !button.isHidden else { return }
        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            options: [.beginFromCurrentState, .curveEaseIn]
        ) {
            button.alpha = 0
            button.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            guard button.alpha == 0 else { return }
            button.isHidden = true
        }
    }

    @objc private func fieldToolSelectionChanged(_ sender: UISegmentedControl) {
        guard fieldTools.indices.contains(sender.selectedSegmentIndex) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        let tool = fieldTools[sender.selectedSegmentIndex]
        setNativeBeaconButtonVisible(sender.selectedSegmentIndex == 2)
        setNativeSonicControlsVisible(sender.selectedSegmentIndex == 3)
        updateSurvivalComposerVisibility(activeTabID: "nav-tools")
        clickJacElement(tool.elementID)
    }

    @objc private func sosTypeSelectionChanged(_ sender: UISegmentedControl) {
        guard sosTypes.indices.contains(sender.selectedSegmentIndex) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        updateSOSTypeTint(for: sender.selectedSegmentIndex)
        let type = sosTypes[sender.selectedSegmentIndex]
        clickJacElement(type.elementID)
    }

    private func clickJacElement(
        _ elementID: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        let script = """
        (() => {
          const element = document.getElementById('\(elementID)');
          if (!element || element.disabled) return false;
          element.click();
          return true;
        })();
        """
        webView?.evaluateJavaScript(script) { [weak self] result, error in
            self?.scheduleNativeControlSync()
            completion?(error == nil && (result as? Bool) == true)
        }
    }

    private func setJacRangeValue(elementID: String, value: Float) {
        let script = """
        (() => {
          const element = document.getElementById('\(elementID)');
          if (!(element instanceof HTMLInputElement)) return false;
          const setter = Object.getOwnPropertyDescriptor(
            HTMLInputElement.prototype,
            'value'
          )?.set;
          setter?.call(element, '\(value)');
          element.dispatchEvent(new Event('input', { bubbles: true }));
          element.dispatchEvent(new Event('change', { bubbles: true }));
          return true;
        })();
        """
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    private func updateSOSTypeTint(for index: Int) {
        guard let control = sosTypeControl else { return }
        let colors: [UIColor] = [
            .systemRed,
            .systemOrange,
            .systemYellow,
            .systemGreen
        ]
        let color = colors.indices.contains(index) ? colors[index] : .systemRed
        control.tintColor = color
        control.setTitleTextAttributes(
            [.foregroundColor: color],
            for: .selected
        )
    }

    private func updateSurvivalComposerVisibility(activeTabID: String) {
        let shouldShow = activeTabID == "nav-tools"
            && fieldToolsControl?.selectedSegmentIndex == 0
        survivalComposerContainer?.isHidden = !shouldShow
        if shouldShow, let survivalComposerContainer {
            view.bringSubviewToFront(survivalComposerContainer)
        } else {
            survivalTextView?.resignFirstResponder()
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        let hasMessage = !textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        survivalPlaceholder?.isHidden = !textView.text.isEmpty
        survivalSendButton?.isEnabled = hasMessage
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        if text == "\n" {
            sendNativeSurvivalMessage()
            return false
        }
        return true
    }

    @objc private func sendNativeSurvivalMessage() {
        guard let textView = survivalTextView else { return }
        let message = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty,
              let data = try? JSONSerialization.data(
                withJSONObject: message,
                options: .fragmentsAllowed
              ),
              let literal = String(data: data, encoding: .utf8) else { return }

        let script = """
        (() => {
          const input = document.querySelector('.survival-composer textarea');
          const send = document.querySelector('.survival-send');
          if (!input || !send) return false;
          const setter = Object.getOwnPropertyDescriptor(
            window.HTMLTextAreaElement.prototype,
            'value'
          )?.set;
          setter?.call(input, \(literal));
          input.dispatchEvent(new Event('input', { bubbles: true }));
          input.dispatchEvent(new Event('change', { bubbles: true }));
          window.setTimeout(() => send.click(), 40);
          return true;
        })();
        """
        webView?.evaluateJavaScript(script) { [weak self] result, _ in
            guard (result as? Bool) == true else { return }
            DispatchQueue.main.async {
                textView.text = ""
                self?.textViewDidChange(textView)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func exposeNativeChromeToJac() {
        let script = """
        document.documentElement.classList.add('native-liquid-glass');
        document.querySelector('.app-header')?.setAttribute('aria-hidden', 'true');
        document.querySelector('.bottom-nav')?.setAttribute('aria-hidden', 'true');
        true;
        """
        if !installedNativeChromeUserScript {
            webView?.configuration.userContentController.addUserScript(
                WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )
            installedNativeChromeUserScript = true
        }
        webView?.evaluateJavaScript(script) { [weak self] _, _ in
            self?.scheduleNativeControlSync()
        }
    }

    private func scheduleNativeControlSync() {
        for delay in [0.1, 0.45, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.syncNativeControlsFromJac()
            }
        }
    }

    private func syncNativeControlsFromJac() {
        let script = """
        (() => {
          const activeTab = document.querySelector('.bottom-nav button.active');
          const activeTool = document.querySelector('.field-tools-switch button.active');
          const selectedSOS = document.querySelector('.sos-type-switch button[aria-checked="true"]');
          const sosAction = document.querySelector('.distress-command');
          const beaconAction = document.getElementById('strobe-action');
          const sonicBase = document.getElementById('sonic-base-frequency');
          const sonicSend = document.getElementById('sonic-send-action');
          const sonicListen = document.getElementById('sonic-listen-action');
          const mapLocate = document.getElementById('map-locate');
          const settings = document.getElementById('native-settings-state');
          const sosRect = sosAction?.getBoundingClientRect();
          const beaconRect = beaconAction?.getBoundingClientRect();
          const controlRect = (element) => {
            const rect = element?.getBoundingClientRect();
            return rect ? {
              x: rect.x,
              y: rect.y,
              width: rect.width,
              height: rect.height
            } : null;
          };
          return {
            tab: activeTab?.id ?? 'nav-home',
            tool: activeTool?.id ?? 'tool-guide',
            sos: selectedSOS?.id ?? 'sos-rescue',
            settings: settings ? {
              meshActive: settings.dataset.meshActive === 'true',
              busy: settings.dataset.busy === 'true',
              meshMessage: settings.dataset.meshMessage ?? '',
              batteryMode: settings.dataset.batteryMode ?? 'Bridge',
              themeMode: settings.dataset.themeMode ?? 'System',
              autoDownloadMaps: settings.dataset.autoDownloadMaps === 'true',
              showNotifications: settings.dataset.showNotifications === 'true',
              bluetoothPermission: settings.dataset.bluetoothPermission ?? 'unknown',
              notificationPermission: settings.dataset.notificationPermission ?? 'unknown',
              backgroundState: settings.dataset.backgroundState ?? 'unknown',
              networkState: settings.dataset.networkState ?? 'unknown',
              cloudConfigured: settings.dataset.cloudConfigured === 'true',
              cloudReachable: settings.dataset.cloudReachable === 'true',
              cloudMessage: settings.dataset.cloudMessage ?? '',
              locationReady: settings.dataset.locationReady === 'true',
              locationMessage: settings.dataset.locationMessage ?? '',
              foundationAvailable: settings.dataset.foundationAvailable === 'true',
              foundationStatus: settings.dataset.foundationStatus ?? 'not checked',
              offlineTiles: Number(settings.dataset.offlineTiles ?? 0),
              queuedPackets: Number(settings.dataset.queuedPackets ?? 0),
              syncReceipts: Number(settings.dataset.syncReceipts ?? 0),
              packetCount: Number(settings.dataset.packetCount ?? 0),
              syncRecordCount: Number(settings.dataset.syncRecordCount ?? 0),
              platform: settings.dataset.platform ?? 'ios',
              pluginVersion: settings.dataset.pluginVersion ?? 'unknown'
            } : null,
            sosAction: sosAction ? {
              active: sosAction.classList.contains('active'),
              busy: sosAction.disabled,
              stage: sosAction.dataset.state ?? 'idle',
              message: sosAction.dataset.message ?? '',
              status: sosAction.querySelector('small')?.textContent ?? 'Rescue',
              rect: sosRect ? {
                top: sosRect.top,
                width: sosRect.width,
                height: sosRect.height
              } : null
            } : null,
            mapAction: mapLocate ? {
              locating: mapLocate.disabled,
              locationReady: mapLocate.classList.contains('has-location')
            } : null,
            beaconAction: beaconAction ? {
              active: beaconAction.classList.contains('active'),
              rect: beaconRect ? {
                x: beaconRect.x,
                y: beaconRect.y,
                width: beaconRect.width,
                height: beaconRect.height
              } : null
            } : null,
            sonicAction: sonicBase && sonicSend && sonicListen ? {
              baseFrequency: Number(sonicBase.value),
              listening: sonicListen.classList.contains('active'),
              sliderRect: controlRect(sonicBase),
              sendRect: controlRect(sonicSend),
              listenRect: controlRect(sonicListen)
            } : null
          };
        })();
        """
        webView?.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self,
                  let values = result as? [String: Any],
                  let tabID = values["tab"] as? String,
                  let tabIndex = nativeTabs.firstIndex(
                    where: { $0.elementID == tabID }
                  ) else { return }

            updateNativeControlVisibility(for: tabIndex)
            if let toolID = values["tool"] as? String,
               let toolIndex = fieldTools.firstIndex(
                   where: { $0.elementID == toolID }
               ) {
                fieldToolsControl?.selectedSegmentIndex = toolIndex
                setNativeBeaconButtonVisible(
                    tabID == "nav-tools" && toolIndex == 2
                )
                setNativeSonicControlsVisible(
                    tabID == "nav-tools" && toolIndex == 3
                )
                updateSurvivalComposerVisibility(activeTabID: tabID)
            }
            if let sosID = values["sos"] as? String,
               let sosIndex = sosTypes.firstIndex(
                   where: { $0.elementID == sosID }
               ) {
                sosTypeControl?.selectedSegmentIndex = sosIndex
                updateSOSTypeTint(for: sosIndex)
            }
            if let action = values["sosAction"] as? [String: Any] {
                updateNativeSOSButton(
                    active: action["active"] as? Bool ?? false,
                    busy: action["busy"] as? Bool ?? false,
                    status: action["status"] as? String ?? "Rescue",
                    stage: action["stage"] as? String ?? "idle",
                    message: action["message"] as? String ?? ""
                )
                if let rect = action["rect"] as? [String: Any] {
                    updateNativeSOSButtonFrame(from: rect)
                }
                if action["busy"] as? Bool == true {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        [weak self] in
                        guard self?.nativeSOSButton?.isHidden == false else { return }
                        self?.syncNativeControlsFromJac()
                    }
                }
            }
            if let action = values["mapAction"] as? [String: Any] {
                let locating = action["locating"] as? Bool ?? false
                updateNativeMapLocateButton(
                    locationReady: action["locationReady"] as? Bool ?? false,
                    locating: locating
                )
                if locating {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        [weak self] in
                        guard self?.nativeMapControls?.isHidden == false else { return }
                        self?.syncNativeControlsFromJac()
                    }
                }
            }
            if let action = values["beaconAction"] as? [String: Any] {
                updateNativeBeaconButton(
                    active: action["active"] as? Bool ?? false
                )
                if let rect = action["rect"] as? [String: Any] {
                    updateNativeBeaconButtonFrame(from: rect)
                }
            }
            if let action = values["sonicAction"] as? [String: Any] {
                let baseFrequency = (action["baseFrequency"] as? NSNumber)
                    .map { $0.floatValue } ?? 17_000
                updateNativeSonicControls(
                    baseFrequency: baseFrequency,
                    listening: action["listening"] as? Bool ?? false
                )
                updateNativeSonicControlFrames(from: action)
            }
            if let settings = values["settings"] as? [String: Any] {
                switch settings["themeMode"] as? String {
                case "Light":
                    overrideUserInterfaceStyle = .light
                case "Dark":
                    overrideUserInterfaceStyle = .dark
                default:
                    overrideUserInterfaceStyle = .unspecified
                }
            }
        }
    }

    private func updateNativeSOSButtonFrame(from rect: [String: Any]) {
        guard
            let top = (rect["top"] as? NSNumber).map(CGFloat.init(truncating:)),
            let reportedWidth = (rect["width"] as? NSNumber).map(CGFloat.init(truncating:)),
            let reportedHeight = (rect["height"] as? NSNumber).map(CGFloat.init(truncating:))
        else { return }

        let width = min(max(reportedWidth, 248), 288)
        let height = min(max(reportedHeight, 248), 288)
        let tabBarTop = nativeTabBar?.frame.minY
            ?? (view.bounds.height - view.safeAreaInsets.bottom - 49)
        let minimumTop = view.safeAreaInsets.top + 156
        let maximumTop = max(minimumTop, tabBarTop - height - 20)
        let clampedTop = min(max(top, minimumTop), maximumTop)

        nativeSOSButtonTopConstraint?.constant = clampedTop
        nativeSOSButtonWidthConstraint?.constant = width
        nativeSOSButtonHeightConstraint?.constant = height
        UIView.animate(
            withDuration: 0.32,
            delay: 0,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]
        ) {
            self.view.layoutIfNeeded()
        }
    }

    private func updateNativeBeaconButtonFrame(from rect: [String: Any]) {
        guard
            let webView,
            let x = (rect["x"] as? NSNumber).map(CGFloat.init(truncating:)),
            let y = (rect["y"] as? NSNumber).map(CGFloat.init(truncating:)),
            let width = (rect["width"] as? NSNumber).map(CGFloat.init(truncating:)),
            let height = (rect["height"] as? NSNumber).map(CGFloat.init(truncating:))
        else { return }

        let webRect = CGRect(x: x, y: y, width: width, height: height)
        let nativeRect = webView.convert(webRect, to: view)
        nativeBeaconButtonLeadingConstraint?.constant = nativeRect.minX
        nativeBeaconButtonTopConstraint?.constant = nativeRect.minY
        nativeBeaconButtonWidthConstraint?.constant = nativeRect.width
        nativeBeaconButtonHeightConstraint?.constant = nativeRect.height
        view.layoutIfNeeded()
    }

    private func updateNativeSonicControlFrames(from action: [String: Any]) {
        if let rect = action["sliderRect"] as? [String: Any] {
            updateNativeSonicControlFrame(
                nativeSonicSlider,
                from: rect,
                minimumHeight: 44
            )
        }
        if let rect = action["sendRect"] as? [String: Any] {
            updateNativeSonicControlFrame(
                nativeSonicSendButton,
                from: rect,
                minimumHeight: 48
            )
        }
        if let rect = action["listenRect"] as? [String: Any] {
            updateNativeSonicControlFrame(
                nativeSonicListenButton,
                from: rect,
                minimumHeight: 48
            )
        }
        let sonicTabActive = nativeTabBar?.selectedItem?.tag == 3
            && fieldToolsControl?.selectedSegmentIndex == 3
        setNativeSonicControlsVisible(sonicTabActive)
    }

    private func updateNativeSonicControlFrame(
        _ control: UIView?,
        from rect: [String: Any],
        minimumHeight: CGFloat
    ) {
        guard
            let control,
            let webView,
            let x = (rect["x"] as? NSNumber).map(CGFloat.init(truncating:)),
            let y = (rect["y"] as? NSNumber).map(CGFloat.init(truncating:)),
            let width = (rect["width"] as? NSNumber).map(CGFloat.init(truncating:)),
            let height = (rect["height"] as? NSNumber).map(CGFloat.init(truncating:))
        else { return }

        let webRect = CGRect(x: x, y: y, width: width, height: height)
        var nativeRect = webView.convert(webRect, to: view)
        if nativeRect.height < minimumHeight {
            nativeRect.origin.y -= (minimumHeight - nativeRect.height) / 2
            nativeRect.size.height = minimumHeight
        }
        control.frame = nativeRect.integral
    }
}
