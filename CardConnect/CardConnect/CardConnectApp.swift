//
//  CardConnectApp.swift
//  CardConnect
//
//  Created by RiderPanda on 24.06.2026.
//

import SwiftUI
import SwiftData

@main
struct CardConnectApp: App {

    private let modelContainer: ModelContainer = {
        do {
            return try SwiftDataStack.makeContainer()
        } catch {
            fatalError("SwiftData container başlatılamadı: \(error)")
        }
    }()

    private let dependencies: any DependencyContainer = LiveDependencyContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(\.dependencies, dependencies)
        }
    }
}
