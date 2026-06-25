import Foundation

/// Kartvizit duplikat tespiti — saf fonksiyon, DB bağımlılığı yok.
struct DuplicateDetector {

    /// `candidates` listesi içinde `incoming` ile eşleşen ilk kişiyi döner.
    /// Eşleşme önceliği: (1) name+company → (2) phone → (3) email.
    /// Boş alanlar eşleşme kriteri olarak kullanılmaz.
    /// Self-match engellenir (aynı id).
    @discardableResult
    static func findDuplicate(
        incoming: Contact,
        in candidates: [Contact]
    ) -> Contact? {
        for candidate in candidates {
            guard candidate.id != incoming.id else { continue }

            // 1. Name + company exact match
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

            // 2. Phone intersection
            let incomingPhones = Set(incoming.phones.map { $0.normalizedPhone })
                .filter { !$0.isEmpty }
            let candidatePhones = Set(candidate.phones.map { $0.normalizedPhone })
                .filter { !$0.isEmpty }

            if !incomingPhones.isEmpty,
               !incomingPhones.isDisjoint(with: candidatePhones) {
                return candidate
            }

            // 3. Email intersection (case-insensitive)
            let incomingEmails = Set(incoming.emails.map { $0.lowercased() })
                .filter { !$0.isEmpty }
            let candidateEmails = Set(candidate.emails.map { $0.lowercased() })
                .filter { !$0.isEmpty }

            if !incomingEmails.isEmpty,
               !incomingEmails.isDisjoint(with: candidateEmails) {
                return candidate
            }
        }
        return nil
    }
}

// MARK: - Phone normalization helper
private extension String {
    /// Telefon numarasından boşluk, tire, parantez ve artı kaldırır.
    var normalizedPhone: String {
        self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
}
