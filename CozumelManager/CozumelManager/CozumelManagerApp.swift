import SwiftUI
import Sparkle

@main
struct CozumelManagerApp: App {
    @StateObject private var store = PropertyStore()
    @StateObject private var forSaleStore = ForSaleStore()
    @StateObject private var bookingStore = BookingRequestStore()
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        Window("Cozumel Manager", id: "main") {
            MainDashboardView()
                .environmentObject(store)
                .environmentObject(forSaleStore)
                .environmentObject(bookingStore)
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
