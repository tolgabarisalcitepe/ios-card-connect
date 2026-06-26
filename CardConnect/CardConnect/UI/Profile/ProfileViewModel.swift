// ProfileViewModel.swift
// CardConnect

import Foundation

@MainActor final class ProfileViewModel: ObservableObject {

    @Published var profile = UserProfile()
    @Published var isSaving = false
    @Published var errorMessage: String?

    // MARK: - Keychain round-trip

    func load(from store: UserProfileStore) async {
        profile = await store.load()
    }

    func save(to store: UserProfileStore) async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await store.save(profile)
        } catch {
            errorMessage = "Profil kaydedilemedi."
        }
    }
}
