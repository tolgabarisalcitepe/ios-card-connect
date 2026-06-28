// HomeView.swift
// CardConnect

import SwiftUI

struct HomeView: View {

    @Environment(\.dependencies) private var dependencies
    @State private var profile = UserProfile()
    @State private var avatarImage: Image?

    var body: some View {
        ContactsView()
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    NavigationLink(value: AppRoute.profile) {
                        if profile.fullName.isEmpty {
                            Image(systemName: "person.circle")
                        } else {
                            HomeProfileChipView(profile: profile, avatarImage: avatarImage)
                        }
                    }
                    NavigationLink(value: AppRoute.settings) {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink(value: AppRoute.camera) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await loadProfile() }
            .onAppear { Task { await loadProfile() } }
    }

    // MARK: - Profile loading

    private func loadProfile() async {
        profile = await dependencies.userProfileStore.load()
        guard !profile.avatarPath.isEmpty else { avatarImage = nil; return }
        let url = URL(fileURLWithPath: profile.avatarPath)
        guard let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data) else { avatarImage = nil; return }
        avatarImage = Image(uiImage: uiImage)
    }
}
