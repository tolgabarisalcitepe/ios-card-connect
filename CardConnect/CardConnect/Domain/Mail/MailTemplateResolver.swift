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

    // MARK: - Event-aware resolve

    /// eventName boşsa [Etkinlik] içeren satırları siler, ardından token'ları çözer.
    func resolveBody(_ body: String) -> String {
        let cleaned = hasEvent ? body : removeEventLines(from: body)
        return resolve(cleaned)
    }

    /// eventName boşsa subject'teki [Etkinlik] bölümlerini temizler, ardından token'ları çözer.
    func resolveSubject(_ subject: String) -> String {
        let cleaned = hasEvent ? subject : removeEventFromSubject(subject)
        return resolve(cleaned)
    }

    // MARK: - Private

    private var hasEvent: Bool {
        !(contact.eventName ?? "").isEmpty
    }

    private func removeEventLines(from body: String) -> String {
        let lines = body.components(separatedBy: "\n")
        let filtered = lines.filter { !$0.contains("[Etkinlik]") }
        // Ardışık boş satırları tek satıra indir
        var result: [String] = []
        var prevWasEmpty = false
        for line in filtered {
            let isEmpty = line.trimmingCharacters(in: .whitespaces).isEmpty
            if isEmpty && prevWasEmpty { continue }
            result.append(line)
            prevWasEmpty = isEmpty
        }
        return result.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }

    private func removeEventFromSubject(_ subject: String) -> String {
        subject
            .replacingOccurrences(of: "[Etkinlik] - ", with: "")
            .replacingOccurrences(of: " - [Etkinlik]", with: "")
            .replacingOccurrences(of: "[Etkinlik]", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}
