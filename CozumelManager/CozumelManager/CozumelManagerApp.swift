import SwiftUI
import Sparkle

@main
struct CozumelManagerApp: App {
    @StateObject private var store = PropertyStore()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        Window("Cozumel Manager", id: "main") {
            MainDashboardView()
                .environmentObject(store)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
            }
        }
    }
}
