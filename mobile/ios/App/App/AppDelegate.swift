import BackgroundTasks
import Capacitor
import OSLog
import UIKit

enum SafeRelayBackgroundRefresh {
    static let taskIdentifier = "com.development.saferelay.refresh"

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.development.saferelay",
        category: "BackgroundRefresh"
    )

    static func register() {
        let registered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            DispatchQueue.main.async {
                guard let refreshTask = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                handle(refreshTask)
            }
        }
        if !registered {
            logger.error("Failed to register app refresh task")
        }
    }

    static func schedule() {
        guard UIApplication.shared.backgroundRefreshStatus == .available,
              SafeRelayMeshService.shared.isEnabled else {
            return
        }

        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.notice("Scheduled app refresh")
        } catch {
            logger.error(
                "App refresh scheduling failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private static func handle(_ task: BGAppRefreshTask) {
        schedule()
        let completion = SafeRelayBackgroundRefreshCompletion(task: task)
        task.expirationHandler = {
            DispatchQueue.main.async {
                completion.finish(success: false)
            }
        }

        guard SafeRelayMeshService.shared.isEnabled else {
            completion.finish(success: true)
            return
        }
        SafeRelayMeshService.shared.start { result in
            completion.finish(success: (try? result.get()) != nil)
        }
    }
}

private final class SafeRelayBackgroundRefreshCompletion {
    private let task: BGAppRefreshTask
    private var finished = false

    init(task: BGAppRefreshTask) {
        self.task = task
    }

    func finish(success: Bool) {
        guard !finished else { return }
        finished = true
        task.expirationHandler = nil
        task.setTaskCompleted(success: success)
    }
}

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        SafeRelayBackgroundRefresh.register()
        SafeRelayMeshService.shared.configureAtLaunch()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
