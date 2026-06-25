// VisionOCRService.swift
// CardConnect

import Vision
import CoreGraphics

struct VisionOCRService {

    enum OCRError: Error {
        case requestFailed(Error)
    }

    // MARK: - Public API

    /// Bir veya iki görüntüden metin çıkarır.
    /// İki görüntü varsa aralarına "---" eklenir; toplam çıktı FieldLimits.maxOCRInput ile sınırlandırılır.
    func recognizeText(from images: [CGImage]) async throws -> String {
        var parts: [String] = []
        for image in images {
            let text = try await recognize(image: image)
            if !text.isEmpty {
                parts.append(text)
            }
        }
        let merged = parts.joined(separator: "\n---\n")
        return String(merged.prefix(FieldLimits.maxOCRInput))
    }

    // MARK: - Private

    private func recognize(image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: OCRError.requestFailed(error))
                        return
                    }
                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let text = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                    continuation.resume(returning: text)
                }
                request.recognitionLevel = .accurate
                request.recognitionLanguages = ["tr-TR", "en-US"]
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: OCRError.requestFailed(error))
                }
            }
        }
    }
}
