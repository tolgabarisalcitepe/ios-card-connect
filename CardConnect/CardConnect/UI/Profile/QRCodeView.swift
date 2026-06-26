// QRCodeView.swift
// CardConnect
// Profil vCard'ından QR üretir ve paylaşma sheet'i sunar.

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {

    let profile: UserProfile

    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false

    private var vCardString: String { VCardExporter.build(from: profile) }
    private var qrImage: UIImage? { Self.generateQR(from: vCardString) }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                if let qrImage {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 240, height: 240)
                        .padding(16)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 8, y: 4)
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(width: 240, height: 240)
                        .overlay {
                            Image(systemName: "qrcode")
                                .font(.system(size: 64))
                                .foregroundStyle(.secondary)
                        }
                }

                VStack(spacing: 4) {
                    Text(profile.fullName)
                        .font(.title3.bold())
                    if !profile.company.isEmpty {
                        Text(profile.company)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    showShare = true
                } label: {
                    Label("Paylaş", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
            .navigationTitle("QR Kodu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                if let qrImage {
                    ShareSheet(items: [qrImage, vCardString])
                }
            }
        }
    }

    // MARK: - QR generation

    private static func generateQR(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let ciImage = filter.outputImage else { return nil }
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Share sheet wrapper

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uvc: UIActivityViewController, context: Context) {}
}
