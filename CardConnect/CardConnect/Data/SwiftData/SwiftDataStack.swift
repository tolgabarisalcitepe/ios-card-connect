// SwiftDataStack.swift
// CardConnect

import SwiftData
import Foundation

enum SwiftDataStack {

    /// Üretim için ModelContainer.
    /// - DB dosyası Application Support altına yazılır.
    /// - NSFileProtectionCompleteUntilFirstUserAuthentication ile korunur.
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let url = try storeURL()
        let config = ModelConfiguration(
            schema: schema,
            url: url,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(
            for: schema,
            migrationPlan: CardConnectMigrationPlan.self,
            configurations: config
        )
        try applyFileProtection(to: url)
        return container
    }

    /// Testler için in-memory container.
    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Private

    private static func storeURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("CardConnect.sqlite")
    }

    private static func applyFileProtection(to url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }
}

// MARK: - Migration Plan

enum CardConnectMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
