// DeviceContactsService.swift
// CardConnect
// Bug #136: CNMutableContact.note explicit set — notlar kaybolmasın.

import Contacts
import Foundation

actor DeviceContactsService {

    enum DeviceContactsError: Error {
        case permissionDenied
        case saveFailed(Error)
    }

    private let store = CNContactStore()

    // MARK: - Authorization

    func authorizationStatus() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    private func requireAuthorization() throws {
        guard authorizationStatus() == .authorized else {
            throw DeviceContactsError.permissionDenied
        }
    }

    // MARK: - Add (CNSaveRequest)

    /// Kişiyi rehbere ekler ve CNContact.identifier döner (deviceContactId olarak saklanır).
    @discardableResult
    func add(_ contact: Contact) throws -> String {
        try requireAuthorization()
        let cn = makeContact(from: contact)
        let request = CNSaveRequest()
        request.add(cn, toContainerWithIdentifier: nil)
        do {
            try store.execute(request)
        } catch {
            throw DeviceContactsError.saveFailed(error)
        }
        return cn.identifier
    }

    // MARK: - Update (stub — #104)

    /// TODO: #104 — mevcut CNContact'ı sil + yeniden ekle (CNContactStore güvenilir güncelleme yok).
    func update(_ contact: Contact) throws {
        // Implemented in #104
    }

    // MARK: - Delete (stub — #105)

    /// TODO: #105 — deviceContactId ile CNContact'ı bul ve sil.
    func delete(deviceContactId: String) throws {
        // Implemented in #105
    }

    // MARK: - CNMutableContact mapping

    private func makeContact(from contact: Contact) -> CNMutableContact {
        let cn = CNMutableContact()

        cn.givenName  = contact.firstName
        cn.familyName = contact.lastName
        cn.organizationName = contact.company
        cn.jobTitle   = contact.title

        cn.phoneNumbers = contact.phones.map {
            CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: $0))
        }

        cn.emailAddresses = contact.emails.map {
            CNLabeledValue(label: CNLabelWork, value: $0 as NSString)
        }

        if !contact.address.isEmpty {
            let postal = CNMutablePostalAddress()
            postal.street = contact.address
            cn.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: postal)]
        }

        if !contact.linkedin.isEmpty {
            cn.urlAddresses = [CNLabeledValue(label: "LinkedIn", value: contact.linkedin as NSString)]
        }

        // Bug #136: note alanı her zaman explicit set edilmeli — yoksa boş kalır.
        cn.note = contact.notes

        return cn
    }
}
