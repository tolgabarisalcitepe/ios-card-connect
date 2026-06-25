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
}
