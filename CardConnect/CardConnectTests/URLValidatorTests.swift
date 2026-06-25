// URLValidatorTests.swift
// CardConnectTests
// Android Cat-4: domain whitelist, parse anında kontrol.

import XCTest
@testable import CardConnect

final class URLValidatorTests: XCTestCase {

    // MARK: - Valid

    func testValidLinkedIn() {
        XCTAssertTrue(URLValidator.isValidLinkedIn("https://linkedin.com/in/ada"))
    }

    func testValidLinkedInWWW() {
        XCTAssertTrue(URLValidator.isValidLinkedIn("https://www.linkedin.com/in/ada"))
    }

    func testValidLinkedInWithPath() {
        XCTAssertTrue(URLValidator.isValidLinkedIn("https://linkedin.com/company/acme"))
    }

    // MARK: - Invalid scheme

    func testHttpRejected() {
        XCTAssertFalse(URLValidator.isValidLinkedIn("http://linkedin.com/in/ada"))
    }

    func testIntentSchemeRejected() {
        XCTAssertFalse(URLValidator.isValidLinkedIn("intent://linkedin.com/in/ada"))
    }

    func testNoSchemeRejected() {
        XCTAssertFalse(URLValidator.isValidLinkedIn("linkedin.com/in/ada"))
    }

    // MARK: - Invalid domain (Cat-4 evil.com variants)

    func testEvilDomainRejected() {
        XCTAssertFalse(URLValidator.isValidLinkedIn("https://evil.com/linkedin"))
    }

    func testEvilDomainWithLinkedInInPath() {
        XCTAssertFalse(URLValidator.isValidLinkedIn("https://evil.com/in/linkedin.com"))
    }

    func testSubdomainSpoofRejected() {
        XCTAssertFalse(URLValidator.isValidLinkedIn("https://linkedin.com.evil.com/in/ada"))
    }

    func testEmptyStringRejected() {
        XCTAssertFalse(URLValidator.isValidLinkedIn(""))
    }
}
