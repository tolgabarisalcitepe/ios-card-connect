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

    // MARK: - Update

    /// Mevcut CNContact'ı fetch eder, tüm alanları günceller ve CNSaveRequest.update çalıştırır.
    func update(_ contact: Contact) throws {
        guard let deviceContactId = contact.deviceContactId, !deviceContactId.isEmpty else { return }
        try requireAuthorization()

        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
        ]

        let existing: CNContact
        do {
            existing = try store.unifiedContact(withIdentifier: deviceContactId, keysToFetch: keys)
        } catch {
            throw DeviceContactsError.saveFailed(error)
        }

        guard let mutable = existing.mutableCopy() as? CNMutableContact else { return }

        mutable.givenName        = contact.firstName
        mutable.familyName       = contact.lastName
        mutable.organizationName = contact.company
        mutable.jobTitle         = contact.title

        mutable.phoneNumbers = contact.phones.map {
            CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: $0))
        }
        mutable.emailAddresses = contact.emails.map {
            CNLabeledValue(label: CNLabelWork, value: $0 as NSString)
        }

        if !contact.address.isEmpty {
            let postal = CNMutablePostalAddress()
            postal.street = contact.address
            mutable.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: postal)]
        } else {
            mutable.postalAddresses = []
        }

        mutable.urlAddresses = contact.linkedin.isEmpty
            ? []
            : [CNLabeledValue(label: "LinkedIn", value: contact.linkedin as NSString)]

        // Bug #136: note alanı her zaman explicit set edilmeli.
        mutable.note = contact.notes

        let request = CNSaveRequest()
        request.update(mutable)
        do {
            try store.execute(request)
        } catch {
            throw DeviceContactsError.saveFailed(error)
        }
    }

    // MARK: - Delete

    /// Rehberdeki karşılığı siler; bulunamazsa no-op (idempotent).
    func delete(deviceContactId: String) throws {
        guard !deviceContactId.isEmpty else { return }
        try requireAuthorization()

        let keys: [CNKeyDescriptor] = [CNContactIdentifierKey as CNKeyDescriptor]
        let existing: CNContact
        do {
            existing = try store.unifiedContact(withIdentifier: deviceContactId, keysToFetch: keys)
        } catch {
            // Bulunamadı — idempotent, no-op.
            return
        }

        guard let mutable = existing.mutableCopy() as? CNMutableContact else { return }
        let request = CNSaveRequest()
        request.delete(mutable)
        do {
            try store.execute(request)
        } catch {
            throw DeviceContactsError.saveFailed(error)
        }
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
