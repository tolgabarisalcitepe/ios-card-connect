import SwiftUI

/// Duplikat diff görünümü + merge / yeni kayıt aksiyonları.
struct DuplicateView: View {
    let existing: Contact
    let incoming: Contact
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = DuplicateViewModel()

    var body: some View {
        List {
            Section {
                headerRow
            }

            let diffs = computeDiffs()
            if diffs.isEmpty {
                Text("Fark bulunamadı")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                Section(header: Text("Farklı Alanlar")) {
                    ForEach(diffs) { diff in
                        DiffRowView(diff: diff)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Olası Duplikat")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("duplicate_view")
        .safeAreaInset(edge: .bottom) {
            actionButtons
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    let ok = await viewModel.mergeAndContinue(
                        existing: existing,
                        incoming: incoming,
                        modelContext: modelContext,
                        scanFlow: dependencies.scanFlow
                    )
                    if ok { dismiss() }
                }
            } label: {
                Label("Mevcut Kaydı Güncelle", systemImage: "arrow.triangle.merge")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier("duplicate_merge_button")

            Button {
                Task {
                    let ok = await viewModel.continueAsNew(scanFlow: dependencies.scanFlow)
                    if ok { dismiss() }
                }
            } label: {
                Label("Yeni Kayıt Oluştur", systemImage: "person.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)
            .accessibilityIdentifier("duplicate_new_button")
        }
        .padding()
        .background(.regularMaterial)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            contactCard(label: "Mevcut", contact: existing)
            Divider()
            contactCard(label: "Yeni Gelen", contact: incoming)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func contactCard(label: String, contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(contact.fullName.isEmpty ? "—" : contact.fullName)
                .font(.headline)
            if !contact.company.isEmpty {
                Text(contact.company)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }

    // MARK: - Diff computation

    private func computeDiffs() -> [FieldDiff] {
        var diffs: [FieldDiff] = []

        func add(_ field: String, existing val: String, incoming val2: String) {
            guard !val2.isEmpty, val.lowercased() != val2.lowercased() else { return }
            diffs.append(FieldDiff(field: field, existingValue: val.isEmpty ? nil : val, incomingValue: val2))
        }

        func addList(_ field: String, existing vals: [String], incoming vals2: [String]) {
            let newOnly = vals2.filter { !vals.contains($0) }
            guard !newOnly.isEmpty else { return }
            diffs.append(FieldDiff(field: field, existingValue: vals.isEmpty ? nil : vals.joined(separator: "\n"), incomingValue: newOnly.joined(separator: "\n")))
        }

        add("Ad",       existing: existing.firstName, incoming: incoming.firstName)
        add("Soyad",    existing: existing.lastName,  incoming: incoming.lastName)
        add("Şirket",   existing: existing.company,   incoming: incoming.company)
        add("Unvan",    existing: existing.title,      incoming: incoming.title)
        add("Adres",    existing: existing.address,    incoming: incoming.address)
        add("LinkedIn", existing: existing.linkedin,   incoming: incoming.linkedin)
        addList("Telefon", existing: existing.phones,  incoming: incoming.phones)
        addList("E-posta", existing: existing.emails,  incoming: incoming.emails)

        if !incoming.notes.isEmpty,
           !existing.notes.contains(incoming.notes.trimmingCharacters(in: .whitespacesAndNewlines)) {
            diffs.append(FieldDiff(
                field: "Notlar",
                existingValue: existing.notes.isEmpty ? nil : existing.notes,
                incomingValue: incoming.notes
            ))
        }

        return diffs
    }
}

// MARK: - FieldDiff model

struct FieldDiff: Identifiable {
    let id = UUID()
    let field: String
    let existingValue: String?
    let incomingValue: String
}

// MARK: - DiffRowView

struct DiffRowView: View {
    let diff: FieldDiff

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(diff.field)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let existing = diff.existingValue {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red.opacity(0.7))
                        .font(.caption)
                    Text(existing)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.6))
                        .strikethrough(color: .red.opacity(0.5))
                }
            }

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
                Text(diff.incomingValue)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
        .accessibilityIdentifier("diff_row_\(diff.field.lowercased())")
    }
}
