// HomeView.swift
// CardConnect

import SwiftUI
import SwiftData

struct HomeView: View {

    var onShowAllContacts: () -> Void = {}

    @Environment(\.dependencies) private var dependencies
    @Query(sort: \Contact.updatedAt, order: .reverse) private var contacts: [Contact]
    @State private var profile = UserProfile()
    @State private var avatarImage: Image?

    private var recentContacts: [Contact] { Array(contacts.prefix(5)) }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scanBannerCard
                if !recentContacts.isEmpty {
                    recentSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .navigationTitle("Ana Sayfa")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                NavigationLink(value: AppRoute.profile) {
                    if profile.fullName.isEmpty {
                        Image(systemName: "person.circle")
                            .font(.title3)
                    } else {
                        HomeProfileChipView(profile: profile, avatarImage: avatarImage)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: AppRoute.settings) {
                    Image(systemName: "gearshape")
                }
            }
        }
        .task { await loadProfile() }
        .onAppear { Task { await loadProfile() } }
    }

    // MARK: - Scan Banner

    private var scanBannerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Ağınızı Genişletin")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text("Fiziksel kartvizitleri saniyeler içinde dijital kişilere dönüştürün.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            NavigationLink(value: AppRoute.camera) {
                Label("Kartvizit Tara", systemImage: "camera.viewfinder")
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.white, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Recent Contacts

    private var recentSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Son Kişiler")
                    .font(.headline)
                Spacer()
                Button("Tümünü Gör") { onShowAllContacts() }
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 2)

            VStack(spacing: 0) {
                ForEach(recentContacts) { contact in
                    NavigationLink(value: AppRoute.detail(contactID: contact.id)) {
                        contactRow(contact)
                    }
                    .buttonStyle(.plain)

                    if contact.id != recentContacts.last?.id {
                        Divider().padding(.leading, 58)
                    }
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 0.5)
            }
        }
    }

    private func contactRow(_ contact: Contact) -> some View {
        HStack(spacing: 12) {
            InitialsAvatarView(fullName: contact.fullName, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName.isEmpty ? "—" : contact.fullName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                let subtitle = [contact.company, contact.title]
                    .filter { !$0.isEmpty }.joined(separator: " · ")
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
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
