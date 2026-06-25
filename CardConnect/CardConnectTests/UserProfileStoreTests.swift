// UserProfileStoreTests.swift
// CardConnectTests

import XCTest
@testable import CardConnect

final class UserProfileStoreTests: XCTestCase {

    private var store: UserProfileStore!

    override func setUp() async throws {
        store = UserProfileStore()
        try await store.deleteProfile()
    }

    override func tearDown() async throws {
        try await store.deleteProfile()
    }

    // MARK: - UserProfile round-trip

    func testSaveAndLoadRoundTrip() async throws {
        var profile = UserProfile()
        profile.firstName = "Ada"
        profile.lastName = "Lovelace"
        profile.email = "ada@example.com"

        try await store.save(profile)
        let loaded = await store.load()

        XCTAssertEqual(loaded.firstName, "Ada")
        XCTAssertEqual(loaded.lastName, "Lovelace")
        XCTAssertEqual(loaded.email, "ada@example.com")
    }

    func testLoadReturnsDefaultWhenMissing() async {
        let profile = await store.load()
        XCTAssertEqual(profile.firstName, "")
        XCTAssertEqual(profile.fullName, "")
    }

    func testPIIDoesNotGoToUserDefaults() async throws {
        var profile = UserProfile()
        profile.firstName = "Secret"
        try await store.save(profile)

        // UserDefaults içinde bu değer olmamalı
        let ud = UserDefaults.standard
        let allKeys = ud.dictionaryRepresentation().keys
        XCTAssertFalse(allKeys.contains { $0.contains("userprofile") })
        XCTAssertFalse(
            ud.dictionaryRepresentation().values
                .compactMap { $0 as? String }
                .contains { $0.contains("Secret") }
        )
    }

    // MARK: - DB Passphrase

    func testDBPassphraseIs32Bytes() async throws {
        let passphrase = try await store.dbPassphrase()
        XCTAssertEqual(passphrase.count, 32)
    }

    func testDBPassphraseIsStable() async throws {
        let first = try await store.dbPassphrase()
        let second = try await store.dbPassphrase()
        XCTAssertEqual(first, second)
    }

    func testDBPassphraseIsRandom() async throws {
        let storeA = UserProfileStore()
        let storeB = UserProfileStore()

        // Temizle, iki bağımsız key üret
        try await storeA.deleteProfile()
        try KeychainStore.delete(key: "com.cardconnect.dbpassphrase")

        let keyA = try await storeA.dbPassphrase()

        try KeychainStore.delete(key: "com.cardconnect.dbpassphrase")

        let keyB = try await storeB.dbPassphrase()

        XCTAssertNotEqual(keyA, keyB)
    }
}
