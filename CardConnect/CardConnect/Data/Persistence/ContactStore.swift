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
        modelContext.delete(contact)
        try modelContext.save()
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

    // MARK: - search (stub — #91)

    func search(query: String) throws -> [Contact] {
        // TODO: #91 — Swift-side fulltext filter
        return []
    }

    // MARK: - findDuplicate (stub — #90)

    func findDuplicate(
        firstName: String,
        lastName: String,
        company: String,
        phones: [String],
        emails: [String]
    ) throws -> Contact? {
        // TODO: #90 — Swift-side duplicate detection
        return nil
    }
}
