import SwiftUI

@main
struct PupWeatherApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundRefresher.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await LiveActivityManager.shared.ensureActivityRunning() }
            case .background:
                if LiveActivityManager.shared.isActivityRunning {
                    BackgroundRefresher.schedule()
                }
            default:
                break
            }
        }
    }
}
