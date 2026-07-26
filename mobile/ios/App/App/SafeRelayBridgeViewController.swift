import Capacitor
import UIKit
import WebKit

final class SafeRelayBridgeViewController: CAPBridgeViewController, UITabBarDelegate, UITextViewDelegate {
    private struct NativeTab {
        let elementID: String
        let title: String
        let symbol: String
        let isSOS: Bool
    }

    private let nativeTabs = [
        NativeTab(elementID: "nav-home", title: "Home", symbol: "house.fill", isSOS: false),
        NativeTab(elementID: "nav-map", title: "Map", symbol: "map.fill", isSOS: false),
        NativeTab(elementID: "nav-tools", title: "Tools", symbol: "wrench.and.screwdriver.fill", isSOS: false),
        NativeTab(elementID: "nav-sos", title: "SOS", symbol: "sos.circle.fill", isSOS: true),
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

    private var nativeTabBar: UITabBar?
    private var fieldToolsControl: UISegmentedControl?
    private var sosTypeControl: UISegmentedControl?
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
        if let survivalComposerContainer {
            view.bringSubviewToFront(survivalComposerContainer)
        }
        exposeNativeChromeToJac()
        scheduleNativeControlSync()
    }

    private func installNativeChrome() {
        installNativeTabBar()
        installFieldToolsControl()
        installSOSTypeControl()
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
                constant: -49
            )
        ])

        nativeTabBar = tabBar
        exposeNativeChromeToJac()
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
        glassView.layer.cornerRadius = 30
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
        control.layer.cornerRadius = 10
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
        if tab.elementID == "nav-tools", let fieldToolsControl {
            view.bringSubviewToFront(fieldToolsControl)
        }
        if tab.isSOS, let sosTypeControl {
            view.bringSubviewToFront(sosTypeControl)
        }
        updateSurvivalComposerVisibility(activeTabID: tab.elementID)
    }

    @objc private func fieldToolSelectionChanged(_ sender: UISegmentedControl) {
        guard fieldTools.indices.contains(sender.selectedSegmentIndex) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        let tool = fieldTools[sender.selectedSegmentIndex]
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

    private func clickJacElement(_ elementID: String) {
        webView?.evaluateJavaScript(
            "document.getElementById('\(elementID)')?.click();"
        ) { [weak self] _, _ in
            self?.scheduleNativeControlSync()
        }
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
          return {
            tab: activeTab?.id ?? 'nav-home',
            tool: activeTool?.id ?? 'tool-guide',
            sos: selectedSOS?.id ?? 'sos-rescue'
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
                updateSurvivalComposerVisibility(activeTabID: tabID)
            }
            if let sosID = values["sos"] as? String,
               let sosIndex = sosTypes.firstIndex(
                   where: { $0.elementID == sosID }
               ) {
                sosTypeControl?.selectedSegmentIndex = sosIndex
                updateSOSTypeTint(for: sosIndex)
            }
        }
    }
}
