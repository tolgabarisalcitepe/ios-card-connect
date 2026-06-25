// KeychainStore.swift
// CardConnect

import Foundation
import Security

enum KeychainStore {

    enum KeychainError: Error, Equatable {
        case itemNotFound
        case unexpectedStatus(OSStatus)
    }

    // MARK: - Save / Update

    static func save(key: String, data: Data) throws {
        var status = SecItemAdd(addQuery(key: key, data: data), nil)

        if status == errSecDuplicateItem {
            status = SecItemUpdate(lookupQuery(key: key), [kSecValueData: data] as CFDictionary)
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Load

    static func load(key: String) throws -> Data {
        var fetchQuery = lookupQuery(key: key) as! [CFString: Any]
        fetchQuery[kSecReturnData] = true
        fetchQuery[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(fetchQuery as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.itemNotFound }
            return data
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Delete

    static func delete(key: String) throws {
        let status = SecItemDelete(lookupQuery(key: key))
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    // MARK: - Private

    private static let service = Bundle.main.bundleIdentifier ?? "com.cardconnect"

    private static func lookupQuery(key: String) -> CFDictionary {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ] as CFDictionary
    }

    private static func addQuery(key: String, data: Data) -> CFDictionary {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as CFDictionary
    }
}
