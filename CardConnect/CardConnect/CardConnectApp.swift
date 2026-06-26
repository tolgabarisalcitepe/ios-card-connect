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
        BackupExclusion.applyAll()
        do {
            let container = try SwiftDataStack.makeContainer()
            EmailTemplateSeeder.seedIfEmpty(in: container.mainContext)
            return container
        } catch {
            fatalError("SwiftData container başlatılamadı: \(error)")
        }
    }()

    private let dependencies: any DependencyContainer = LiveDependencyContainer()

    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .modelContainer(modelContainer)
                .environment(\.dependencies, dependencies)
                .onOpenURL { handleOpen(url: $0) }
        }
    }

    private func handleOpen(url: URL) {
        guard url.pathExtension.lowercased() == "vcf",
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        Task { await dependencies.scanFlow.setIncomingVCard(content) }
    }
}
