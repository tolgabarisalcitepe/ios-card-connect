import Foundation

/// Kartvizit duplikat tespiti — saf fonksiyon, DB bağımlılığı yok.
struct DuplicateDetector {

    @discardableResult
    static func findDuplicate(
        incoming: Contact,
        in candidates: [Contact]
    ) -> Contact? {
        for candidate in candidates {
            guard candidate.id != incoming.id else { continue }

            let incomingName = incoming.fullName.trimmingCharacters(in: .whitespaces)
            let candidateName = candidate.fullName.trimmingCharacters(in: .whitespaces)
            let incomingCompany = incoming.company.trimmingCharacters(in: .whitespaces)
            let candidateCompany = candidate.company.trimmingCharacters(in: .whitespaces)

            if !incomingName.isEmpty,
               !candidateName.isEmpty,
               incomingName.lowercased() == candidateName.lowercased(),
               incomingCompany.lowercased() == candidateCompany.lowercased() {
                return candidate
            }

            let incomingPhones = Set(incoming.phones.map { $0.normalizedPhone }).filter { !$0.isEmpty }
            let candidatePhones = Set(candidate.phones.map { $0.normalizedPhone }).filter { !$0.isEmpty }

            if !incomingPhones.isEmpty, !incomingPhones.isDisjoint(with: candidatePhones) {
                return candidate
            }

            let incomingEmails = Set(incoming.emails.map { $0.lowercased() }).filter { !$0.isEmpty }
            let candidateEmails = Set(candidate.emails.map { $0.lowercased() }).filter { !$0.isEmpty }

            if !incomingEmails.isEmpty, !incomingEmails.isDisjoint(with: candidateEmails) {
                return candidate
            }
        }
        return nil
    }

    static func merge(existing: Contact, incoming: Contact) -> Contact {
        existing.firstName  = nonEmpty(existing.firstName,  fallback: incoming.firstName)
        existing.lastName   = nonEmpty(existing.lastName,   fallback: incoming.lastName)
        existing.company    = nonEmpty(existing.company,    fallback: incoming.company)
        existing.title      = nonEmpty(existing.title,      fallback: incoming.title)
        existing.linkedin   = nonEmpty(existing.linkedin,   fallback: incoming.linkedin)
        existing.address    = nonEmpty(existing.address,    fallback: incoming.address)

        existing.phones     = unionDistinct(existing.phones,     incoming.phones)
        existing.emails     = unionDistinct(existing.emails,     incoming.emails)
        existing.photoPaths = unionDistinct(existing.photoPaths, incoming.photoPaths)

        existing.notes      = mergeNotes(existing.notes, incoming.notes)

        existing.eventId         = existing.eventId         ?? incoming.eventId
        existing.eventName       = existing.eventName       ?? incoming.eventName
        existing.deviceContactId = existing.deviceContactId ?? incoming.deviceContactId

        existing.updatedAt = Date()
        return existing
    }

    private static func nonEmpty(_ primary: String, fallback: String) -> String {
        primary.trimmingCharacters(in: .whitespaces).isEmpty ? fallback : primary
    }

    private static func unionDistinct(_ primary: [String], _ secondary: [String]) -> [String] {
        var seen = Set<String>()
        return (primary + secondary).filter { seen.insert($0).inserted }
    }

    private static func mergeNotes(_ existing: String, _ incoming: String) -> String {
        let trimmed = incoming.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return existing }
        guard !existing.contains(trimmed) else { return existing }
        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return trimmed }
        return existing + "\n" + trimmed
    }
}

private extension String {
    var normalizedPhone: String {
        self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
}
