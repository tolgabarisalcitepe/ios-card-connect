// CardCaptureView.swift
// CardConnect
// 1.6:1 kart çerçeve overlay — AVCaptureSession önizlemesi üzerinde rehber dikdörtgeni.

import SwiftUI
import AVFoundation

struct CardCaptureView: View {
    let session: AVCaptureSession

    var body: some View {
        GeometryReader { geo in
            ZStack {
                CameraPreviewLayerView(session: session)
                    .ignoresSafeArea()
                CardFrameOverlay(containerSize: geo.size)
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card Frame Overlay

private struct CardFrameOverlay: View {
    let containerSize: CGSize

    private var frameWidth: CGFloat { min(containerSize.width * 0.85, 320) }
    private var frameHeight: CGFloat { frameWidth / 1.586 } // ISO 7810 ID-1: 85.6 × 53.98 mm

    var body: some View {
        ZStack {
            // Karartma + kesik
            Color.black.opacity(0.55)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .frame(width: frameWidth, height: frameHeight)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()

            // Çerçeve kenarlığı
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
                .frame(width: frameWidth, height: frameHeight)

            // Köşe braketleri
            CornerBrackets(frameWidth: frameWidth, frameHeight: frameHeight)

            // Rehber metni
            VStack {
                Spacer()
                    .frame(height: frameHeight / 2 + 16)
                Text("Kartviziti çerçeve içine yerleştirin")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - Corner Brackets

private struct CornerBrackets: View {
    let frameWidth: CGFloat
    let frameHeight: CGFloat
    private let len: CGFloat = 18
    private let lw: CGFloat = 3

    var body: some View {
        ZStack {
            cornerPath(xSign: -1, ySign: -1)
            cornerPath(xSign:  1, ySign: -1)
            cornerPath(xSign: -1, ySign:  1)
            cornerPath(xSign:  1, ySign:  1)
        }
    }

    private func cornerPath(xSign: CGFloat, ySign: CGFloat) -> some View {
        BracketShape(length: len)
            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lw, lineCap: .round))
            .frame(width: len, height: len)
            .scaleEffect(x: xSign, y: ySign)
            .offset(
                x: xSign * (frameWidth / 2 - len / 2),
                y: ySign * (frameHeight / 2 - len / 2)
            )
    }
}

private struct BracketShape: Shape {
    let length: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        return p
    }
}

// MARK: - AVCaptureSession Preview (internal, shared)

struct CameraPreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}
