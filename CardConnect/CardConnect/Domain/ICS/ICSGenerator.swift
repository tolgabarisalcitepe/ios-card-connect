// ICSGenerator.swift
// CardConnect

import Foundation

enum ICSGenerator {

    // MARK: - ICSEvent

    struct ICSEvent {
        let uid: String
        let summary: String
        let dtStart: Date
        let dtEnd: Date
        let location: String?
        let description: String?
        let organizerName: String
        let organizerEmail: String
        let attendeeEmail: String
    }

    // MARK: - Public API

    static func generate(_ event: ICSEvent) -> String {
        var lines: [String] = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//CardConnect//CardConnect//TR",
            "CALSCALE:GREGORIAN",
            "METHOD:REQUEST",
            "BEGIN:VEVENT",
            "UID:\(event.uid)",
            "DTSTAMP:\(utcString(Date()))",
            "DTSTART:\(utcString(event.dtStart))",
            "DTEND:\(utcString(event.dtEnd))",
            "SUMMARY:\(escapeText(event.summary))",
        ]
        if let location = event.location {
            lines.append("LOCATION:\(escapeText(location))")
        }
        if let description = event.description {
            lines.append("DESCRIPTION:\(escapeText(description))")
        }
        lines.append(contentsOf: [
            "ORGANIZER;CN=\"\(event.organizerName)\":mailto:\(event.organizerEmail)",
            "ATTENDEE;RSVP=TRUE:mailto:\(event.attendeeEmail)",
            "END:VEVENT",
            "END:VCALENDAR",
        ])
        return lines.map { fold($0) }.joined(separator: "\r\n") + "\r\n"
    }

    /// RFC 5545 §3.3.11 TEXT escaping.
    static func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\r\n", with: "\\n")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\n")
    }

    static func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = parts[0]
        let domain = parts[1]
        return !local.isEmpty && !domain.isEmpty && domain.contains(".")
    }

    // MARK: - Private

    private static func utcString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }

    /// RFC 5545 §3.1: fold physical lines to ≤ 75 octets (CRLF + SPACE for continuation).
    private static func fold(_ line: String) -> String {
        guard line.utf8.count > 75 else { return line }
        var result = ""
        var scalars = Array(line.unicodeScalars)
        var index = 0
        var isFirst = true

        while index < scalars.count {
            // Continuation lines start with a SPACE (1 octet), so their content limit is 74.
            let octetLimit = isFirst ? 75 : 74
            var chunk: [Unicode.Scalar] = []
            var octetCount = 0

            while index < scalars.count {
                let s = scalars[index]
                let size = String(s).utf8.count
                guard octetCount + size <= octetLimit else { break }
                chunk.append(s)
                octetCount += size
                index += 1
            }

            let chunkStr = String(String.UnicodeScalarView(chunk))
            if isFirst {
                result += chunkStr
            } else {
                result += "\r\n " + chunkStr
            }
            isFirst = false
        }

        return result
    }
}
