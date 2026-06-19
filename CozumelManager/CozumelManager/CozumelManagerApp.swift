import SwiftUI

@main
struct CozumelManagerApp: App {
    @StateObject private var store = PropertyStore()

    var body: some Scene {
        Window("Cozumel Manager", id: "main") {
            MainDashboardView()
                .environmentObject(store)
        }
    }
}
