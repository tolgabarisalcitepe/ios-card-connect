// MailComposeView.swift
// CardConnect

import SwiftUI
import SwiftData
import UIKit

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
    @State private var includeInvite = false
    @State private var meetingDate: Date = {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }()
    @State private var calendarPermissionDenied = false
    @StateObject private var viewModel = MailComposeViewModel()

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
        .alert("Takvim İzni Gerekiyor", isPresented: $calendarPermissionDenied) {
            Button("Ayarlara Git") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Toplantı daveti eklemek için takvim erişimine izin verin.")
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

                // Toplantı daveti toggle + tarih seçici
                meetingInviteSection

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

    // MARK: - Meeting invite section

    private var meetingInviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Toplantı Daveti Ekle", isOn: $includeInvite)
                .onChange(of: includeInvite) { _, newValue in
                    if newValue { Task { await requestCalendarAccess() } }
                }

            if includeInvite {
                DatePicker(
                    "Tarih ve Saat",
                    selection: $meetingDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .onChange(of: meetingDate) { _, newDate in
                    Task {
                        await viewModel.loadEventsForDay(
                            newDate,
                            calendarService: dependencies.calendarService
                        )
                    }
                }

                // Yükleme göstergesi
                if viewModel.isLoadingEvents {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Takvim kontrol ediliyor…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Çakışma kartı
                let conflicts = viewModel.conflictingEvents(for: meetingDate)
                if !conflicts.isEmpty {
                    conflictCard(events: conflicts)
                }
            }
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func conflictCard(events: [CalendarEvent]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Çakışan Etkinlikler", systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)

            ForEach(events) { event in
                HStack(spacing: 6) {
                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                    Text(event.title)
                        .font(.footnote)
                    Spacer()
                    Text(event.startDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private func requestCalendarAccess() async {
        let granted = await dependencies.calendarService.requestAccess()
        if !granted {
            includeInvite = false
            calendarPermissionDenied = true
        } else {
            await viewModel.loadEventsForDay(meetingDate, calendarService: dependencies.calendarService)
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
