import Foundation

/// Kişi listesi arama + debounce ViewModel.
/// `contactStore` DI hazır olduğunda `update` → `contactStore.search` ile değiştirilebilir.
@MainActor
final class ContactsViewModel: ObservableObject {
    @Published private(set) var displayedContacts: [Contact] = []

    private var debounceTask: Task<Void, Never>?

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
