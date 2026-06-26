// ProfileView.swift
// CardConnect

import SwiftUI
import PhotosUI

struct ProfileView: View {

    @Environment(\.dependencies) private var dependencies
    @StateObject private var viewModel = ProfileViewModel()

    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var showQR = false

    private var isProfileEmpty: Bool {
        viewModel.profile.firstName.isEmpty && viewModel.profile.lastName.isEmpty
    }

    // MARK: - Body

    var body: some View {
        Form {
            avatarSection
            basicInfoSection
            contactSection
            socialSection
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Kaydet") {
                    Task { await viewModel.save(to: dependencies.userProfileStore) }
                }
                .disabled(viewModel.isSaving)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showQR = true
                } label: {
                    Image(systemName: "qrcode")
                }
                .disabled(isProfileEmpty)
            }
        }
        .sheet(isPresented: $showQR) {
            Text("QR Kodu — #132")
                .presentationDetents([.medium])
        }
        .alert("Hata", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("Tamam", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.load(from: dependencies.userProfileStore)
            loadAvatarIfNeeded()
        }
        .onChange(of: avatarItem) { _, newItem in
            Task { await loadAvatar(from: newItem) }
        }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        Section {
            HStack {
                Spacer()
                PhotosPicker(selection: $avatarItem, matching: .images) {
                    avatarContent
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .accentColor)
                                .offset(x: 4, y: 4)
                        }
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let avatarImage {
            avatarImage
                .resizable()
                .scaledToFill()
                .frame(width: 90, height: 90)
                .clipShape(Circle())
        } else {
            InitialsAvatarView(fullName: viewModel.profile.fullName, size: 90)
        }
    }

    private var basicInfoSection: some View {
        Section("Kişisel Bilgiler") {
            TextField("Ad", text: $viewModel.profile.firstName)
                .textContentType(.givenName)
            TextField("Soyad", text: $viewModel.profile.lastName)
                .textContentType(.familyName)
            TextField("Şirket", text: $viewModel.profile.company)
                .textContentType(.organizationName)
            TextField("Ünvan", text: $viewModel.profile.title)
                .textContentType(.jobTitle)
        }
    }

    private var contactSection: some View {
        Section("İletişim") {
            TextField("Telefon", text: $viewModel.profile.phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
            TextField("E-posta", text: $viewModel.profile.email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .textContentType(.emailAddress)
        }
    }

    private var socialSection: some View {
        Section("Sosyal") {
            TextField("LinkedIn URL", text: $viewModel.profile.linkedin)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
            TextField("Web Sitesi", text: $viewModel.profile.website)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
        }
    }

    // MARK: - Avatar helpers

    private func loadAvatarIfNeeded() {
        guard !viewModel.profile.avatarPath.isEmpty else { return }
        let url = URL(fileURLWithPath: viewModel.profile.avatarPath)
        guard let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data) else { return }
        avatarImage = Image(uiImage: uiImage)
    }

    private func loadAvatar(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        avatarImage = Image(uiImage: uiImage)
        if let savedPath = saveAvatar(data: data) {
            viewModel.profile.avatarPath = savedPath
        }
    }

    private func saveAvatar(data: Data) -> String? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_avatar.jpg")
        try? data.write(to: url, options: .atomic)
        return url.path
    }
}
