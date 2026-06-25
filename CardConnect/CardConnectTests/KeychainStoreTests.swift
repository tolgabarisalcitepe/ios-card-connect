// KeychainStoreTests.swift
// CardConnectTests

import XCTest
@testable import CardConnect

final class KeychainStoreTests: XCTestCase {

    private let key = "com.cardconnect.test.keychain.\(UUID().uuidString)"

    override func tearDown() async throws {
        try? KeychainStore.delete(key: key)
    }

    func testSaveAndLoad() throws {
        let data = Data("hello".utf8)
        try KeychainStore.save(key: key, data: data)
        let loaded = try KeychainStore.load(key: key)
        XCTAssertEqual(loaded, data)
    }

    func testUpdateOverwrites() throws {
        try KeychainStore.save(key: key, data: Data("first".utf8))
        try KeychainStore.save(key: key, data: Data("second".utf8))
        let loaded = try KeychainStore.load(key: key)
        XCTAssertEqual(loaded, Data("second".utf8))
    }

    func testLoadMissingThrows() {
        XCTAssertThrowsError(try KeychainStore.load(key: key)) { error in
            XCTAssertEqual(error as? KeychainStore.KeychainError, .itemNotFound)
        }
    }

    func testDeleteRemovesItem() throws {
        try KeychainStore.save(key: key, data: Data("x".utf8))
        try KeychainStore.delete(key: key)
        XCTAssertThrowsError(try KeychainStore.load(key: key))
    }

    func testDeleteMissingIsNoop() {
        XCTAssertNoThrow(try KeychainStore.delete(key: key))
    }
}
