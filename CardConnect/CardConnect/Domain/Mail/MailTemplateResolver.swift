// MailTemplateResolver.swift
// CardConnect

import Foundation

struct MailTemplateResolver {

    let contact: Contact
    let profile: UserProfile

    // MARK: - Token map

    private var tokenMap: [(token: String, value: String)] {
        [
            ("[Ad]",         contact.firstName),
            ("[Tam Ad]",     contact.fullName),
            ("[Etkinlik]",   contact.eventName ?? ""),
            ("[Benim Adım]", profile.fullName),
            ("[Ünvanım]",    profile.title),
            ("[Şirketim]",   profile.company),
        ]
    }

    // MARK: - API

    /// Tüm [Token]'ları contact + profile değerleriyle değiştirir.
    func resolve(_ template: String) -> String {
        tokenMap.reduce(template) { result, pair in
            result.replacingOccurrences(of: pair.token, with: pair.value)
        }
    }

    /// Şablonda geçen ancak değeri boş olan token'ları döner (uyarı listesi).
    func findMissingVars(in template: String) -> [String] {
        tokenMap.compactMap { pair in
            template.contains(pair.token) && pair.value.isEmpty ? pair.token : nil
        }
    }
}
