// HomeView.swift
// CardConnect

import SwiftUI

struct HomeView: View {

    @Environment(\.dependencies) private var dependencies
    @State private var profile = UserProfile()
    @State private var avatarImage: Image?

    var body: some View {
        coreView
            .task { await loadProfile() }
            .onAppear { Task { await loadProfile() } }
    }

    // MARK: - Core View

    @ViewBuilder
    private var coreView: some View {
        ZStack(alignment: .bottomTrailing) {
            emptyState
            scanFAB
        }
        .navigationTitle("Kişiler")
        .navigationBarTitleDisplayMode(.large)
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

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "creditcard")
                .font(.system(size: 64))
                .foregroundStyle(.secondary.opacity(0.3))
            Text("Henüz kartvizit yok")
                .font(.title2.bold())
            Text("Kameranızı bir kartvizite tutarak başlayın.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - FAB

    private var scanFAB: some View {
        NavigationLink(value: AppRoute.camera) {
            Image(systemName: "camera.viewfinder")
                .font(.title2.weight(.semibold))
                .padding(18)
                .background(Color.accentColor, in: Circle())
                .foregroundStyle(.white)
                .shadow(radius: 4, y: 2)
        }
        .padding(24)
    }

}
