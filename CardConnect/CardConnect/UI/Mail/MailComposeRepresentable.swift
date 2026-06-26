// MailComposeRepresentable.swift
// CardConnect

import SwiftUI
import MessageUI

struct MailComposeRepresentable: UIViewControllerRepresentable {

    let recipients: [String]
    let subject: String
    let body: String
    /// .ics binary — nil ise ek eklenmez.
    let icsData: Data?
    let onDismiss: (MFMailComposeResult) -> Void

    // MARK: - Availability

    static var isAvailable: Bool { MFMailComposeViewController.canSendMail() }

    // MARK: - UIViewControllerRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(recipients)
        composer.setSubject(subject)
        composer.setMessageBody(body, isHTML: false)
        if let data = icsData {
            composer.addAttachmentData(data, mimeType: "text/calendar", fileName: "invite.ics")
        }
        return composer
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {

        let parent: MailComposeRepresentable

        init(parent: MailComposeRepresentable) {
            self.parent = parent
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            controller.dismiss(animated: true)
            parent.onDismiss(result)
        }
    }
}
