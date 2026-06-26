import Foundation

/// RFC 6350 vCard 3.0 üreticisi.
enum VCardExporter {

    /// Kullanıcının kendi profilinden vCard üretir.
    static func build(from profile: UserProfile) -> String {
        var lines: [String] = [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "N:\(profile.lastName);\(profile.firstName);;;",
            "FN:\(profile.fullName)",
        ]
        if !profile.company.isEmpty { lines.append("ORG:\(profile.company)") }
        if !profile.title.isEmpty   { lines.append("TITLE:\(profile.title)") }
        if !profile.phone.isEmpty   { lines.append("TEL;TYPE=VOICE:\(profile.phone)") }
        if !profile.email.isEmpty   { lines.append("EMAIL:\(profile.email)") }
        if !profile.linkedin.isEmpty { lines.append("URL:\(profile.linkedin)") }
        if !profile.website.isEmpty  { lines.append("URL:\(profile.website)") }
        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// RFC 6350 vCard 3.0 formatında string üretir.
    static func build(from contact: Contact) -> String {
        var lines: [String] = [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "N:\(contact.lastName);\(contact.firstName);;;",
            "FN:\(contact.fullName.isEmpty ? "\(contact.firstName) \(contact.lastName)".trimmingCharacters(in: .whitespaces) : contact.fullName)",
        ]

        if !contact.company.isEmpty  { lines.append("ORG:\(contact.company)") }
        if !contact.title.isEmpty    { lines.append("TITLE:\(contact.title)") }

        for phone in contact.phones where !phone.isEmpty {
            lines.append("TEL;TYPE=VOICE:\(phone)")
        }
        for email in contact.emails where !email.isEmpty {
            lines.append("EMAIL:\(email)")
        }

        if !contact.address.isEmpty {
            lines.append("ADR;TYPE=WORK:;;\(contact.address);;;;")
        }
        if !contact.linkedin.isEmpty, URLValidator.isValidLinkedIn(contact.linkedin) {
            lines.append("URL:\(contact.linkedin)")
        }
        if !contact.notes.isEmpty {
            lines.append("NOTE:\(contact.notes.replacingOccurrences(of: "\n", with: "\\n"))")
        }

        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// vCard içeriğini geçici .vcf dosyasına yazar ve URL döner.
    static func writeToTempFile(contact: Contact) throws -> URL {
        let content = build(from: contact)
        let name = contact.fullName.isEmpty ? "contact" : contact.fullName
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("vcf")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
