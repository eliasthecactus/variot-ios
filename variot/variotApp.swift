//
//  variotApp.swift
//  variot
//
//  Created by Elias Frehner on 04.09.2024.
//

import SwiftUI
import SwiftData

@main
struct variotApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([

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
            ConnectView()
        }
        .modelContainer(sharedModelContainer)
    }
}
