// ScanFlowActor.swift
// CardConnect

import Foundation

actor ScanFlowActor {

    // MARK: - State

    private(set) var photoPaths: [URL] = []
    private(set) var parsedCard: ParsedCard? = nil
    private(set) var contactID: UUID? = nil
    private(set) var incomingVCard: String? = nil

    // MARK: - Mutations

    func addPhoto(_ url: URL) {
        photoPaths.append(url)
    }

    func setPhotoPaths(_ paths: [URL]) {
        photoPaths = paths
    }

    func setParsedCard(_ card: ParsedCard?) {
        parsedCard = card
    }

    func setContactID(_ id: UUID?) {
        contactID = id
    }

    func setIncomingVCard(_ vcard: String?) {
        incomingVCard = vcard
    }

    // MARK: - Reset

    /// Flow sonunda atomik olarak çağrılır. Android Cat-2 (stale state) önlemi.
    func reset() {
        photoPaths = []
        parsedCard = nil
        contactID = nil
        incomingVCard = nil
    }
}
