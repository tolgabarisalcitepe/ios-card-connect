import SwiftUI
import SwiftData

struct ContactsView: View {
    @Query(sort: \Contact.updatedAt, order: .reverse)
    private var contacts: [Contact]

    @StateObject private var viewModel = ContactsViewModel()
    @State private var searchText = ""
    @Environment(\.modelContext) private var modelContext
    @State private var contactToDelete: Contact?
    @AppStorage("contacts_swipe_hint_shown") private var swipeHintShown = false
    @State private var showSwipeHint = false

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
            if !swipeHintShown && !contacts.isEmpty {
                showSwipeHint = true
                swipeHintShown = true
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    showSwipeHint = false
                }
            }
        }
        .confirmationDialog(
            "Bu kişiyi silmek istediğinden emin misin?",
            isPresented: Binding(
                get: { contactToDelete != nil },
                set: { if !$0 { contactToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let contact = contactToDelete {
                Button("Sil", role: .destructive) {
                    viewModel.delete(contact, in: modelContext)
                    contactToDelete = nil
                }
            }
            Button("İptal", role: .cancel) {
                contactToDelete = nil
            }
        }
        .alert("Hata", isPresented: Binding(
            get: { viewModel.deleteError != nil },
            set: { if !$0 { viewModel.deleteError = nil } }
        )) {
            Button("Tamam", role: .cancel) { viewModel.deleteError = nil }
        } message: {
            Text(viewModel.deleteError ?? "")
        }
        .safeAreaInset(edge: .bottom) {
            if showSwipeHint {
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                    Text("Aksiyonlar için sola veya sağa kaydır")
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: showSwipeHint)
        .accessibilityIdentifier("contacts_view")
    }

    // MARK: - List

    private var list: some View {
        List(viewModel.displayedContacts) { contact in
            NavigationLink(value: AppRoute.detail(contactID: contact.id)) {
                ContactRowView(contact: contact)
            }
            .accessibilityIdentifier("contact_row_\(contact.id)")
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    contactToDelete = contact
                } label: {
                    Label("Sil", systemImage: "trash")
                }
                .accessibilityIdentifier("contact_delete_swipe")
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                if !contact.linkedin.isEmpty,
                   URLValidator.isValidLinkedIn(contact.linkedin),
                   let url = URL(string: contact.linkedin) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        Label("LinkedIn", systemImage: "link")
                    }
                    .tint(.teal)
                    .accessibilityIdentifier("contact_linkedin_swipe")
                }
                if !contact.emails.isEmpty {
                    NavigationLink(value: AppRoute.mailCompose(contactID: contact.id)) {
                        Label("Mail", systemImage: "envelope")
                    }
                    .tint(.blue)
                    .accessibilityIdentifier("contact_mail_swipe")
                }
            }
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
