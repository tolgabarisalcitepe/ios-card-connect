// ProfileSetupView.swift
// CardConnect
// OCR self-scan: kendi kartından profil alanlarını doldur.

import SwiftUI
import PhotosUI

struct ProfileSetupView: View {

    /// Tarama tamamlandığında boş alanları doldurmak için kullanılır.
    let onApply: (ParsedCard) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scanState: ScanState = .idle
    @State private var selectedItem: PhotosPickerItem?

    // MARK: - State

    enum ScanState {
        case idle
        case loading
        case done(ParsedCard)
        case error(String)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                switch scanState {
                case .idle:    idleView
                case .loading: loadingView
                case .done(let card): doneView(card: card)
                case .error(let msg): errorView(message: msg)
                }
            }
            .navigationTitle("Bilgilerimi Oku")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
        .onChange(of: selectedItem) { _, item in
            Task { await processImage(item) }
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Kartvizitini Tara")
                    .font(.title2.bold())
                Text("Kendi kartvizitinin fotoğrafını seç; boş profil alanları otomatik doldurulur.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Galeriden Seç", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            Text("Metin okunuyor…")
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Done

    private func doneView(card: ParsedCard) -> some View {
        List {
            if !card.firstName.isEmpty || !card.lastName.isEmpty {
                LabeledContent("İsim", value: "\(card.firstName) \(card.lastName)"
                    .trimmingCharacters(in: .whitespaces))
            }
            if !card.company.isEmpty {
                LabeledContent("Şirket", value: card.company)
            }
            if !card.title.isEmpty {
                LabeledContent("Ünvan", value: card.title)
            }
            if let phone = card.phones.first, !phone.isEmpty {
                LabeledContent("Telefon", value: phone)
            }
            if let email = card.emails.first, !email.isEmpty {
                LabeledContent("E-posta", value: email)
            }
            if !card.linkedin.isEmpty {
                LabeledContent("LinkedIn", value: card.linkedin)
            }

            Section {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Tekrar Tara", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                onApply(card)
                dismiss()
            } label: {
                Text("Profili Doldur")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .background(.regularMaterial)
        }
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("Tekrar Dene", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    // MARK: - OCR processing

    private func processImage(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        scanState = .loading

        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            scanState = .error("Görüntü yüklenemedi.")
            return
        }

        do {
            let rawText = try await VisionOCRService().recognizeText(from: [cgImage])
            let card = CardParser.parse(rawText)
            scanState = .done(card)
        } catch {
            scanState = .error("Metin tanıma başarısız. Lütfen daha net bir fotoğraf deneyin.")
        }
    }
}
