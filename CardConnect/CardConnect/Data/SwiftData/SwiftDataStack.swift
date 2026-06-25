// SwiftDataStack.swift
// CardConnect

import Foundation
import SwiftData
import OSLog

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.cardconnect",
    category: "SwiftDataStack"
)

enum SwiftDataStack {

    static func makeContainer() throws -> ModelContainer {
        let key = dbFilenameKey()
        let schema = Schema(versionedSchema: SchemaV1.self)
        let url = try storeURL(key: key)
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

    static func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Keychain DB Key

    private static func dbFilenameKey() -> String {
        let keychainKey = "db_filename_key"
        do {
            let data = try KeychainStore.load(key: keychainKey)
            return data.map { String(format: "%02x", $0) }.joined()
        } catch KeychainStore.KeychainError.itemNotFound {
            return generateAndStoreKey(keychainKey: keychainKey)
        } catch {
            logger.error("Keychain read error: \(error). Generating new DB key.")
            return generateAndStoreKey(keychainKey: keychainKey)
        }
    }

    private static func generateAndStoreKey(keychainKey: String) -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        try? KeychainStore.save(key: keychainKey, data: Data(bytes))
        return hex
    }

    // MARK: - Store URL

    private static func storeURL(key: String) throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent("CardConnect", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("CardConnect-\(key).sqlite")
    }

    // MARK: - File Protection

    private static func applyFileProtection(to url: URL) throws {
        try (url as NSURL).setResourceValue(
            URLFileProtection.completeUntilFirstUserAuthentication,
            forKey: .fileProtectionKey
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
