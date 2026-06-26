import Foundation
import SwiftData

@MainActor
final class ContactEditViewModel: ObservableObject {
    @Published var isSaving = false
    @Published var saveError: String?

    // MARK: - Save

    func save(
        contact: Contact,
        firstName: String,
        lastName: String,
        company: String,
        title: String,
        phones: [String],
        emails: [String],
        address: String,
        linkedin: String,
        notes: String,
        in modelContext: ModelContext
    ) async -> Bool {
        isSaving = true
        defer { isSaving = false }

        if let error = validate(firstName: firstName, emails: emails, linkedin: linkedin) {
            saveError = error
            return false
        }

        contact.firstName = firstName.trimmingCharacters(in: .whitespaces)
        contact.lastName  = lastName.trimmingCharacters(in: .whitespaces)
        contact.company   = company.trimmingCharacters(in: .whitespaces)
        contact.title     = title.trimmingCharacters(in: .whitespaces)
        contact.phones    = phones.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        contact.emails    = emails.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        contact.address   = address.trimmingCharacters(in: .whitespaces)
        contact.linkedin  = linkedin.trimmingCharacters(in: .whitespaces)
        contact.notes     = notes.trimmingCharacters(in: .whitespaces)
        contact.updatedAt = Date()

        do {
            try modelContext.save()
            // TODO: Bug #133 — if contact.deviceContactId != nil → DeviceContactsService.update(contact)
            return true
        } catch {
            saveError = "Kayıt sırasında hata oluştu."
            return false
        }
    }

    // MARK: - Validation

    private func validate(firstName: String, emails: [String], linkedin: String) -> String? {
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty else {
            return "Ad alanı zorunludur."
        }
        for email in emails where !email.trimmingCharacters(in: .whitespaces).isEmpty {
            guard isValidEmailFormat(email) else {
                return "Geçersiz e-posta adresi: \(email)"
            }
        }
        if !linkedin.isEmpty, !URLValidator.isValidLinkedIn(linkedin) {
            return "Geçersiz LinkedIn URL'i."
        }
        return nil
    }

    private func isValidEmailFormat(_ email: String) -> Bool {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2 else { return false }
        return parts[1].contains(".")
    }
}
