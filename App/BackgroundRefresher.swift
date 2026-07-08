import BackgroundTasks
import Foundation

/// Refreshes weather and updates the Live Activity while the app is
/// backgrounded. iOS decides exact timing; we ask for ~20 minute intervals,
/// which lands in the plan's 15-30 minute window. Between refreshes the dog
/// keeps animating on its own via the timer-font loop.
enum BackgroundRefresher {
    static let taskIdentifier = "com.pupweather.app.refresh"
    private static let interval: TimeInterval = 20 * 60

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            handle(task: task as! BGAppRefreshTask)
        }
    }

    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(task: BGAppRefreshTask) {
        schedule()  // always keep the chain alive
        let work = Task { @MainActor in
            await LiveActivityManager.shared.refreshAll()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
