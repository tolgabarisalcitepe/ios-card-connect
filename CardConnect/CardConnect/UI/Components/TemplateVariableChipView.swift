// TemplateVariableChipView.swift
// CardConnect

import SwiftUI

/// Şablon metnindeki [Token]'ları accent rengiyle vurgular.
struct TemplateVariableChipView: View {

    let text: String
    var lineLimit: Int = 3

    var body: some View {
        Text(attributedPreview)
            .lineLimit(lineLimit)
            .font(.caption)
    }

    // MARK: - Private

    private static let tokens: [String] = [
        "[Ad]", "[Tam Ad]", "[Etkinlik]",
        "[Benim Adım]", "[Ünvanım]", "[Şirketim]",
    ]

    private var attributedPreview: AttributedString {
        var result = AttributedString()
        var remaining = text

        while !remaining.isEmpty {
            // En erken geçen token'ı bul
            var earliest: (range: Range<String.Index>, token: String)?
            for token in Self.tokens {
                if let r = remaining.range(of: token) {
                    if earliest == nil || r.lowerBound < earliest!.range.lowerBound {
                        earliest = (r, token)
                    }
                }
            }

            if let found = earliest {
                // Token öncesi normal metin
                let before = String(remaining[remaining.startIndex ..< found.range.lowerBound])
                if !before.isEmpty {
                    var plain = AttributedString(before)
                    plain.foregroundColor = Color(.label).opacity(0.55)
                    result += plain
                }
                // Token — accent rengi + hafif arka plan
                var chip = AttributedString(found.token)
                chip.foregroundColor = Color.accentColor
                chip.backgroundColor = Color.accentColor.opacity(0.12)
                result += chip
                remaining = String(remaining[found.range.upperBound...])
            } else {
                var plain = AttributedString(remaining)
                plain.foregroundColor = Color(.label).opacity(0.55)
                result += plain
                remaining = ""
            }
        }

        return result
    }
}
