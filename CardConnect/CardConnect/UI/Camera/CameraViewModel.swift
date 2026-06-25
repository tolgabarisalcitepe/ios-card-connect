// CameraViewModel.swift
// CardConnect

import AVFoundation
import SwiftUI

@Observable
@MainActor
final class CameraViewModel {

    enum ScanMode { case card, qr }

    // MARK: - State

    var mode: ScanMode = .card
    var capturedImages: [UIImage] = []
    var isProcessing = false
    var cameraPermissionDenied = false

    // MARK: - AVFoundation (nonisolated — session queue üzerinden erişilir)

    nonisolated let session = AVCaptureSession()
    nonisolated let photoOutput = AVCapturePhotoOutput()
    nonisolated let photoCapture = PhotoCaptureHelper()
    private let sessionQueue = DispatchQueue(label: "com.cardconnect.camera.session", qos: .userInitiated)

    // MARK: - Lifecycle

    func startSession() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
                AVCaptureDevice.requestAccess(for: .video) { c.resume(returning: $0) }
            }
            if granted { configureAndStart() } else { cameraPermissionDenied = true }
        default:
            cameraPermissionDenied = true
        }
    }

    func stopSession() {
        sessionQueue.async { [session = session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            sessionQueue.async { [output = photoOutput, capture = photoCapture] in
                capture.prepare(continuation: continuation)
                let settings = AVCapturePhotoSettings()
                output.capturePhoto(with: settings, delegate: capture)
            }
        }
    }

    func addPhoto(_ image: UIImage) { capturedImages.append(image) }
    func clearPhotos() { capturedImages.removeAll() }

    // MARK: - Private

    private func configureAndStart() {
        sessionQueue.async { [session = session, output = photoOutput] in
            guard !session.isRunning else { return }
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard
                let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let input = try? AVCaptureDeviceInput(device: device),
                session.canAddInput(input)
            else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)
            if session.canAddOutput(output) { session.addOutput(output) }
            session.commitConfiguration()
            session.startRunning()
        }
    }
}

// MARK: - PhotoCaptureHelper

final class PhotoCaptureHelper: NSObject, AVCapturePhotoCaptureDelegate {
    nonisolated(unsafe) private var continuation: CheckedContinuation<UIImage?, Never>?

    func prepare(continuation: CheckedContinuation<UIImage?, Never>) {
        self.continuation = continuation
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        defer { continuation = nil }
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            continuation?.resume(returning: nil)
            return
        }
        continuation?.resume(returning: image)
    }
}
