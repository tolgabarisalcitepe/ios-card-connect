// ProfileView.swift
// CardConnect

import SwiftUI
import PhotosUI

struct ProfileView: View {

    var isOnboarding: Bool = false
    var onComplete: (() -> Void)? = nil

    @Environment(\.dependencies) private var dependencies
    @StateObject private var viewModel = ProfileViewModel()

    // Avatar
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var showAvatarOptions = false
    @State private var showAvatarCamera = false
    @State private var showAvatarGallery = false

    // Business card
    @State private var frontCardImage: Image?
    @State private var backCardImage: Image?
    @State private var showFrontOptions = false
    @State private var showBackOptions = false
    @State private var showFrontCamera = false
    @State private var showBackCamera = false
    @State private var showFrontGallery = false
    @State private var showBackGallery = false
    @State private var frontGalleryItem: PhotosPickerItem?
    @State private var backGalleryItem: PhotosPickerItem?

    // Other sheets
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
            cardSection
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
                    Button { showQR = true } label: {
                        Image(systemName: "qrcode")
                    }
                    .disabled(isProfileEmpty)
                }
            }
        }
        // Avatar options
        .confirmationDialog("Profil Fotoğrafı", isPresented: $showAvatarOptions) {
            Button("Fotoğraf Çek") { showAvatarCamera = true }
            Button("Galeriden Seç") { avatarItem = nil; showAvatarGallery = true }
            if !viewModel.profile.avatarPath.isEmpty {
                Button("Kaldır", role: .destructive) { removeAvatar() }
            }
            Button("İptal", role: .cancel) {}
        }
        .photosPicker(isPresented: $showAvatarGallery, selection: $avatarItem, matching: .images)
        .sheet(isPresented: $showAvatarCamera) {
            ProfileCameraPickerView(mode: .avatar) { applyAvatar($0) }
        }
        // Front card options
        .confirmationDialog("Ön Yüz", isPresented: $showFrontOptions) {
            Button("Fotoğraf Çek") { showFrontCamera = true }
            Button("Galeriden Seç") { frontGalleryItem = nil; showFrontGallery = true }
            if !viewModel.profile.frontCardPath.isEmpty {
                Button("Kaldır", role: .destructive) { removeFrontCard() }
            }
            Button("İptal", role: .cancel) {}
        }
        .photosPicker(isPresented: $showFrontGallery, selection: $frontGalleryItem, matching: .images)
        .sheet(isPresented: $showFrontCamera) {
            ProfileCameraPickerView(mode: .card) { applyFrontCard($0) }
        }
        // Back card options
        .confirmationDialog("Arka Yüz", isPresented: $showBackOptions) {
            Button("Fotoğraf Çek") { showBackCamera = true }
            Button("Galeriden Seç") { backGalleryItem = nil; showBackGallery = true }
            if !viewModel.profile.backCardPath.isEmpty {
                Button("Kaldır", role: .destructive) { removeBackCard() }
            }
            Button("İptal", role: .cancel) {}
        }
        .photosPicker(isPresented: $showBackGallery, selection: $backGalleryItem, matching: .images)
        .sheet(isPresented: $showBackCamera) {
            ProfileCameraPickerView(mode: .card) { applyBackCard($0) }
        }
        // Other sheets
        .sheet(isPresented: $showQR) {
            QRCodeView(profile: viewModel.profile)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showSelfScan) {
            ProfileSetupView { parsed in applyParsedCard(parsed) }
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
            loadImagesFromDisk()
        }
        .onChange(of: avatarItem) { _, item in Task { await loadAvatarFromPicker(item) } }
        .onChange(of: frontGalleryItem) { _, item in Task { await loadCardFromPicker(item, side: .front) } }
        .onChange(of: backGalleryItem)  { _, item in Task { await loadCardFromPicker(item, side: .back) } }
    }

    // MARK: - Sections

    private var avatarSection: some View {
        Section {
            HStack {
                Spacer()
                Button { showAvatarOptions = true } label: {
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

    private var cardSection: some View {
        Section("Kartvizitim") {
            cardRow(
                label: "Ön Yüz",
                image: frontCardImage,
                hasPath: !viewModel.profile.frontCardPath.isEmpty,
                onTap: { showFrontOptions = true }
            )
            cardRow(
                label: "Arka Yüz",
                image: backCardImage,
                hasPath: !viewModel.profile.backCardPath.isEmpty,
                onTap: { showBackOptions = true }
            )
        } footer: {
            Text("Kartvizitinizin ön ve arka yüzünü ekleyin.")
        }
    }

    @ViewBuilder
    private func cardRow(label: String, image: Image?, hasPath: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 45)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 72, height: 45)
                        .overlay {
                            Image(systemName: "plus")
                                .foregroundStyle(.secondary)
                        }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .foregroundStyle(.primary)
                    Text(hasPath ? "Değiştir veya Kaldır" : "Ekle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private var privacySection: some View {
        Section("Hakkında") {
            Button("Gizlilik Politikası") { showPrivacyPolicy = true }
        }
    }

    // MARK: - OCR apply

    private func applyParsedCard(_ card: ParsedCard) {
        if viewModel.profile.firstName.isEmpty { viewModel.profile.firstName = card.firstName }
        if viewModel.profile.lastName.isEmpty  { viewModel.profile.lastName  = card.lastName  }
        if viewModel.profile.company.isEmpty   { viewModel.profile.company   = card.company   }
        if viewModel.profile.title.isEmpty     { viewModel.profile.title     = card.title     }
        if viewModel.profile.phone.isEmpty,    let p = card.phones.first { viewModel.profile.phone = p }
        if viewModel.profile.email.isEmpty,    let e = card.emails.first { viewModel.profile.email = e }
        if viewModel.profile.linkedin.isEmpty  { viewModel.profile.linkedin  = card.linkedin  }
    }

    // MARK: - Avatar helpers

    private func applyAvatar(_ uiImage: UIImage) {
        avatarImage = Image(uiImage: uiImage)
        if let data = uiImage.jpegData(compressionQuality: 0.85),
           let path = saveToDisk(data: data, filename: "profile_avatar.jpg") {
            viewModel.profile.avatarPath = path
        }
    }

    private func removeAvatar() {
        PhotoStorage.deletePhotos(paths: [viewModel.profile.avatarPath])
        viewModel.profile.avatarPath = ""
        avatarImage = nil
    }

    private func loadAvatarFromPicker(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        applyAvatar(uiImage)
    }

    // MARK: - Card helpers

    private enum CardSide { case front, back }

    private func applyFrontCard(_ uiImage: UIImage) {
        frontCardImage = Image(uiImage: uiImage)
        if let data = uiImage.jpegData(compressionQuality: 0.85),
           let path = saveToDisk(data: data, filename: "profile_front_card.jpg") {
            viewModel.profile.frontCardPath = path
        }
    }

    private func applyBackCard(_ uiImage: UIImage) {
        backCardImage = Image(uiImage: uiImage)
        if let data = uiImage.jpegData(compressionQuality: 0.85),
           let path = saveToDisk(data: data, filename: "profile_back_card.jpg") {
            viewModel.profile.backCardPath = path
        }
    }

    private func removeFrontCard() {
        PhotoStorage.deletePhotos(paths: [viewModel.profile.frontCardPath])
        viewModel.profile.frontCardPath = ""
        frontCardImage = nil
    }

    private func removeBackCard() {
        PhotoStorage.deletePhotos(paths: [viewModel.profile.backCardPath])
        viewModel.profile.backCardPath = ""
        backCardImage = nil
    }

    private func loadCardFromPicker(_ item: PhotosPickerItem?, side: CardSide) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        switch side {
        case .front: applyFrontCard(uiImage)
        case .back:  applyBackCard(uiImage)
        }
    }

    // MARK: - Disk helpers

    private func loadImagesFromDisk() {
        avatarImage    = loadImage(at: viewModel.profile.avatarPath)
        frontCardImage = loadImage(at: viewModel.profile.frontCardPath)
        backCardImage  = loadImage(at: viewModel.profile.backCardPath)
    }

    private func loadImage(at path: String) -> Image? {
        guard !path.isEmpty,
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
    }

    private func saveToDisk(data: Data, filename: String) -> String? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        try? data.write(to: url, options: .atomic)
        return url.path
    }
}
