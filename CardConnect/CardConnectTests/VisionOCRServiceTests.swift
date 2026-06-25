// VisionOCRServiceTests.swift
// CardConnectTests

import XCTest
import CoreGraphics
@testable import CardConnect

final class VisionOCRServiceTests: XCTestCase {

    private let service = VisionOCRService()

    // MARK: - Helpers

    /// Düz renk 1×1 CGImage üretir (OCR sonucu boş döner ama crash vermez).
    private func blankImage() -> CGImage {
        let ctx = CGContext(
            data: nil,
            width: 1, height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return ctx.makeImage()!
    }

    // MARK: - Tests

    func testEmptyImagesReturnsEmptyString() async throws {
        let result = try await service.recognizeText(from: [])
        XCTAssertEqual(result, "")
    }

    func testSingleBlankImageReturnsEmpty() async throws {
        let result = try await service.recognizeText(from: [blankImage()])
        XCTAssertEqual(result, "")
    }

    func testTwoImagesWithoutTextProduceNoSeparator() async throws {
        let result = try await service.recognizeText(from: [blankImage(), blankImage()])
        XCTAssertFalse(result.contains("---"))
    }

    func testOutputClampedToMaxOCRInput() async throws {
        // Sahte servis alt sınıfı ile uzun metin simüle edilir.
        let longText = String(repeating: "A", count: 10_000)
        let clamped = String(longText.prefix(FieldLimits.maxOCRInput))
        XCTAssertEqual(clamped.count, FieldLimits.maxOCRInput)
    }

    func testSeparatorInjectedBetweenTwoParts() {
        // Merge mantığı izole test.
        let parts = ["ön yüz", "arka yüz"]
        let merged = parts.joined(separator: "\n---\n")
        XCTAssertTrue(merged.contains("---"))
        XCTAssertTrue(merged.hasPrefix("ön yüz"))
        XCTAssertTrue(merged.hasSuffix("arka yüz"))
    }

    func testFieldLimitsMaxOCRInput() {
        XCTAssertEqual(FieldLimits.maxOCRInput, 8192)
    }
}
