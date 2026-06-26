import SwiftUI

/// Kişi adının baş harflerini deterministik renkte 44pt daire içinde gösterir.
struct InitialsAvatarView: View {
    let fullName: String
    var size: CGFloat = 44

    private static let palette: [Color] = [
        .blue, .indigo, .purple, .pink,
        .orange, .green, .teal, .cyan
    ]

    private var initials: String {
        let parts = fullName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }

    private var color: Color {
        guard !fullName.isEmpty else { return .gray }
        let idx = abs(fullName.hashValue) % Self.palette.count
        return Self.palette[idx]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size, height: size)
            Text(initials.isEmpty ? "?" : initials)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(color)
        }
        .accessibilityHidden(true)
    }
}
