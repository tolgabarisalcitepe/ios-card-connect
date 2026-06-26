// MailComposeViewModel.swift
// CardConnect

import Foundation
import MessageUI
import UIKit
import UniformTypeIdentifiers

@MainActor final class MailComposeViewModel: ObservableObject {

    // MARK: - Calendar state

    @Published var dayEvents: [CalendarEvent] = []
    @Published var isLoadingEvents = false

    // MARK: - Send state

    @Published var showMailCompose = false   // invite yok → MFMailCompose
    @Published var showActivity = false      // invite var → UIActivityViewController
    @Published var mailUnavailable = false   // mail app yok, invite yok

    private(set) var mailComposeICSData: Data?      // MailComposeRepresentable'a geçilir
    private(set) var activityItemsBuffer: [Any] = [] // ActivityView'a geçilir

    // MARK: - Calendar

    func loadEventsForDay(_ date: Date, calendarService: CalendarService) async {
        isLoadingEvents = true
        defer { isLoadingEvents = false }
        dayEvents = await calendarService.getEventsForDay(date)
    }

    /// meetingDate + 1 saat aralığıyla çakışan etkinlikler.
    func conflictingEvents(for meetingDate: Date) -> [CalendarEvent] {
        let meetingEnd = meetingDate.addingTimeInterval(3600)
        return dayEvents.filter { event in
            event.startDate < meetingEnd && event.endDate > meetingDate
        }
    }

    // MARK: - Send

    func prepareSend(
        contactID: UUID,
        recipients: [String],
        subject: String,
        body: String,
        includeInvite: Bool,
        meetingDate: Date,
        organizerName: String,
        organizerEmail: String
    ) {
        if includeInvite {
            // ICS oluştur → temp dosyaya yaz → UIActivityViewController
            let uid = "\(contactID)-\(Int(meetingDate.timeIntervalSince1970))@cardconnect"
            let event = ICSGenerator.ICSEvent(
                uid: uid,
                summary: subject,
                dtStart: meetingDate,
                dtEnd: meetingDate.addingTimeInterval(3600),
                location: nil,
                description: body.isEmpty ? nil : body,
                organizerName: organizerName,
                organizerEmail: organizerEmail,
                attendeeEmail: recipients.first ?? ""
            )
            let icsString = ICSGenerator.generate(event)
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("invite-\(contactID).ics")
            try? icsString.write(to: tmpURL, atomically: true, encoding: .utf8)

            let source = ICSActivityItemSource(
                icsURL: tmpURL,
                subject: subject,
                body: body
            )
            activityItemsBuffer = [source]
            showActivity = true
        } else {
            activityItemsBuffer = []
            mailComposeICSData = nil
            if MailComposeRepresentable.isAvailable {
                showMailCompose = true
            } else {
                mailUnavailable = true
            }
        }
    }

    func handleMailResult(_ result: MFMailComposeResult) {
        showMailCompose = false
    }
}

// MARK: - ICSActivityItemSource

final class ICSActivityItemSource: NSObject, UIActivityItemSource {

    private let icsURL: URL
    private let subject: String
    private let body: String

    init(icsURL: URL, subject: String, body: String) {
        self.icsURL = icsURL
        self.subject = subject
        self.body = body
    }

    func activityViewControllerPlaceholderItem(
        _ activityViewController: UIActivityViewController
    ) -> Any { icsURL }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? { icsURL }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String { UTType.calendarEvent.identifier }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String { subject }
}
