import XCTest
@testable import CardConnect

final class ContactMergeTests: XCTestCase {

    // MARK: - Helpers

    private func makeContact(
        id: UUID = UUID(),
        firstName: String = "",
        lastName: String = "",
        company: String = "",
        phones: [String] = [],
        emails: [String] = [],
        photoPaths: [String] = [],
        notes: String = "",
        linkedin: String = "",
        address: String = "",
        title: String = "",
        eventId: String? = nil,
        eventName: String? = nil,
        deviceContactId: String? = nil
    ) -> Contact {
        let c = Contact(
            source: "businessCard",
            status: "active",
            firstName: firstName,
            lastName: lastName,
            company: company,
            title: title,
            phones: phones,
            emails: emails,
            address: address,
            notes: notes,
            linkedin: linkedin,
            photoPaths: photoPaths
        )
        c.id = id
        c.eventId = eventId
        c.eventName = eventName
        c.deviceContactId = deviceContactId
        return c
    }

    // MARK: - findDuplicate

    func test_findDuplicate_nameAndCompanyMatch_returnsCandidate() {
        let incoming = makeContact(firstName: "Ali", lastName: "Yılmaz", company: "Acme")
        let candidate = makeContact(firstName: "Ali", lastName: "Yılmaz", company: "Acme")
        XCTAssertEqual(DuplicateDetector.findDuplicate(incoming: incoming, in: [candidate])?.id, candidate.id)
    }

    func test_findDuplicate_nameMatchCaseInsensitive_returnsCandidate() {
        let incoming = makeContact(firstName: "ali", lastName: "yılmaz", company: "acme")
        let candidate = makeContact(firstName: "ALİ", lastName: "YILMAZ", company: "ACME")
        XCTAssertEqual(DuplicateDetector.findDuplicate(incoming: incoming, in: [candidate])?.id, candidate.id)
    }

    func test_findDuplicate_phoneMatch_returnsCandidate() {
        let incoming = makeContact(phones: ["+905551234567"])
        let candidate = makeContact(phones: ["+905551234567"])
        XCTAssertEqual(DuplicateDetector.findDuplicate(incoming: incoming, in: [candidate])?.id, candidate.id)
    }

    func test_findDuplicate_phoneMatchNormalized_returnsCandidate() {
        let incoming = makeContact(phones: ["+90 555 123 45 67"])
        let candidate = makeContact(phones: ["90-555-123-45-67"])
        XCTAssertEqual(DuplicateDetector.findDuplicate(incoming: incoming, in: [candidate])?.id, candidate.id)
    }

    func test_findDuplicate_emailMatch_returnsCandidate() {
        let incoming = makeContact(emails: ["ali@example.com"])
        let candidate = makeContact(emails: ["ali@example.com"])
        XCTAssertEqual(DuplicateDetector.findDuplicate(incoming: incoming, in: [candidate])?.id, candidate.id)
    }

    func test_findDuplicate_emailMatchCaseInsensitive_returnsCandidate() {
        let incoming = makeContact(emails: ["Ali@Example.COM"])
        let candidate = makeContact(emails: ["ali@example.com"])
        XCTAssertEqual(DuplicateDetector.findDuplicate(incoming: incoming, in: [candidate])?.id, candidate.id)
    }

    func test_findDuplicate_selfExclude_returnsNil() {
        let sharedID = UUID()
        let incoming = makeContact(id: sharedID, firstName: "Ali", lastName: "Yılmaz", company: "Acme")
        let same = makeContact(id: sharedID, firstName: "Ali", lastName: "Yılmaz", company: "Acme")
        XCTAssertNil(DuplicateDetector.findDuplicate(incoming: incoming, in: [same]))
    }

    func test_findDuplicate_emptyName_doesNotMatchByName() {
        let incoming = makeContact(firstName: "", lastName: "", company: "Acme")
        let candidate = makeContact(firstName: "", lastName: "", company: "Acme")
        XCTAssertNil(DuplicateDetector.findDuplicate(incoming: incoming, in: [candidate]))
    }

    func test_findDuplicate_emptyPhones_doesNotMatchByPhone() {
        let incoming = makeContact(phones: [])
        let candidate = makeContact(phones: [])
        XCTAssertNil(DuplicateDetector.findDuplicate(incoming: incoming, in: [candidate]))
    }

    func test_findDuplicate_emptyCandidates_returnsNil() {
        let incoming = makeContact(firstName: "Ali", lastName: "Yılmaz", company: "Acme")
        XCTAssertNil(DuplicateDetector.findDuplicate(incoming: incoming, in: []))
    }

    func test_findDuplicate_noMatch_returnsNil() {
        let incoming = makeContact(firstName: "Ali", lastName: "Yılmaz", company: "Acme", phones: ["111"], emails: ["a@a.com"])
        let candidate = makeContact(firstName: "Veli", lastName: "Kaya", company: "Beta", phones: ["222"], emails: ["b@b.com"])
        XCTAssertNil(DuplicateDetector.findDuplicate(incoming: incoming, in: [candidate]))
    }

    // MARK: - merge

    func test_merge_existingNonEmptyFieldPreserved() {
        let existing = makeContact(firstName: "Ali", company: "Acme")
        let incoming = makeContact(firstName: "Veli", company: "Beta")
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.firstName, "Ali")
        XCTAssertEqual(result.company, "Acme")
    }

    func test_merge_existingEmptyField_incomingUsed() {
        let existing = makeContact(firstName: "Ali", lastName: "")
        let incoming = makeContact(firstName: "Ali", lastName: "Yılmaz")
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.lastName, "Yılmaz")
    }

    func test_merge_phonesUnionDistinct() {
        let existing = makeContact(phones: ["111", "222"])
        let incoming = makeContact(phones: ["222", "333"])
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.phones, ["111", "222", "333"])
    }

    func test_merge_emailsUnionDistinct() {
        let existing = makeContact(emails: ["a@a.com", "b@b.com"])
        let incoming = makeContact(emails: ["b@b.com", "c@c.com"])
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.emails, ["a@a.com", "b@b.com", "c@c.com"])
    }

    func test_merge_photoPathsUnionDistinct() {
        let existing = makeContact(photoPaths: ["/img/1.jpg", "/img/2.jpg"])
        let incoming = makeContact(photoPaths: ["/img/2.jpg", "/img/3.jpg"])
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.photoPaths, ["/img/1.jpg", "/img/2.jpg", "/img/3.jpg"])
    }

    func test_merge_notesConcat_newNotesAppended() {
        let existing = makeContact(notes: "Eski not")
        let incoming = makeContact(notes: "Yeni not")
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.notes, "Eski not\nYeni not")
    }

    func test_merge_notesDistinct_duplicateNotAdded() {
        let existing = makeContact(notes: "Ortak not")
        let incoming = makeContact(notes: "Ortak not")
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.notes, "Ortak not")
    }

    func test_merge_existingNotesEmpty_incomingUsed() {
        let existing = makeContact(notes: "")
        let incoming = makeContact(notes: "Yeni not")
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.notes, "Yeni not")
    }

    func test_merge_idPreserved() {
        let existingID = UUID()
        let existing = makeContact(id: existingID)
        let incoming = makeContact()
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.id, existingID)
    }

    func test_merge_createdAtPreserved() {
        let oldDate = Date(timeIntervalSinceNow: -86400)
        let existing = makeContact()
        existing.createdAt = oldDate
        let incoming = makeContact()
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.createdAt, oldDate)
    }

    func test_merge_updatedAtRefreshed() {
        let before = Date()
        let existing = makeContact()
        let incoming = makeContact()
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertGreaterThanOrEqual(result.updatedAt, before)
    }

    func test_merge_optionalFields_existingNilUsesIncoming() {
        let existing = makeContact(eventId: nil, eventName: nil, deviceContactId: nil)
        let incoming = makeContact(eventId: "evt1", eventName: "Toplantı", deviceContactId: "dev1")
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.eventId, "evt1")
        XCTAssertEqual(result.eventName, "Toplantı")
        XCTAssertEqual(result.deviceContactId, "dev1")
    }

    func test_merge_optionalFields_existingNonNilPreserved() {
        let existing = makeContact(eventId: "orig", eventName: "Orijinal", deviceContactId: "origDev")
        let incoming = makeContact(eventId: "new", eventName: "Yeni", deviceContactId: "newDev")
        let result = DuplicateDetector.merge(existing: existing, incoming: incoming)
        XCTAssertEqual(result.eventId, "orig")
        XCTAssertEqual(result.eventName, "Orijinal")
        XCTAssertEqual(result.deviceContactId, "origDev")
    }
}
