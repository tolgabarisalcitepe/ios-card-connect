import SwiftUI
import SwiftData

struct ContactsView: View {
    @Query(sort: \Contact.updatedAt, order: .reverse)
    private var contacts: [Contact]

    @StateObject private var viewModel = ContactsViewModel()
    @State private var searchText = ""

    var body: some View {
        Group {
            if contacts.isEmpty {
                allEmptyState
            } else if viewModel.displayedContacts.isEmpty {
                searchEmptyState
            } else {
                list
            }
        }
        .navigationTitle("Kişiler")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Kişi ara")
        .onChange(of: searchText) { _, newValue in
            viewModel.update(query: newValue, contacts: contacts)
        }
        .onChange(of: contacts) { _, newValue in
            viewModel.update(query: searchText, contacts: newValue)
        }
        .onAppear {
            viewModel.update(query: searchText, contacts: contacts)
        }
        .accessibilityIdentifier("contacts_view")
    }

    // MARK: - List

    private var list: some View {
        List(viewModel.displayedContacts) { contact in
            NavigationLink(value: AppRoute.detail(contactID: contact.id)) {
                ContactRowView(contact: contact)
            }
            .accessibilityIdentifier("contact_row_\(contact.id)")
        }
        .listStyle(.plain)
    }

    // MARK: - Empty states

    private var allEmptyState: some View {
        ContentUnavailableView {
            Label("Henüz kişi yok", systemImage: "person.crop.rectangle.stack")
        } description: {
            Text("Kartvizit tarayarak kişi ekleyebilirsin.")
        } actions: {
            NavigationLink(value: AppRoute.camera) {
                Label("Kartvizit Tara", systemImage: "camera")
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityIdentifier("contacts_empty_state")
    }

    private var searchEmptyState: some View {
        ContentUnavailableView.search(text: searchText)
            .accessibilityIdentifier("contacts_search_empty_state")
    }
}

// MARK: - ContactRowView

private struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            InitialsAvatarView(fullName: contact.fullName)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.fullName.isEmpty ? "—" : contact.fullName)
                    .font(.headline)

                let subtitle = [contact.company, contact.title]
                    .filter { !$0.isEmpty }
                    .joined(separator: " · ")
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let eventName = contact.eventName, !eventName.isEmpty {
                Text(eventName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.blue.opacity(0.12))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
                    .lineLimit(1)
                    .accessibilityIdentifier("contact_event_badge")
            }
        }
        .padding(.vertical, 4)
    }
}
