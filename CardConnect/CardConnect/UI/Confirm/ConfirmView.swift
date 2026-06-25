// ConfirmView.swift
// CardConnect
// Android Cat-3: @SceneStorage ile form draft process death sonrası korunur.

import SwiftUI

struct ConfirmView: View {
    @Binding var path: NavigationPath
    @Environment(\.dependencies) private var dependencies

    // MARK: - @SceneStorage (Cat-3: process death koruması)

    @SceneStorage("confirm.firstName")   private var firstName   = ""
    @SceneStorage("confirm.lastName")    private var lastName    = ""
    @SceneStorage("confirm.company")     private var company     = ""
    @SceneStorage("confirm.jobTitle")    private var jobTitle    = ""
    @SceneStorage("confirm.linkedin")    private var linkedin    = ""
    @SceneStorage("confirm.notes")       private var notes       = ""
    @SceneStorage("confirm.phonesJSON")  private var phonesJSON  = "[]"
    @SceneStorage("confirm.emailsJSON")  private var emailsJSON  = "[]"
    @SceneStorage("confirm.photoJSON")   private var photoJSON   = "[]"
    @SceneStorage("confirm.sourceRaw")   private var sourceRaw   = ContactSource.businessCard.rawValue
    @SceneStorage("confirm.hasLoaded")   private var hasLoaded   = false

    // MARK: - @State (düzenleme için yerel kopya)

    @State private var phones: [String] = []
    @State private var emails: [String] = []
    @State private var photoPaths: [URL] = []
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        List {
            qrBanner
            photoSection
            nameSection
            phoneSection
            emailSection
            otherSection
        }
        .navigationTitle("Kaydet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Yeniden Çek") {
                    clearDraft()
                    path.removeLast()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Kaydediliyor…" : "Kaydet") {
                    Task { await save() }
                }
                .disabled(isSaving || firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                .fontWeight(.semibold)
            }
        }
        .task { await load() }
        .onChange(of: phones) { _, v in phonesJSON = encode(v) }
        .onChange(of: emails) { _, v in emailsJSON = encode(v) }
        .alert("Kayıt Hatası", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var qrBanner: some View {
        if sourceRaw == ContactSource.qrCode.rawValue {
            HStack(spacing: 10) {
                Image(systemName: "qrcode")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("QR Kod Kaynağı")
                        .font(.subheadline.bold())
                    Text("Veri QR koddan alındı. Lütfen bilgileri doğrulayın.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        if !photoPaths.isEmpty {
            Section {
                TabView {
                    ForEach(photoPaths, id: \.absoluteString) { url in
                        if let img = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(height: 200)
            }
        }
    }

    private var nameSection: some View {
        Section("Kişi Bilgileri") {
            TextField("Ad *", text: $firstName)
                .textContentType(.givenName)
            TextField("Soyad", text: $lastName)
                .textContentType(.familyName)
            TextField("Şirket", text: $company)
                .textContentType(.organizationName)
            TextField("Ünvan", text: $jobTitle)
                .textContentType(.jobTitle)
        }
    }

    @ViewBuilder private var phoneSection: some View {
        Section("Telefon") {
            ForEach(0..<phones.count, id: \.self) { i in
                PhoneEmailRowView(
                    value: Binding(
                        get: { phones[i] },
                        set: { v in var p = phones; p[i] = v; phones = p }
                    ),
                    type: .phone,
                    onDelete: { var p = phones; p.remove(at: i); phones = p }
                )
            }
            Button("+ Telefon ekle") { phones.append("") }
                .foregroundStyle(Color.accentColor)
        }
    }

    @ViewBuilder private var emailSection: some View {
        Section("E-posta") {
            ForEach(0..<emails.count, id: \.self) { i in
                PhoneEmailRowView(
                    value: Binding(
                        get: { emails[i] },
                        set: { v in var e = emails; e[i] = v; emails = e }
                    ),
                    type: .email,
                    onDelete: { var e = emails; e.remove(at: i); emails = e }
                )
            }
            Button("+ E-posta ekle") { emails.append("") }
                .foregroundStyle(Color.accentColor)
        }
    }

    private var otherSection: some View {
        Section("Diğer") {
            TextField("LinkedIn", text: $linkedin)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
            TextField("Notlar", text: $notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    // MARK: - Load / Save

    private func load() async {
        if hasLoaded {
            phones = decode(phonesJSON)
            emails = decode(emailsJSON)
            photoPaths = decode(photoJSON).compactMap { URL(string: $0) }
            return
        }
        let card  = await dependencies.scanFlow.parsedCard ?? ParsedCard()
        let paths = await dependencies.scanFlow.photoPaths

        firstName   = card.firstName
        lastName    = card.lastName
        company     = card.company
        jobTitle    = card.title
        linkedin    = card.linkedin
        notes       = card.notes
        phones      = card.phones
        emails      = card.emails
        photoPaths  = paths
        phonesJSON  = encode(card.phones)
        emailsJSON  = encode(card.emails)
        photoJSON   = encode(paths.map(\.absoluteString))
        if await dependencies.scanFlow.incomingVCard != nil {
            sourceRaw = ContactSource.qrCode.rawValue
        }
        hasLoaded   = true
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let contact = ConfirmViewModel.buildContact(
            firstName: firstName,
            lastName: lastName,
            company: company,
            title: jobTitle,
            phones: phones.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            emails: emails.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty },
            linkedin: linkedin,
            notes: notes,
            source: ContactSource(rawValue: sourceRaw) ?? .businessCard,
            photoPaths: photoPaths.map(\.path)
        )

        // TODO: ContactStore.insert(contact) — Epic 2 (#19)
        _ = contact

        await dependencies.scanFlow.reset()
        clearDraft()
        path.removeLast(path.count)
    }

    private func clearDraft() {
        firstName = ""; lastName = ""; company = ""; jobTitle = ""
        linkedin = ""; notes = ""
        phonesJSON = "[]"; emailsJSON = "[]"; photoJSON = "[]"
        hasLoaded = false
    }

    // MARK: - Helpers

    private func encode(_ arr: [String]) -> String {
        (try? String(data: JSONEncoder().encode(arr), encoding: .utf8)) ?? "[]"
    }

    private func decode(_ json: String) -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
    }
}
