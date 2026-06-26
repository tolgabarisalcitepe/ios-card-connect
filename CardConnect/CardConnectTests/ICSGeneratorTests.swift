// ICSGeneratorTests.swift
// CardConnectTests
// RFC 5545: UTC format, 75-octet line fold, TEXT escaping, e-posta validasyon.

import XCTest
@testable import CardConnect

final class ICSGeneratorTests: XCTestCase {

    // MARK: - Helpers

    /// 2026-06-26T10:00:00Z (sabit UTC)
    private let fixedStart: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 26
        comps.hour = 10; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: comps)!
    }()

    private var fixedEnd: Date { fixedStart.addingTimeInterval(3600) } // +1 saat

    private func makeEvent(
        uid: String = "test-uid@cardconnect",
        summary: String = "Test Toplantı",
        location: String? = nil,
        description: String? = nil,
        organizerName: String = "Test Host",
        organizerEmail: String = "host@example.com",
        attendeeEmail: String = "guest@example.com"
    ) -> ICSGenerator.ICSEvent {
        ICSGenerator.ICSEvent(
            uid: uid,
            summary: summary,
            dtStart: fixedStart,
            dtEnd: fixedEnd,
            location: location,
            description: description,
            organizerName: organizerName,
            organizerEmail: organizerEmail,
            attendeeEmail: attendeeEmail
        )
    }

    // MARK: - VCALENDAR structure

    func test_vcalendar_beginsCorrectly() {
        let ics = ICSGenerator.generate(makeEvent())
        XCTAssertTrue(ics.hasPrefix("BEGIN:VCALENDAR\r\n"), "BEGIN:VCALENDAR ile başlamalı")
    }

    func test_vcalendar_endsCorrectly() {
        let ics = ICSGenerator.generate(makeEvent())
        XCTAssertTrue(ics.hasSuffix("END:VCALENDAR\r\n"), "END:VCALENDAR ile bitmeli")
    }

    func test_vevent_present() {
        let ics = ICSGenerator.generate(makeEvent())
        XCTAssertTrue(ics.contains("BEGIN:VEVENT\r\n"), "BEGIN:VEVENT olmalı")
        XCTAssertTrue(ics.contains("END:VEVENT\r\n"), "END:VEVENT olmalı")
    }

    func test_uid_present() {
        let ics = ICSGenerator.generate(makeEvent())
        XCTAssertTrue(ics.contains("UID:test-uid@cardconnect"), "UID property olmalı")
    }

    // MARK: - UTC date format

    func test_dtstart_utcFormat() {
        let ics = ICSGenerator.generate(makeEvent())
        XCTAssertTrue(ics.contains("DTSTART:20260626T100000Z"), "DTSTART UTC formatında olmalı")
    }

    func test_dtend_utcFormat() {
        let ics = ICSGenerator.generate(makeEvent())
        XCTAssertTrue(ics.contains("DTEND:20260626T110000Z"), "DTEND UTC formatında olmalı")
    }

    // MARK: - CRLF line endings

    func test_crlfLineEndings() {
        let ics = ICSGenerator.generate(makeEvent())
        XCTAssertTrue(ics.contains("\r\n"), "Satır sonu CRLF olmalı")
    }

    func test_noBareLF() {
        let ics = ICSGenerator.generate(makeEvent())
        // CRLF split sonrası kalan parçalarda bare \n olmamalı
        let bare = ics.components(separatedBy: "\r\n").dropLast().contains { $0.contains("\n") }
        XCTAssertFalse(bare, "CRLF dışında bare LF bulunmamalı")
    }

    // MARK: - 75-octet line folding

    func test_lineFolding_noLineExceeds75Octets() {
        let longSummary = String(repeating: "A", count: 80) // SUMMARY: + 80 = 88 > 75
        let ics = ICSGenerator.generate(makeEvent(summary: longSummary))
        XCTAssertTrue(ics.contains("\r\n "), "Uzun satır fold edilmeli (CRLF + SPACE)")
        let lines = ics.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        for line in lines {
            XCTAssertLessThanOrEqual(
                line.utf8.count, 75,
                "Fold sonrası satır 75 oktet'i geçmemeli: '\(line.prefix(80))'"
            )
        }
    }

    func test_lineFolding_shortLineNotFolded() {
        let ics = ICSGenerator.generate(makeEvent(summary: "Kısa"))
        let summaryLines = ics.components(separatedBy: "\r\n").filter { $0.hasPrefix("SUMMARY:") }
        XCTAssertEqual(summaryLines.count, 1, "Kısa SUMMARY tek satır olmalı")
    }

    // MARK: - TEXT escaping (RFC 5545 §3.3.11)

    func test_escapeText_comma() {
        XCTAssertEqual(ICSGenerator.escapeText("a,b"), "a\\,b")
    }

    func test_escapeText_semicolon() {
        XCTAssertEqual(ICSGenerator.escapeText("a;b"), "a\\;b")
    }

    func test_escapeText_backslash() {
        XCTAssertEqual(ICSGenerator.escapeText("a\\b"), "a\\\\b")
    }

    func test_escapeText_newline() {
        XCTAssertEqual(ICSGenerator.escapeText("a\nb"), "a\\nb")
    }

    func test_escapeText_combined() {
        XCTAssertEqual(ICSGenerator.escapeText("a,b;c\\d\ne"), "a\\,b\\;c\\\\d\\ne")
    }

    func test_escapeText_plain_noChange() {
        XCTAssertEqual(ICSGenerator.escapeText("Hello World"), "Hello World")
    }

    func test_summaryEscaped_inOutput() {
        let ics = ICSGenerator.generate(makeEvent(summary: "Toplantı, Önemli; Acil"))
        XCTAssertFalse(
            ics.contains("SUMMARY:Toplantı, Önemli; Acil\r\n"),
            "Escape edilmemiş virgül/noktalı virgül olmamalı"
        )
        XCTAssertTrue(ics.contains("\\,"), "Virgül escape edilmeli")
        XCTAssertTrue(ics.contains("\\;"), "Noktalı virgül escape edilmeli")
    }

    // MARK: - ORGANIZER / ATTENDEE

    func test_organizer_containsMailto() {
        let ics = ICSGenerator.generate(makeEvent())
        XCTAssertTrue(ics.contains("ORGANIZER"), "ORGANIZER property olmalı")
        XCTAssertTrue(ics.contains("mailto:host@example.com"), "ORGANIZER mailto olmalı")
    }

    func test_attendee_containsMailto() {
        let ics = ICSGenerator.generate(makeEvent())
        XCTAssertTrue(ics.contains("ATTENDEE"), "ATTENDEE property olmalı")
        XCTAssertTrue(ics.contains("mailto:guest@example.com"), "ATTENDEE mailto olmalı")
    }

    // MARK: - Email validation

    func test_validEmail_simple()     { XCTAssertTrue(ICSGenerator.isValidEmail("user@example.com")) }
    func test_validEmail_plus()       { XCTAssertTrue(ICSGenerator.isValidEmail("user+tag@example.com")) }
    func test_validEmail_subdomain()  { XCTAssertTrue(ICSGenerator.isValidEmail("user@mail.example.com")) }

    func test_invalidEmail_noAt()     { XCTAssertFalse(ICSGenerator.isValidEmail("userexample.com")) }
    func test_invalidEmail_noDomain() { XCTAssertFalse(ICSGenerator.isValidEmail("user@")) }
    func test_invalidEmail_noLocal()  { XCTAssertFalse(ICSGenerator.isValidEmail("@example.com")) }
    func test_invalidEmail_empty()    { XCTAssertFalse(ICSGenerator.isValidEmail("")) }

    // MARK: - Optional fields

    func test_location_whenPresent() {
        let ics = ICSGenerator.generate(makeEvent(location: "İstanbul Ofis"))
        XCTAssertTrue(ics.contains("LOCATION:"), "LOCATION olmalı")
    }

    func test_location_whenNil() {
        let ics = ICSGenerator.generate(makeEvent(location: nil))
        XCTAssertFalse(ics.contains("LOCATION:"), "location nil iken LOCATION olmamalı")
    }

    func test_description_whenPresent() {
        let ics = ICSGenerator.generate(makeEvent(description: "Gündem: Proje değerlendirme"))
        XCTAssertTrue(ics.contains("DESCRIPTION:"), "DESCRIPTION olmalı")
    }

    func test_description_whenNil() {
        let ics = ICSGenerator.generate(makeEvent(description: nil))
        XCTAssertFalse(ics.contains("DESCRIPTION:"), "description nil iken DESCRIPTION olmamalı")
    }
}
