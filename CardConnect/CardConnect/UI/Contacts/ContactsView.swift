import SwiftUI
import SwiftData

struct ContactsView: View {
    @Query(sort: \Contact.updatedAt, order: .reverse)
    private var contacts: [Contact]

    var body: some View {
        Group {
            if contacts.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Kişiler")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("contacts_view")
    }

    // MARK: - List

    private var list: some View {
        List(contacts) { contact in
            NavigationLink(value: AppRoute.detail(contactID: contact.id)) {
                ContactRowView(contact: contact)
            }
            .accessibilityIdentifier("contact_row_\(contact.id)")
        }
        .listStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
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
