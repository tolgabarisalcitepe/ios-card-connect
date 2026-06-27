// ProfileViewModel.swift
// CardConnect

import Combine
import Foundation

@MainActor final class ProfileViewModel: ObservableObject {

    @Published var profile = UserProfile()
    @Published var isSaving = false
    @Published var errorMessage: String?

    // MARK: - Keychain round-trip

    func load(from store: UserProfileStore) async {
        profile = await store.load()
    }

    /// Kaydeder; başarıysa `true`, hata varsa `false` döner.
    @discardableResult
    func save(to store: UserProfileStore) async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.save(profile)
            return true
        } catch {
            errorMessage = "Profil kaydedilemedi."
            return false
        }
    }
}
