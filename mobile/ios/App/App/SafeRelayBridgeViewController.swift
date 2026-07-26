import Capacitor
import UIKit
import WebKit

final class SafeRelayBridgeViewController: CAPBridgeViewController, UITabBarDelegate {
    private struct NativeTab {
        let elementID: String
        let title: String
        let symbol: String
        let isSOS: Bool
    }

    private let nativeTabs = [
        NativeTab(elementID: "nav-command", title: "Command", symbol: "dot.radiowaves.left.and.right", isSOS: false),
        NativeTab(elementID: "nav-map", title: "Map", symbol: "map.fill", isSOS: false),
        NativeTab(elementID: "nav-sos", title: "SOS", symbol: "sos.circle.fill", isSOS: true),
        NativeTab(elementID: "nav-tools", title: "Tools", symbol: "wrench.and.screwdriver.fill", isSOS: false),
        NativeTab(elementID: "nav-systems", title: "Systems", symbol: "slider.horizontal.3", isSOS: false)
    ]
    private let fieldTools = [
        (elementID: "tool-guide", title: "Guide"),
        (elementID: "tool-compass", title: "Compass"),
        (elementID: "tool-beacon", title: "Beacon"),
        (elementID: "tool-sonic", title: "Sonic")
    ]

    private var nativeTabBar: UITabBar?
    private var fieldToolsControl: UISegmentedControl?
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
        exposeNativeChromeToJac()
    }

    private func installNativeChrome() {
        installNativeTabBar()
        installFieldToolsControl()
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
        control.isHidden = true
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
                constant: 40
            ),
            control.heightAnchor.constraint(equalToConstant: 34)
        ])

        fieldToolsControl = control
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
        nativeTabBar?.selectedItem = nativeTabBar?.items?[index]
        nativeTabBar?.tintColor = tab.isSOS ? .systemRed : signalTint
        fieldToolsControl?.isHidden = tab.elementID != "nav-tools"

        if tab.isSOS {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else {
            UISelectionFeedbackGenerator().selectionChanged()
        }

        webView?.evaluateJavaScript(
            "document.getElementById('\(tab.elementID)')?.click();"
        )
    }

    @objc private func fieldToolSelectionChanged(_ sender: UISegmentedControl) {
        guard fieldTools.indices.contains(sender.selectedSegmentIndex) else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        let tool = fieldTools[sender.selectedSegmentIndex]
        webView?.evaluateJavaScript(
            "document.getElementById('\(tool.elementID)')?.click();"
        )
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
        webView?.evaluateJavaScript(script)
    }
}
