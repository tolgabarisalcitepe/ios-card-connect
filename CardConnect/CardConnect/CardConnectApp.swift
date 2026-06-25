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

    private let container: ModelContainer = {
        do {
            return try SwiftDataStack.makeContainer()
        } catch {
            fatalError("SwiftData container başlatılamadı: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(container)
        }
    }
}
