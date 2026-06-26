// MailComposeView.swift
// CardConnect

import SwiftUI
import SwiftData

struct MailComposeView: View {

    let contactID: UUID

    @Environment(\.dependencies) private var dependencies
    @Query private var allTemplates: [EmailTemplate]
    @Query private var allContacts: [Contact]

    @State private var profile = UserProfile()
    @State private var selectedTemplate: EmailTemplate?
    @State private var resolvedSubject = ""
    @State private var resolvedBody = ""
    @State private var missingVars: [String] = []

    private var contact: Contact? {
        allContacts.first { $0.id == contactID }
    }

    private var recipientEmail: String? {
        contact?.emails.first
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let contact, !contact.emails.isEmpty {
                mainContent(contact: contact)
            } else {
                ContentUnavailableView(
                    "E-posta Adresi Yok",
                    systemImage: "envelope.badge.shield.half.filled",
                    description: Text("Bu kişide kayıtlı e-posta adresi bulunmuyor.")
                )
            }
        }
        .navigationTitle("E-posta Gönder")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            profile = await dependencies.userProfileStore.load()
        }
        .onChange(of: allTemplates) { _, templates in
            if selectedTemplate == nil, let first = templates.first {
                applyTemplate(first, contact: contact)
            }
        }
        .onChange(of: profile.fullName) {
            if let t = selectedTemplate { applyTemplate(t, contact: contact) }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func mainContent(contact: Contact) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Alıcı
                recipientRow(email: contact.emails.first!)

                // Şablon chip seçici
                if !allTemplates.isEmpty {
                    templateChipSelector(contact: contact)
                }

                // Eksik değişken uyarısı
                if !missingVars.isEmpty {
                    missingVarsBanner
                }

                // Çözümlenmiş konu + gövde önizleme
                if selectedTemplate != nil {
                    resolvedPreview
                }
            }
            .padding()
        }
    }

    // MARK: - Recipient row

    private func recipientRow(email: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "envelope")
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(email)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Template chip selector

    private func templateChipSelector(contact: Contact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Şablon")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(allTemplates) { template in
                        TemplateChipButton(
                            template: template,
                            isSelected: selectedTemplate?.id == template.id
                        ) {
                            applyTemplate(template, contact: contact)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Missing vars banner

    private var missingVarsBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("Eksik değişkenler: \(missingVars.joined(separator: ", "))")
                .font(.footnote)
                .foregroundStyle(.primary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Resolved preview

    private var resolvedPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Konu
            VStack(alignment: .leading, spacing: 4) {
                Text("Konu")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(resolvedSubject)
                    .font(.body.weight(.medium))
            }

            Divider()

            // Gövde
            VStack(alignment: .leading, spacing: 4) {
                Text("İçerik")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(resolvedBody)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func applyTemplate(_ template: EmailTemplate, contact: Contact?) {
        guard let contact else { return }
        let resolver = MailTemplateResolver(contact: contact, profile: profile)
        resolvedSubject = resolver.resolveSubject(template.subject)
        resolvedBody = resolver.resolveBody(template.body)
        selectedTemplate = template
        let combined = resolver.findMissingVars(in: template.subject)
            + resolver.findMissingVars(in: template.body)
        var seen = Set<String>()
        missingVars = combined.filter { seen.insert($0).inserted }
    }
}

// MARK: - TemplateChipButton

private struct TemplateChipButton: View {
    let template: EmailTemplate
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: template.iconName)
                    .font(.subheadline)
                Text(template.name)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color.accentColor : Color.secondary.opacity(0.15),
                in: Capsule()
            )
            .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
