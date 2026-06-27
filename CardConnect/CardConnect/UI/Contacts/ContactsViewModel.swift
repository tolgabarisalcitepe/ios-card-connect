import Combine
import Foundation
import SwiftData

/// Kişi listesi arama + debounce ViewModel.
/// `contactStore` DI hazır olduğunda `update` → `contactStore.search` ile değiştirilebilir.
@MainActor
final class ContactsViewModel: ObservableObject {
    @Published private(set) var displayedContacts: [Contact] = []

    private var debounceTask: Task<Void, Never>?

    // MARK: - delete

    @Published var deleteError: String?

    func delete(_ contact: Contact, in modelContext: ModelContext) {
        do {
            modelContext.delete(contact)
            try modelContext.save()
            // TODO: Bug #133 — PhotoStorage.deletePhotos(contact.photoPaths)
            // TODO: Bug #133 — PhotoStorage.deleteICS(for: contact.id)
            // TODO: Bug #133 — DeviceContactsService.delete(contact.deviceContactId)
        } catch {
            deleteError = "Kişi silinemedi."
        }
    }

    func update(query: String, contacts: [Contact]) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            let q = query.trimmingCharacters(in: .whitespaces).lowercased()
            if q.isEmpty {
                displayedContacts = contacts
            } else {
                displayedContacts = contacts.filter { c in
                    c.firstName.lowercased().contains(q) ||
                    c.lastName.lowercased().contains(q)  ||
                    c.company.lowercased().contains(q)   ||
                    c.title.lowercased().contains(q)     ||
                    (c.eventName?.lowercased().contains(q) ?? false)
                }
            }
        }
    }
}
