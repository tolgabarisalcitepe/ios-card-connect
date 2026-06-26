// CameraView.swift
// CardConnect
// Kartvizit fotoğrafı (AVFoundation) + QR (DataScanner) + galeri (PhotosPicker).

import SwiftUI
import AVFoundation
import PhotosUI
import VisionKit

struct CameraView: View {
    @Binding var path: NavigationPath
    @Environment(\.dependencies) private var dependencies

    @State private var viewModel = CameraViewModel()
    @State private var galleryItem: PhotosPickerItem?
    @State private var showNonVCardAlert = false

    var body: some View {
        ZStack(alignment: .bottom) {
            background
            overlay
        }
        .ignoresSafeArea()
        .navigationTitle("Tara")
        .navigationBarTitleDisplayMode(.inline)
        .alert("QR Kod Geçersiz", isPresented: $showNonVCardAlert) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text("Bu QR kod bir kartvizit (vCard) bilgisi içermiyor.")
        }
        .task { await viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
        .onChange(of: galleryItem) { _, item in
            Task { await handleGallery(item) }
        }
    }

    // MARK: - Background layer

    @ViewBuilder
    private var background: some View {
        if viewModel.cameraPermissionDenied {
            permissionDeniedView
        } else if viewModel.mode == .card {
            CardCaptureView(session: viewModel.session)
        } else {
            DataScannerView(
                onVCardDetected: { payload in Task { await handleVCard(payload) } },
                onNonVCardDetected: { showNonVCardAlert = true }
            )
        }
    }

    // MARK: - Overlay controls

    @ViewBuilder
    private var overlay: some View {
        if !viewModel.cameraPermissionDenied {
            VStack(spacing: 0) {
                if !viewModel.capturedImages.isEmpty {
                    photoBadge
                        .padding(.bottom, 8)
                }
                modePicker
                if viewModel.mode == .card {
                    cardControls
                }
            }
            .padding(.bottom, 32)
        }
    }

    private var photoBadge: some View {
        Label("\(viewModel.capturedImages.count)/2 fotoğraf çekildi", systemImage: "checkmark.circle.fill")
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.green, in: Capsule())
            .foregroundStyle(.white)
    }

    private var modePicker: some View {
        Picker("Mod", selection: $viewModel.mode) {
            Text("Kartvizit").tag(CameraViewModel.ScanMode.card)
            Text("QR Kod").tag(CameraViewModel.ScanMode.qr)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
    }

    private var cardControls: some View {
        VStack(spacing: 12) {
            if viewModel.capturedImages.count == 1 {
                Button {
                    Task { await processAndNavigate() }
                } label: {
                    Text("Devam Et (arka yüz olmadan)")
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .foregroundStyle(.white)
            }

            HStack(spacing: 48) {
                PhotosPicker(selection: $galleryItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }

                captureButton

                if viewModel.capturedImages.isEmpty {
                    Color.clear.frame(width: 44, height: 44)
                } else {
                    Button { viewModel.clearPhotos() } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }
            .foregroundStyle(.white)
            .overlay {
                if viewModel.isProcessing {
                    ProgressView("OCR işleniyor…")
                        .tint(.white)
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.top, 12)
    }

    private var captureButton: some View {
        Button {
            Task { await capturePhoto() }
        } label: {
            ZStack {
                Circle().fill(.white).frame(width: 70, height: 70)
                Circle()
                    .strokeBorder(.white.opacity(0.4), lineWidth: 4)
                    .frame(width: 80, height: 80)
            }
        }
        .disabled(viewModel.isProcessing || viewModel.capturedImages.count >= 2)
        .opacity(viewModel.capturedImages.count >= 2 ? 0.4 : 1)
    }

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Kamera Erişimi Gerekli")
                .font(.title2.bold())
            Text("Kartvizit taramak için kamera iznini açın.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Ayarları Aç") {
                dependencies.permissionCoordinator.openSettings()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("camera_settings_button")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .accessibilityIdentifier("camera_permission_denied_view")
    }

    // MARK: - Actions

    private func capturePhoto() async {
        guard !viewModel.isProcessing, viewModel.capturedImages.count < 2 else { return }
        if let image = await viewModel.capturePhoto() {
            viewModel.addPhoto(image)
            if viewModel.capturedImages.count >= 2 {
                await processAndNavigate()
            }
        }
    }

    private func processAndNavigate() async {
        guard !viewModel.isProcessing else { return }
        viewModel.isProcessing = true
        defer { viewModel.isProcessing = false }

        let cgImages = viewModel.capturedImages.compactMap { $0.cgImage }
        let rawText = (try? await VisionOCRService().recognizeText(from: cgImages)) ?? ""
        let card = CardParser.parse(rawText)

        let savedPaths = saveToDisk(viewModel.capturedImages)
        await dependencies.scanFlow.setPhotoPaths(savedPaths)
        await dependencies.scanFlow.setParsedCard(card)

        path.append(AppRoute.confirm)
    }

    private func handleVCard(_ payload: String) async {
        guard let card = try? VCardParser.parse(.string(payload)) else { return }
        await dependencies.scanFlow.setParsedCard(card)
        path.append(AppRoute.confirm)
    }

    private func handleGallery(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        viewModel.addPhoto(image)
        await processAndNavigate()
    }

    private func saveToDisk(_ images: [UIImage]) -> [URL] {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("photos")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return images.compactMap { image in
            let url = dir.appendingPathComponent("\(UUID().uuidString).jpg")
            guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
            try? data.write(to: url)
            return url
        }
    }
}

// MARK: - Camera Preview (AVCaptureVideoPreviewLayer)

private struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView { PreviewUIView(session: session) }
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        private var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        init(session: AVCaptureSession) {
            super.init(frame: .zero)
            previewLayer.session = session
            previewLayer.videoGravity = .resizeAspectFill
        }

        required init?(coder: NSCoder) { fatalError() }
    }
}
