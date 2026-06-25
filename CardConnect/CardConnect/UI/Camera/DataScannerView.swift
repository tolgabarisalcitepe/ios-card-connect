// DataScannerView.swift
// CardConnect
// VisionKit DataScannerViewController wrapper — sadece QR (vCard kontrolü caller'da).

import SwiftUI
import Vision
import VisionKit

struct DataScannerView: UIViewControllerRepresentable {
    let onVCardDetected: (String) -> Void
    let onNonVCardDetected: () -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onVCardDetected: onVCardDetected, onNonVCardDetected: onNonVCardDetected)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onVCardDetected: (String) -> Void
        private let onNonVCardDetected: () -> Void
        private var handled = false

        init(
            onVCardDetected: @escaping (String) -> Void,
            onNonVCardDetected: @escaping () -> Void
        ) {
            self.onVCardDetected = onVCardDetected
            self.onNonVCardDetected = onNonVCardDetected
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !handled else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue else { continue }
                handled = true
                dataScanner.stopScanning()
                if payload.uppercased().hasPrefix("BEGIN:VCARD") {
                    onVCardDetected(payload)
                } else {
                    onNonVCardDetected()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.handled = false
                        try? dataScanner.startScanning()
                    }
                }
                return
            }
        }
    }
}
