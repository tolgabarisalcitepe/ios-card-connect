// ProfileCameraPickerView.swift
// CardConnect
// Tek fotoğraf yakalama sheet'i — CameraViewModel + CardCaptureView yeniden kullanılır.

import AVFoundation
import SwiftUI

struct ProfileCameraPickerView: View {

    enum CaptureMode { case card, avatar }

    let mode: CaptureMode
    let onCapture: (UIImage) -> Void

    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = CameraViewModel()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                cameraLayer
                if !viewModel.cameraPermissionDenied {
                    captureButton
                        .padding(.bottom, 48)
                }
            }
            .ignoresSafeArea()
            .navigationTitle(mode == .card ? "Kartvizit Çek" : "Fotoğraf Çek")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
        .task { await viewModel.startSession() }
        .onDisappear { viewModel.stopSession() }
    }

    // MARK: - Camera layer

    @ViewBuilder
    private var cameraLayer: some View {
        if viewModel.cameraPermissionDenied {
            permissionDeniedView
        } else if mode == .card {
            CardCaptureView(session: viewModel.session)
        } else {
            CameraPreviewLayerView(session: viewModel.session)
                .ignoresSafeArea()
        }
    }

    // MARK: - Capture button

    private var captureButton: some View {
        Button {
            Task { await capture() }
        } label: {
            ZStack {
                Circle().fill(.white).frame(width: 70, height: 70)
                Circle()
                    .strokeBorder(.white.opacity(0.4), lineWidth: 4)
                    .frame(width: 80, height: 80)
            }
        }
        .disabled(viewModel.isProcessing)
        .overlay {
            if viewModel.isProcessing {
                ProgressView()
                    .tint(.white)
                    .padding(20)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
    }

    // MARK: - Permission denied

    private var permissionDeniedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Kamera Erişimi Gerekli")
                .font(.title2.bold())
            Text("Fotoğraf çekebilmek için kamera iznini açın.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)
            Button("Ayarları Aç") {
                dependencies.permissionCoordinator.openSettings()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Capture action

    private func capture() async {
        viewModel.isProcessing = true
        defer { viewModel.isProcessing = false }
        guard let image = await viewModel.capturePhoto() else { return }
        dismiss()
        onCapture(image)
    }
}
