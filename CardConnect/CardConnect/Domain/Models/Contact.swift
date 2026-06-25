// Contact.swift
// CardConnect

import Foundation
import SwiftData

@Model
final class Contact {
    @Attribute(.unique) var id: UUID
    var source: String          // ContactSource.rawValue
    var status: String          // ContactStatus.rawValue
    var firstName: String
    var lastName: String
    var company: String
    var title: String
    var phones: [String]
    var emails: [String]
    var address: String
    var notes: String
    var linkedin: String
    var photoPaths: [String]
    var eventId: String?
    var eventName: String?
    var deviceContactId: String?
    var createdAt: Date
    var updatedAt: Date

    var fullName: String {
        [firstName, lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    init(
        id: UUID = UUID(),
        source: ContactSource = .manual,
        status: ContactStatus = .new,
        firstName: String = "",
        lastName: String = "",
        company: String = "",
        title: String = "",
        phones: [String] = [],
        emails: [String] = [],
        address: String = "",
        notes: String = "",
        linkedin: String = "",
        photoPaths: [String] = [],
        eventId: String? = nil,
        eventName: String? = nil,
        deviceContactId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.source = source.rawValue
        self.status = status.rawValue
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.title = title
        self.phones = phones
        self.emails = emails
        self.address = address
        self.notes = notes
        self.linkedin = linkedin
        self.photoPaths = photoPaths
        self.eventId = eventId
        self.eventName = eventName
        self.deviceContactId = deviceContactId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
