// UserProfileStore.swift
// CardConnect

import Foundation
import Security

actor UserProfileStore {

    // MARK: - Keys

    private let profileKey = "com.cardconnect.userprofile"
    private let dbPassphraseKey = "com.cardconnect.dbpassphrase"

    // MARK: - UserProfile

    func save(_ profile: UserProfile) throws {
        let data = try JSONEncoder().encode(profile)
        try KeychainStore.save(key: profileKey, data: data)
    }

    func load() -> UserProfile {
        guard
            let data = try? KeychainStore.load(key: profileKey),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else {
            return UserProfile()
        }
        return profile
    }

    func deleteProfile() throws {
        try KeychainStore.delete(key: profileKey)
    }

    // MARK: - DB Passphrase

    /// Mevcut 32-byte passphrase'i döner; yoksa üretip Keychain'e kaydeder.
    /// Keychain bozulursa yeni key üretir — çağıran DB'yi sıfırlamalıdır.
    func dbPassphrase() throws -> Data {
        if let existing = try? KeychainStore.load(key: dbPassphraseKey) {
            return existing
        }
        let key = try generateKey()
        try KeychainStore.save(key: dbPassphraseKey, data: key)
        return key
    }

    // MARK: - Private

    private func generateKey() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw KeychainStore.KeychainError.unexpectedStatus(status)
        }
        return Data(bytes)
    }
}
