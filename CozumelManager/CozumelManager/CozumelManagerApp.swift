//
//  CozumelManagerApp.swift
//  CozumelManager
//
//  Created by Fernando Gonzalez on 5/27/26.
//

import SwiftUI
import SwiftData

@main
struct CozumelManagerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Property.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainDashboardView()
        }
        .modelContainer(sharedModelContainer)
    }
}
