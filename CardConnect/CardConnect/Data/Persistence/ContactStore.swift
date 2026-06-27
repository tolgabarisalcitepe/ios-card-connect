import Foundation
import SwiftData

/// SwiftData destekli kişi deposu.
/// search → #91, findDuplicate → #90, DI wiring → Epic 2 entegrasyon adımı.
@ModelActor
actor ContactStore: ContactStoreProtocol {

    // MARK: - insert

    func insert(_ contact: Contact) throws {
        modelContext.insert(contact)
        try modelContext.save()
    }

    // MARK: - update

    /// Caller, contact'ın bu context'e ait olduğundan emin olmalı.
    func update(_ contact: Contact) throws {
        try modelContext.save()
    }

    // MARK: - delete

    func delete(id: UUID) throws {
        var descriptor = FetchDescriptor<Contact>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let contact = try modelContext.fetch(descriptor).first else { return }

        // Snapshot before deletion
        let photoPaths     = contact.photoPaths
        let contactID      = contact.id
        let deviceContactId = contact.deviceContactId

        modelContext.delete(contact)
        try modelContext.save()

        // Disk cleanup: photos + ICS (best-effort, non-throwing)
        PhotoStorage.deletePhotos(paths: photoPaths)
        PhotoStorage.deleteICS(contactID: contactID)

        // CNContact cleanup (best-effort, fire-and-forget)
        if let dcId = deviceContactId, !dcId.isEmpty {
            Task { try? await DeviceContactsService().delete(deviceContactId: dcId) }
        }
    }

    // MARK: - fetchAll

    /// `updatedAt` azalan sırada tüm kişileri döner.
    func fetchAll() throws -> [Contact] {
        try modelContext.fetch(
            FetchDescriptor<Contact>(
                sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
            )
        )
    }

    // MARK: - fetchById

    func fetchById(_ id: UUID) throws -> Contact? {
        var descriptor = FetchDescriptor<Contact>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - search

    /// Boş query tüm kişileri döner.
    /// Filtre alanları: firstName, lastName, company, title, eventName.
    func search(query: String) throws -> [Contact] {
        let all = try fetchAll()
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter { c in
            c.firstName.lowercased().contains(q) ||
            c.lastName.lowercased().contains(q)  ||
            c.company.lowercased().contains(q)   ||
            c.title.lowercased().contains(q)     ||
            (c.eventName?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - findDuplicate

    /// Swift-side eşleştirme — `#Predicate`/`LIKE` kullanılmaz.
    /// Öncelik: (1) name+company → (2) phone → (3) email.
    func findDuplicate(
        firstName: String,
        lastName: String,
        company: String,
        phones: [String],
        emails: [String]
    ) throws -> Contact? {
        let all = try fetchAll()

        let fn = firstName.trimmingCharacters(in: .whitespaces)
        let ln = lastName.trimmingCharacters(in: .whitespaces)
        let co = company.trimmingCharacters(in: .whitespaces)

        // 1. name + company (case-insensitive)
        if !fn.isEmpty {
            if let match = all.first(where: {
                $0.firstName.trimmingCharacters(in: .whitespaces).lowercased() == fn.lowercased() &&
                $0.lastName.trimmingCharacters(in: .whitespaces).lowercased()  == ln.lowercased() &&
                $0.company.trimmingCharacters(in: .whitespaces).lowercased()   == co.lowercased()
            }) { return match }
        }

        // 2. phone — digits-only normalizasyon
        let inPhones = phones.map { digitsOnly($0) }.filter { !$0.isEmpty }
        if !inPhones.isEmpty,
           let match = all.first(where: { contact in
               let cp = contact.phones.map { digitsOnly($0) }.filter { !$0.isEmpty }
               return inPhones.contains { cp.contains($0) }
           }) { return match }

        // 3. email — lowercase
        let inEmails = emails.map { $0.lowercased() }.filter { !$0.isEmpty }
        if !inEmails.isEmpty,
           let match = all.first(where: { contact in
               let ce = contact.emails.map { $0.lowercased() }.filter { !$0.isEmpty }
               return inEmails.contains { ce.contains($0) }
           }) { return match }

        return nil
    }

    /// Telefon numarasından rakam-dışı karakterleri kaldırır.
    private func digitsOnly(_ s: String) -> String {
        s.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
}
