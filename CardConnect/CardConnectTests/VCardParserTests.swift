// VCardParserTests.swift
// CardConnectTests
// Android Cat-9: tek impl, iki kaynak aynı sonuç. Cat-6: tooLarge. Cat-4: URL validate.

import XCTest
@testable import CardConnect

final class VCardParserTests: XCTestCase {

    // MARK: - Basic parse

    func testBasicVCard() throws {
        let vcard = """
        BEGIN:VCARD
        VERSION:3.0
        FN:Ada Lovelace
        TEL;TYPE=WORK:+90 212 555 00 11
        EMAIL:ada@example.com
        ORG:Acme Ltd.
        TITLE:Yazılım Mühendisi
        END:VCARD
        """
        let card = try VCardParser.parse(.string(vcard))
        XCTAssertEqual(card.firstName, "Ada")
        XCTAssertEqual(card.lastName, "Lovelace")
        XCTAssertEqual(card.emails, ["ada@example.com"])
        XCTAssertFalse(card.phones.isEmpty)
        XCTAssertEqual(card.company, "Acme Ltd.")
        XCTAssertEqual(card.title, "Yazılım Mühendisi")
    }

    func testStructuredName() throws {
        let vcard = """
        BEGIN:VCARD
        VERSION:3.0
        N:Lovelace;Ada;;;
        FN:Ada Lovelace
        END:VCARD
        """
        let card = try VCardParser.parse(.string(vcard))
        XCTAssertEqual(card.firstName, "Ada")
        XCTAssertEqual(card.lastName, "Lovelace")
    }

    // MARK: - RFC 6350 unfold (Cat-9)

    func testUnfoldRemovesCRLFSpace() {
        let folded = "FN:Ada \r\n Lovelace"
        let unfolded = VCardParser.unfold(folded)
        XCTAssertEqual(unfolded, "FN:Ada Lovelace")
    }

    func testUnfoldRemovesLFTab() {
        let folded = "FN:Ada\n\tLovelace"
        let unfolded = VCardParser.unfold(folded)
        XCTAssertEqual(unfolded, "FN:AdaLovelace")
    }

    func testFoldedVCardParsedCorrectly() throws {
        let folded = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Ada \r\n Lovelace\r\nEMAIL:ada@x.com\r\nEND:VCARD"
        let card = try VCardParser.parse(.string(folded))
        XCTAssertTrue(card.firstName.contains("Ada"))
        XCTAssertEqual(card.emails, ["ada@x.com"])
    }

    // MARK: - File source (Cat-9: iki kaynak aynı sonuç)

    func testFileSourceMatchesStringSource() throws {
        let vcard = """
        BEGIN:VCARD
        VERSION:3.0
        FN:Test Kullanıcı
        EMAIL:test@example.com
        END:VCARD
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test.vcf")
        try vcard.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let fromString = try VCardParser.parse(.string(vcard))
        let fromFile   = try VCardParser.parse(.file(url))

        XCTAssertEqual(fromString.firstName, fromFile.firstName)
        XCTAssertEqual(fromString.emails, fromFile.emails)
    }

    // MARK: - Too large (Cat-6)

    func testFileTooLargeThrows() throws {
        let bigData = Data(repeating: UInt8(ascii: "A"), count: FieldLimits.maxVCard + 1)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("big.vcf")
        try bigData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try VCardParser.parse(.file(url))) { error in
            XCTAssertEqual(error as? VCardParser.VCardError, .tooLarge)
        }
    }

    func testFileExactLimitAccepted() throws {
        let exactData = Data(repeating: UInt8(ascii: "A"), count: FieldLimits.maxVCard)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("exact.vcf")
        try exactData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertNoThrow(try VCardParser.parse(.file(url)))
    }

    // MARK: - LinkedIn URL validation (Cat-4)

    func testValidLinkedInStored() throws {
        let vcard = """
        BEGIN:VCARD
        VERSION:3.0
        FN:Ada Lovelace
        URL:https://linkedin.com/in/ada
        END:VCARD
        """
        let card = try VCardParser.parse(.string(vcard))
        XCTAssertEqual(card.linkedin, "https://linkedin.com/in/ada")
    }

    func testInvalidLinkedInRejected() throws {
        let vcard = """
        BEGIN:VCARD
        VERSION:3.0
        FN:Ada Lovelace
        URL:https://evil.com/linkedin
        END:VCARD
        """
        let card = try VCardParser.parse(.string(vcard))
        XCTAssertEqual(card.linkedin, "")
    }

    func testHttpLinkedInRejected() throws {
        let vcard = """
        BEGIN:VCARD
        VERSION:3.0
        FN:Ada Lovelace
        URL:http://linkedin.com/in/ada
        END:VCARD
        """
        let card = try VCardParser.parse(.string(vcard))
        XCTAssertEqual(card.linkedin, "")
    }

    // MARK: - Email lowercased

    func testEmailLowercased() throws {
        let vcard = "BEGIN:VCARD\nFN:Test\nEMAIL:Ada@Example.COM\nEND:VCARD"
        let card = try VCardParser.parse(.string(vcard))
        XCTAssertEqual(card.emails, ["ada@example.com"])
    }

    // MARK: - Max 3 phones

    func testMaxThreePhones() throws {
        let vcard = """
        BEGIN:VCARD
        VERSION:3.0
        FN:Test Kullanıcı
        TEL:+1111111111
        TEL:+2222222222
        TEL:+3333333333
        TEL:+4444444444
        END:VCARD
        """
        let card = try VCardParser.parse(.string(vcard))
        XCTAssertEqual(card.phones.count, 3)
    }
}
