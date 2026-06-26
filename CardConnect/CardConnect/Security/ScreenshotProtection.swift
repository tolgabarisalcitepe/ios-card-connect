// ScreenshotProtection.swift
// CardConnect
// FLAG_SECURE'un iOS karşılığı: inactive/background'da siyah overlay.

import SwiftUI

struct ScreenshotProtectionModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.overlay {
            if scenePhase != .active {
                Color.black.ignoresSafeArea()
            }
        }
    }
}

extension View {
    func screenshotProtected() -> some View {
        modifier(ScreenshotProtectionModifier())
    }
}
