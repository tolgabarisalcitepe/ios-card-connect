// VCardParser.swift
// CardConnect
// Android Cat-9: tek impl, ParseSource enum, RFC 6350 unfold her zaman.
// Android Cat-6: dosya 16 384 byte'ı aşarsa VCardError.tooLarge.

import Foundation

enum VCardParser {

    enum VCardError: Error, Equatable {
        case tooLarge
        case invalidFormat
    }

    // MARK: - Public

    static func parse(_ source: ParseSource) throws -> ParsedCard {
        let raw: String
        switch source {
        case .string(let s):
            raw = s
        case .file(let url):
            let data = try Data(contentsOf: url)
            guard data.count <= FieldLimits.maxVCard else { throw VCardError.tooLarge }
            raw = String(decoding: data, as: UTF8.self)
        }
        let unfolded = unfold(raw)
        return parseProperties(unfolded)
    }

    // MARK: - RFC 6350 Unfold

    /// Katlanmış satırları birleştirir: CRLF/LF + boşluk/tab → kaldır.
    static func unfold(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")
    }

    // MARK: - Property Parsing

    private static func parseProperties(_ text: String) -> ParsedCard {
        var result = ParsedCard()

        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            // Split at first ":" — key may include TYPE params (e.g. TEL;TYPE=WORK)
            guard let colonIdx = trimmed.firstIndex(of: ":") else { continue }
            let keyPart = String(trimmed[..<colonIdx]).uppercased()
            let value   = String(trimmed[trimmed.index(after: colonIdx)...])
                .trimmingCharacters(in: .whitespaces)

            // Base key without params
            let baseKey = keyPart.components(separatedBy: ";").first ?? keyPart

            switch baseKey {
            case "FN":
                let parts = value.components(separatedBy: " ").filter { !$0.isEmpty }
                result.firstName = String((parts.first ?? "").prefix(FieldLimits.maxName))
                result.lastName  = String(parts.dropFirst().joined(separator: " ").prefix(FieldLimits.maxName))

            case "N":
                // last;first;additional;prefix;suffix
                let parts = value.components(separatedBy: ";")
                if parts.count >= 2 {
                    result.lastName  = String(parts[0].prefix(FieldLimits.maxName))
                    result.firstName = String(parts[1].prefix(FieldLimits.maxName))
                }

            case "ORG":
                result.company = String(value.prefix(FieldLimits.maxCompany))

            case "TITLE":
                result.title = String(value.prefix(FieldLimits.maxTitle))

            case "TEL":
                if result.phones.count < 3 {
                    let phone = value.replacingOccurrences(of: "tel:", with: "", options: .caseInsensitive)
                    let cleaned = String(phone.trimmingCharacters(in: .whitespaces).prefix(FieldLimits.maxPhone))
                    if !cleaned.isEmpty { result.phones.append(cleaned) }
                }

            case "EMAIL":
                let email = String(value.lowercased().prefix(FieldLimits.maxEmail))
                if !email.isEmpty && !result.emails.contains(email) {
                    result.emails.append(email)
                }

            case "ADR":
                let parts = value.components(separatedBy: ";").filter { !$0.isEmpty }
                result.address = String(parts.joined(separator: ", ").prefix(FieldLimits.maxAddress))

            case "URL":
                if URLValidator.isValidLinkedIn(value) {
                    result.linkedin = value
                }

            case "NOTE":
                result.notes = String(value.prefix(FieldLimits.maxNotes))

            default:
                break
            }
        }

        return result
    }
}
