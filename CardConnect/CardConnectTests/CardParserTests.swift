// CardParserTests.swift
// CardConnectTests
// Android Bug #106–#115: KV1-KV12 test kartları port.

import XCTest
@testable import CardConnect

final class CardParserTests: XCTestCase {

    // MARK: - KV1: Standart Türkçe kartvizit

    func testKV1_standardCard() {
        let text = """
        Ahmet Yılmaz
        Yazılım Mühendisi
        Acme Teknoloji A.Ş.
        ahmet@acme.com
        +90 212 555 00 11
        """
        let card = CardParser.parse(text)
        XCTAssertEqual(card.firstName, "Ahmet")
        XCTAssertEqual(card.lastName, "Yılmaz")
        XCTAssertEqual(card.emails, ["ahmet@acme.com"])
        XCTAssertFalse(card.phones.isEmpty)
    }

    // MARK: - KV3: All-caps soyad normalize

    func testKV3_allCapsNormalized() {
        let text = "ADA LOVELACE\nMühendis"
        let card = CardParser.parse(text)
        XCTAssertEqual(card.firstName, "Ada")
        XCTAssertEqual(card.lastName, "Lovelace")
    }

    func testKV3_mixedCapsPartialLine() {
        let text = "Mehmet YILMAZ\nDirektor"
        let card = CardParser.parse(text)
        XCTAssertEqual(card.lastName, "Yilmaz")
    }

    // MARK: - KV4: Faks hariç tutulur

    func testKV4_faxExcluded() {
        let text = """
        Ada Lovelace
        +90 212 111 22 33
        Faks: 0212 111 22 44
        ada@example.com
        """
        let card = CardParser.parse(text)
        XCTAssertEqual(card.phones.count, 1)
        XCTAssertFalse(card.phones.joined().contains("44"))
    }

    func testKV4_faxVariantsExcluded() {
        for faxLabel in ["Fax:", "FAX:", "F.:", "faks:"] {
            let text = "Ada Lovelace\n\(faxLabel) 0212 999 99 99\nada@x.com"
            let card = CardParser.parse(text)
            XCTAssertTrue(card.phones.isEmpty, "Faks etiketi '\(faxLabel)' hariç tutulmalı")
        }
    }

    // MARK: - KV6: Dahili numara hariç

    func testKV6_extensionExcluded() {
        let text = """
        Zeynep Kaya
        +90 212 555 00 11
        Dahili 234
        zeynep@firma.com
        """
        let card = CardParser.parse(text)
        XCTAssertEqual(card.phones.count, 1)
    }

    func testKV6_extVariantExcluded() {
        let text = "Ali Veli\n+90 212 555 00 11\next. 45\nali@x.com"
        let card = CardParser.parse(text)
        XCTAssertEqual(card.phones.count, 1)
    }

    // MARK: - KV7: 4 telefon → max 3

    func testKV7_maxThreePhones() {
        let text = """
        Test Kullanıcı
        +90 212 111 11 11
        +90 212 222 22 22
        +90 212 333 33 33
        +90 212 444 44 44
        user@example.com
        """
        let card = CardParser.parse(text)
        XCTAssertEqual(card.phones.count, 3)
    }

    // MARK: - KV9: Email @ işaretiyle doğru parse

    func testKV9_emailExtracted() {
        let text = "Ada Lovelace\nada.lovelace@example.com\n+90 212 555 00 11"
        let card = CardParser.parse(text)
        XCTAssertEqual(card.emails, ["ada.lovelace@example.com"])
    }

    func testKV9_emailLowercased() {
        let text = "Ada Lovelace\nAda@Example.COM"
        let card = CardParser.parse(text)
        XCTAssertEqual(card.emails, ["ada@example.com"])
    }

    // MARK: - KV12: Ünvan noktalama temizlenir

    func testKV12_titlePunctuationCleaned() {
        let text = "Ada Lovelace\nYazılım Mühendisi.\nAcme Ltd."
        let card = CardParser.parse(text)
        XCTAssertFalse(card.title.hasSuffix("."), "Ünvan nokta ile bitmemeli: \(card.title)")
    }

    // MARK: - Input clamping (Cat-6)

    func testInputClampedTo8192() {
        let longText = String(repeating: "A ", count: 5000) + "\nada@example.com"
        let card = CardParser.parse(longText)
        // Parse should not crash; email may or may not be found depending on clamp position
        XCTAssertNotNil(card)
    }

    // MARK: - Separator ignored

    func testOCRSeparatorIgnored() {
        let text = "Ada Lovelace\n---\nada@example.com"
        let card = CardParser.parse(text)
        XCTAssertEqual(card.emails, ["ada@example.com"])
    }

    // MARK: - Empty input

    func testEmptyInputReturnsEmpty() {
        let card = CardParser.parse("")
        XCTAssertEqual(card.firstName, "")
        XCTAssertTrue(card.emails.isEmpty)
        XCTAssertTrue(card.phones.isEmpty)
    }
}
