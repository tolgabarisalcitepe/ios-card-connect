// URLValidator.swift
// CardConnect
// Android Cat-4: parse anında domain whitelist uygulanır, display anında değil.

import Foundation

enum URLValidator {

    private static let linkedInHosts: Set<String> = ["linkedin.com", "www.linkedin.com"]

    /// https + linkedin.com/www.linkedin.com zorunlu.
    /// http, intent://, evil.com/linkedin gibi URL'ler false döner.
    static func isValidLinkedIn(_ raw: String) -> Bool {
        guard
            let url = URL(string: raw),
            url.scheme == "https",
            let host = url.host?.lowercased(),
            linkedInHosts.contains(host)
        else { return false }
        return true
    }

    /// LinkedIn URL'ini normalize eder → https://linkedin.com/in/<username>
    /// Kabul edilen formatlar:
    ///   - https://linkedin.com/in/username
    ///   - linkedin.com/in/username  (scheme'siz)
    ///   - in/username
    ///   - linkedin: username  (etiketli)
    /// Geçersiz giriş → nil
    static func normalizeLinkedIn(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)

        // 1. URL tabanlı çözümleme (scheme ekleyerek de dene)
        for candidate in [trimmed, "https://" + trimmed] {
            guard let url = URL(string: candidate),
                  let host = url.host?.lowercased(),
                  linkedInHosts.contains(host) else { continue }
            let parts = url.path.split(separator: "/").map(String.init)
            if parts.count >= 2, parts[0].lowercased() == "in", !parts[1].isEmpty {
                return "https://linkedin.com/in/\(parts[1])"
            } else if parts.count == 1, !parts[0].isEmpty {
                return "https://linkedin.com/in/\(parts[0])"
            }
        }

        // 2. "in/username" deseni
        let inPattern = "(?i)(?:^|/)in/([A-Za-z0-9\\-_]{3,100})"
        if let regex = try? NSRegularExpression(pattern: inPattern) {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if let m = regex.firstMatch(in: trimmed, range: range),
               let r = Range(m.range(at: 1), in: trimmed) {
                return "https://linkedin.com/in/\(trimmed[r])"
            }
        }

        return nil
    }
}
