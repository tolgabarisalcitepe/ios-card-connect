import SwiftUI
import SwiftData

struct DetailView: View {
    let contactID: UUID

    @Query private var contacts: [Contact]
    @State private var selectedPhotoPath: String?

    init(contactID: UUID) {
        self.contactID = contactID
        _contacts = Query(filter: #Predicate { $0.id == contactID })
    }

    private var contact: Contact? { contacts.first }

    var body: some View {
        Group {
            if let contact {
                content(contact)
            } else {
                ContentUnavailableView("Kişi bulunamadı", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("detail_view")
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ contact: Contact) -> some View {
        List {
            // Header
            Section {
                headerSection(contact)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            // Photos
            if !contact.photoPaths.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(contact.photoPaths, id: \.self) { path in
                                if let uiImage = UIImage(contentsOfFile: path) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .onTapGesture { selectedPhotoPath = path }
                                        .accessibilityIdentifier("detail_photo_thumbnail")
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            // Phones
            if !contact.phones.isEmpty {
                Section("Telefon") {
                    ForEach(contact.phones, id: \.self) { phone in
                        let digits = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                        if let url = URL(string: "tel:\(digits)") {
                            Link(destination: url) {
                                Label(phone, systemImage: "phone")
                                    .foregroundStyle(.primary)
                            }
                            .accessibilityIdentifier("detail_phone_\(digits)")
                        }
                    }
                }
            }

            // Emails
            if !contact.emails.isEmpty {
                Section("E-posta") {
                    ForEach(contact.emails, id: \.self) { email in
                        if let url = URL(string: "mailto:\(email)") {
                            Link(destination: url) {
                                Label(email, systemImage: "envelope")
                                    .foregroundStyle(.primary)
                            }
                            .accessibilityIdentifier("detail_email")
                        }
                    }
                }
            }

            // Address
            if !contact.address.isEmpty {
                Section("Adres") {
                    let encoded = contact.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    if let url = URL(string: "maps://?q=\(encoded)") {
                        Link(destination: url) {
                            Label(contact.address, systemImage: "map")
                                .foregroundStyle(.primary)
                        }
                        .accessibilityIdentifier("detail_address")
                    } else {
                        Label(contact.address, systemImage: "map")
                    }
                }
            }

            // LinkedIn
            if !contact.linkedin.isEmpty,
               URLValidator.isValidLinkedIn(contact.linkedin),
               let url = URL(string: contact.linkedin) {
                Section("LinkedIn") {
                    Link(destination: url) {
                        Label(contact.linkedin, systemImage: "link")
                            .foregroundStyle(.primary)
                    }
                    .accessibilityIdentifier("detail_linkedin")
                }
            }

            // Notes
            if !contact.notes.isEmpty {
                Section("Notlar") {
                    Text(contact.notes)
                        .font(.body)
                        .accessibilityIdentifier("detail_notes")
                }
            }
        }
        .navigationTitle(contact.fullName.isEmpty ? "Kişi Detayı" : contact.fullName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if let url = try? VCardExporter.writeToTempFile(contact: contact) {
                    ShareLink(
                        item: url,
                        preview: SharePreview(
                            contact.fullName.isEmpty ? "Kişi" : contact.fullName,
                            image: Image(systemName: "person.crop.circle")
                        )
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityIdentifier("detail_share_button")
                }
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { selectedPhotoPath != nil },
            set: { if !$0 { selectedPhotoPath = nil } }
        )) {
            if let path = selectedPhotoPath,
               let uiImage = UIImage(contentsOfFile: path) {
                ZStack(alignment: .topTrailing) {
                    Color.black.ignoresSafeArea()
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                    Button {
                        selectedPhotoPath = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .padding()
                    }
                    .accessibilityIdentifier("detail_photo_dismiss")
                }
            }
        }
    }

    // MARK: - Header

    private func headerSection(_ contact: Contact) -> some View {
        VStack(spacing: 12) {
            InitialsAvatarView(fullName: contact.fullName, size: 72)

            VStack(spacing: 4) {
                Text(contact.fullName.isEmpty ? "—" : contact.fullName)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("detail_full_name")

                if !contact.company.isEmpty || !contact.title.isEmpty {
                    let sub = [contact.title, contact.company]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                    Text(sub)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if let eventName = contact.eventName, !eventName.isEmpty {
                    Text(eventName)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.12))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
