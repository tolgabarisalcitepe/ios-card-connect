// ProfileView.swift
// CardConnect

import SwiftUI
import PhotosUI

struct ProfileView: View {

    var isOnboarding: Bool = false
    var onComplete: (() -> Void)? = nil

    @Environment(\.dependencies) private var dependencies
    @StateObject private var viewModel = ProfileViewModel()

    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var showQR = false
    @State private var showSelfScan = false
    @State private var showPrivacyPolicy = false

    private var isProfileEmpty: Bool {
        viewModel.profile.firstName.isEmpty && viewModel.profile.lastName.isEmpty
    }

    // MARK: - Body

    var body: some View {
        Form {
            avatarSection
            selfScanSection
            basicInfoSection
            contactSection
            socialSection
            privacySection
        }
        .navigationTitle(isOnboarding ? "Profilinizi Kurun" : "Profil")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if isOnboarding {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Atla") { onComplete?() }
                        .foregroundStyle(.secondary)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Kaydet") {
                    Task {
                        let saved = await viewModel.save(to: dependencies.userProfileStore)
                        if saved { onComplete?() }
                    }
                }
                .disabled(viewModel.isSaving)
            }
            if !isOnboarding {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showQR = true
                    } label: {
                        Image(systemName: "qrcode")
                    }
                    .disabled(isProfileEmpty)
                }
            }
        }
        .sheet(isPresented: $showQR) {
            QRCodeView(profile: viewModel.profile)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showSelfScan) {
            ProfileSetupView { parsed in
                applyParsedCard(parsed)
            }
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

    private var selfScanSection: some View {
        Section {
            Button {
                showSelfScan = true
            } label: {
                Label("Bilgilerimi Oku", systemImage: "doc.viewfinder")
            }
        } footer: {
            Text("Kendi kartvizitini tara — boş alanlar otomatik doldurulur.")
        }
    }

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
                                .foregroundStyle(.white, Color.accentColor)
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

    private var privacySection: some View {
        Section("Hakkında") {
            Button("Gizlilik Politikası") {
                showPrivacyPolicy = true
            }
        }
    }

    // MARK: - OCR apply: fills only empty fields

    private func applyParsedCard(_ card: ParsedCard) {
        if viewModel.profile.firstName.isEmpty { viewModel.profile.firstName = card.firstName }
        if viewModel.profile.lastName.isEmpty  { viewModel.profile.lastName  = card.lastName  }
        if viewModel.profile.company.isEmpty   { viewModel.profile.company   = card.company   }
        if viewModel.profile.title.isEmpty     { viewModel.profile.title     = card.title     }
        if viewModel.profile.phone.isEmpty,    let p = card.phones.first  { viewModel.profile.phone = p }
        if viewModel.profile.email.isEmpty,    let e = card.emails.first  { viewModel.profile.email = e }
        if viewModel.profile.linkedin.isEmpty  { viewModel.profile.linkedin  = card.linkedin  }
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
