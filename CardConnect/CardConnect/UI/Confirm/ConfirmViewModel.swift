// ConfirmViewModel.swift
// CardConnect

import Foundation

enum ConfirmViewModel {

    static func buildContact(
        firstName: String,
        lastName: String,
        company: String,
        title: String,
        phones: [String],
        emails: [String],
        linkedin: String,
        notes: String,
        source: ContactSource,
        photoPaths: [String]
    ) -> Contact {
        Contact(
            source: source,
            status: .new,
            firstName: String(firstName.trimmingCharacters(in: .whitespaces).prefix(FieldLimits.maxName)),
            lastName: String(lastName.trimmingCharacters(in: .whitespaces).prefix(FieldLimits.maxName)),
            company: String(company.trimmingCharacters(in: .whitespaces).prefix(FieldLimits.maxCompany)),
            title: String(title.trimmingCharacters(in: .whitespaces).prefix(FieldLimits.maxTitle)),
            phones: phones.map { String($0.prefix(FieldLimits.maxPhone)) },
            emails: emails.map { String($0.lowercased().prefix(FieldLimits.maxEmail)) },
            address: "",
            notes: String(notes.prefix(FieldLimits.maxNotes)),
            linkedin: linkedin,
            photoPaths: photoPaths
        )
    }
}
