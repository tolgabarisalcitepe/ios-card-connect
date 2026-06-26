import SwiftUI
import SwiftData

struct ContactEditView: View {
    let contactID: UUID

    @Query private var contacts: [Contact]
    @Environment(\.dismiss) private var dismiss

    // Editable field copies
    @State private var firstName = ""
    @State private var lastName  = ""
    @State private var company   = ""
    @State private var title     = ""
    @State private var phones: [String] = []
    @State private var emails: [String] = []
    @State private var address   = ""
    @State private var linkedin  = ""
    @State private var notes     = ""

    @State private var hasLoaded  = false
    @State private var isSaving   = false
    @State private var saveError: String?

    private var contact: Contact? { contacts.first }
    private var canSave: Bool { !firstName.trimmingCharacters(in: .whitespaces).isEmpty }

    init(contactID: UUID) {
        self.contactID = contactID
        _contacts = Query(filter: #Predicate { $0.id == contactID })
    }

    var body: some View {
        List {
            nameSection
            phoneSection
            emailSection
            otherSection
        }
        .navigationTitle("Düzenle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("İptal") { dismiss() }
                    .accessibilityIdentifier("edit_cancel_button")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Kaydediliyor…" : "Kaydet") {
                    save()
                }
                .disabled(!canSave || isSaving)
                .fontWeight(.semibold)
                .accessibilityIdentifier("edit_save_button")
            }
        }
        .task { load() }
        .onChange(of: contact) { _, _ in load() }
        .onChange(of: firstName) { _, v in cap(&firstName,  FieldLimits.maxName) }
        .onChange(of: lastName)  { _, v in cap(&lastName,   FieldLimits.maxName) }
        .onChange(of: company)   { _, v in cap(&company,    FieldLimits.maxCompany) }
        .onChange(of: title)     { _, v in cap(&title,      FieldLimits.maxTitle) }
        .onChange(of: address)   { _, v in cap(&address,    FieldLimits.maxAddress) }
        .onChange(of: linkedin)  { _, v in cap(&linkedin,   FieldLimits.maxURL) }
        .onChange(of: notes)     { _, v in cap(&notes,      FieldLimits.maxNotes) }
        .alert("Kayıt Hatası", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
        .accessibilityIdentifier("edit_view")
    }

    // MARK: - Sections

    private var nameSection: some View {
        Section("Kişi Bilgileri") {
            TextField("Ad *", text: $firstName)
                .textContentType(.givenName)
                .accessibilityIdentifier("edit_first_name_field")
            TextField("Soyad", text: $lastName)
                .textContentType(.familyName)
                .accessibilityIdentifier("edit_last_name_field")
            TextField("Şirket", text: $company)
                .textContentType(.organizationName)
                .accessibilityIdentifier("edit_company_field")
            TextField("Ünvan", text: $title)
                .textContentType(.jobTitle)
                .accessibilityIdentifier("edit_title_field")
        }
    }

    @ViewBuilder
    private var phoneSection: some View {
        Section("Telefon") {
            ForEach(0..<phones.count, id: \.self) { i in
                PhoneEmailRowView(
                    value: Binding(
                        get: { phones[i] },
                        set: { v in
                            var p = phones
                            p[i] = String(v.prefix(FieldLimits.maxPhone))
                            phones = p
                        }
                    ),
                    type: .phone,
                    onDelete: {
                        var p = phones
                        p.remove(at: i)
                        phones = p
                    }
                )
            }
            Button("+ Telefon ekle") { phones.append("") }
                .foregroundStyle(Color.accentColor)
                .accessibilityIdentifier("edit_add_phone_button")
        }
    }

    @ViewBuilder
    private var emailSection: some View {
        Section("E-posta") {
            ForEach(0..<emails.count, id: \.self) { i in
                PhoneEmailRowView(
                    value: Binding(
                        get: { emails[i] },
                        set: { v in
                            var e = emails
                            e[i] = String(v.prefix(FieldLimits.maxEmail))
                            emails = e
                        }
                    ),
                    type: .email,
                    onDelete: {
                        var e = emails
                        e.remove(at: i)
                        emails = e
                    }
                )
            }
            Button("+ E-posta ekle") { emails.append("") }
                .foregroundStyle(Color.accentColor)
                .accessibilityIdentifier("edit_add_email_button")
        }
    }

    private var otherSection: some View {
        Section("Diğer") {
            TextField("Adres", text: $address)
                .textContentType(.fullStreetAddress)
                .accessibilityIdentifier("edit_address_field")
            TextField("LinkedIn", text: $linkedin)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .accessibilityIdentifier("edit_linkedin_field")
            TextField("Notlar", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .accessibilityIdentifier("edit_notes_field")
        }
    }

    // MARK: - Load

    private func load() {
        guard !hasLoaded, let c = contact else { return }
        firstName = c.firstName
        lastName  = c.lastName
        company   = c.company
        title     = c.title
        phones    = c.phones
        emails    = c.emails
        address   = c.address
        linkedin  = c.linkedin
        notes     = c.notes
        hasLoaded = true
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        defer { isSaving = false }
        // TODO: #101 — ContactEditViewModel persists changes via modelContext
        dismiss()
    }

    // MARK: - Helpers

    private func cap(_ field: inout String, _ limit: Int) {
        if field.count > limit { field = String(field.prefix(limit)) }
    }
}
