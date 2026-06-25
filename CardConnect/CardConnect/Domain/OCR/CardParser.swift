// CardParser.swift
// CardConnect
// Android Bug #106–#115: faks hariç, dahili hariç, all-caps normalize, max 3 tel, 8192 clamp.

import Foundation

enum CardParser {

    // MARK: - Patterns

    private static let emailRegex = try! NSRegularExpression(
        pattern: "[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}"
    )
    private static let phoneRegex = try! NSRegularExpression(
        pattern: "(?:(?:\\+|00)\\d{1,3}[\\s.\\-]?)?(?:[\\(]?\\d[\\s.\\-]?){6,14}\\d"
    )
    private static let linkedinRegex = try! NSRegularExpression(
        pattern: "(?i)(?:https?://)?(?:www\\.)?linkedin\\.com|\\blinkedin\\b"
    )
    private static let faxRegex = try! NSRegularExpression(
        pattern: "(?i)(faks?|fax|\u{1F4E0}|f\\.?)[:\\s]"
    )
    private static let extRegex = try! NSRegularExpression(
        pattern: "(?i)(ext\\.?|dahili|pbx)\\s*\\d+"
    )

    private static let companySuffixes = [
        "a.ş.", "a.s.", "anonim şirketi", "ltd.", "ltd.şti.", "ltdşti",
        "şti.", "şirketi", "inc.", "corp.", "llc", "gmbh",
        "limited", "san.", "tic.", "san.tic.", "holding", "group", "grup",
        "teknoloji", "danışmanlık", "mühendislik", "yazılım", "bilişim"
    ]

    private static let titleKeywords: [String] = [
        // C-suite / direktör
        "ceo", "cfo", "cto", "coo", "cmo", "genel müdür", "genel koordinatör",
        "direktör", "director", "başkan", "president", "vice president", "vp",
        // Müdür
        "müdür", "müdür yardımcısı", "manager", "yönetici",
        // Mühendis / uzman
        "mühendis", "engineer", "yazılım mühendisi", "senior", "lead", "kıdemli",
        "uzman", "specialist", "danışman", "consultant", "analist", "analyst",
        // Koordinatör / sorumlu
        "koordinatör", "coordinator", "sorumlu", "supervisor",
        // Diğer sık geçenler
        "temsilci", "representative", "asistan", "assistant", "stajyer", "intern",
        "avukat", "lawyer", "doktor", "doctor", "dr.", "prof.", "öğretim görevlisi"
    ]

    // MARK: - Public

    static func parse(_ rawText: String) -> ParsedCard {
        let text = String(rawText.prefix(FieldLimits.maxOCRInput))
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "---" }

        var result = ParsedCard()
        var textLines: [String] = []
        var phones: [String] = []
        var emails: [String] = []

        for line in lines {
            if let email = firstMatch(emailRegex, in: line) {
                emails.append(String(email.lowercased().prefix(FieldLimits.maxEmail)))
                continue
            }
            if result.linkedin.isEmpty {
                let ns = line as NSString
                let fullRange = NSRange(location: 0, length: ns.length)
                if linkedinRegex.firstMatch(in: line, range: fullRange) != nil,
                   let normalized = URLValidator.normalizeLinkedIn(line.trimmingCharacters(in: .whitespaces)) {
                    result.linkedin = String(normalized.prefix(FieldLimits.maxURL))
                    continue
                }
            }
            if hasMatch(faxRegex, in: line) || hasMatch(extRegex, in: line) {
                continue
            }
            if let phone = firstMatch(phoneRegex, in: line) {
                phones.append(String(phone.trimmingCharacters(in: .whitespaces).prefix(FieldLimits.maxPhone)))
                continue
            }
            textLines.append(line)
        }

        result.emails = emails
        result.phones = Array(phones.prefix(3))
        parseName(from: textLines, into: &result)
        return result
    }

    // MARK: - Name / Title / Company

    private static func parseName(from lines: [String], into result: inout ParsedCard) {
        guard !lines.isEmpty else { return }
        var rest = lines

        let rawNameLine = rest.removeFirst()
        let nameLine = normalizeAllCaps(rawNameLine)
        let parts = nameLine.split(separator: " ").map(String.init)
        let rawParts = rawNameLine.split(separator: " ").map(String.init)

        if parts.count >= 2 {
            if isReversedFormat(rawParts) {
                // Ters format: SOYAD Ad → firstName = Ad, lastName = SOYAD
                result.firstName = String(parts.dropFirst().joined(separator: " ").prefix(FieldLimits.maxName))
                result.lastName  = String(parts[0].prefix(FieldLimits.maxName))
            } else {
                result.firstName = String(parts[0].prefix(FieldLimits.maxName))
                result.lastName  = String(parts.dropFirst().joined(separator: " ").prefix(FieldLimits.maxName))
            }
        } else {
            result.firstName = String(nameLine.prefix(FieldLimits.maxName))
        }

        var addressParts: [String] = []
        for line in rest {
            let normalized = normalizeAllCaps(line)
            if result.company.isEmpty, isCompanyLine(normalized) {
                result.company = String(normalized.prefix(FieldLimits.maxCompany))
            } else if result.title.isEmpty, isTitleLine(normalized) {
                result.title = cleanPunctuation(String(normalized.prefix(FieldLimits.maxTitle)))
            } else if result.title.isEmpty, !isAddressLine(normalized), !looksLikeName(normalized) {
                result.title = cleanPunctuation(String(normalized.prefix(FieldLimits.maxTitle)))
            } else {
                addressParts.append(normalized)
            }
        }
        if !addressParts.isEmpty {
            result.address = String(addressParts.joined(separator: ", ").prefix(FieldLimits.maxAddress))
        }
    }

    // MARK: - Helpers

    /// Ters format tespiti: "SOYAD Ad" → true
    /// Kural: ilk token all-caps, kalan tokenlardan en az biri mixed-case ise ters formattır.
    private static func isReversedFormat(_ rawParts: [String]) -> Bool {
        guard rawParts.count >= 2 else { return false }
        let firstIsAllCaps = rawParts[0].rangeOfCharacter(from: .letters) != nil
            && rawParts[0].count > 1
            && rawParts[0] == rawParts[0].uppercased()
        let restHasMixedCase = rawParts.dropFirst().contains { part in
            part.rangeOfCharacter(from: .letters) != nil && part != part.uppercased()
        }
        return firstIsAllCaps && restHasMixedCase
    }

    private static func normalizeAllCaps(_ line: String) -> String {
        line.split(separator: " ").map { word -> String in
            let s = String(word)
            guard s.count > 1,
                  s == s.uppercased(),
                  s.rangeOfCharacter(from: .letters) != nil
            else { return s }
            return s.lowercased().capitalized
        }.joined(separator: " ")
    }

    private static func isCompanyLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return companySuffixes.contains { lower.contains($0) }
    }

    private static func isTitleLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        return titleKeywords.contains { lower.contains($0) }
    }

    /// İki veya daha az kelimeden oluşan, harf içeren ve şirket/adres olmayan satır
    /// → isim satırı olarak görünür, başlık olmamalı
    private static func looksLikeName(_ line: String) -> Bool {
        let words = line.split(separator: " ")
        guard words.count <= 3 else { return false }
        let hasOnlyLetters = words.allSatisfy { word in
            word.allSatisfy { $0.isLetter || $0.isWhitespace || $0 == "-" }
        }
        return hasOnlyLetters && !isCompanyLine(line) && !isAddressLine(line)
    }

    private static func isAddressLine(_ line: String) -> Bool {
        let lower = line.lowercased()
        let keywords = ["sok.", "cad.", "mah.", "no:", "kat:", "blok", "apt", "st.", "ave.", "floor", "suite"]
        return keywords.contains { lower.contains($0) }
    }

    private static func cleanPunctuation(_ s: String) -> String {
        s.trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
    }

    private static func firstMatch(_ regex: NSRegularExpression, in line: String) -> String? {
        let range = NSRange(line.startIndex..., in: line)
        guard let m = regex.firstMatch(in: line, range: range),
              let r = Range(m.range, in: line) else { return nil }
        return String(line[r])
    }

    private static func hasMatch(_ regex: NSRegularExpression, in line: String) -> Bool {
        let range = NSRange(line.startIndex..., in: line)
        return regex.firstMatch(in: line, range: range) != nil
    }
}
