// ScanFlowActorTests.swift
// CardConnectTests

import XCTest
@testable import CardConnect

final class ScanFlowActorTests: XCTestCase {

    private var actor: ScanFlowActor!

    override func setUp() async throws {
        actor = ScanFlowActor()
    }

    // MARK: - Initial state

    func testInitialStateIsEmpty() async {
        let paths = await actor.photoPaths
        let card = await actor.parsedCard
        let id = await actor.contactID
        let vcard = await actor.incomingVCard

        XCTAssertTrue(paths.isEmpty)
        XCTAssertNil(card)
        XCTAssertNil(id)
        XCTAssertNil(vcard)
    }

    // MARK: - Mutations

    func testAddPhoto() async {
        let url = URL(fileURLWithPath: "/tmp/photo.jpg")
        await actor.addPhoto(url)
        let paths = await actor.photoPaths
        XCTAssertEqual(paths, [url])
    }

    func testSetPhotoPaths() async {
        let urls = [URL(fileURLWithPath: "/tmp/a.jpg"), URL(fileURLWithPath: "/tmp/b.jpg")]
        await actor.setPhotoPaths(urls)
        let paths = await actor.photoPaths
        XCTAssertEqual(paths, urls)
    }

    func testSetParsedCard() async {
        var card = ParsedCard()
        card.firstName = "Ada"
        card.lastName = "Lovelace"
        await actor.setParsedCard(card)
        let stored = await actor.parsedCard
        XCTAssertEqual(stored?.firstName, "Ada")
    }

    func testSetContactID() async {
        let id = UUID()
        await actor.setContactID(id)
        let stored = await actor.contactID
        XCTAssertEqual(stored, id)
    }

    func testSetIncomingVCard() async {
        await actor.setIncomingVCard("BEGIN:VCARD\nEND:VCARD")
        let stored = await actor.incomingVCard
        XCTAssertEqual(stored, "BEGIN:VCARD\nEND:VCARD")
    }

    // MARK: - Reset (Android Cat-2 önlemi)

    func testResetClearsAllState() async {
        await actor.addPhoto(URL(fileURLWithPath: "/tmp/photo.jpg"))
        await actor.setContactID(UUID())
        await actor.setIncomingVCard("BEGIN:VCARD\nEND:VCARD")

        await actor.reset()

        let paths = await actor.photoPaths
        let id = await actor.contactID
        let vcard = await actor.incomingVCard
        let card = await actor.parsedCard

        XCTAssertTrue(paths.isEmpty)
        XCTAssertNil(id)
        XCTAssertNil(vcard)
        XCTAssertNil(card)
    }

    // MARK: - Concurrency (Android Cat-1 önlemi)

    func testConcurrentWritesDoNotDataRace() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    await self.actor.addPhoto(URL(fileURLWithPath: "/tmp/\(i).jpg"))
                }
            }
        }
        let count = await actor.photoPaths.count
        XCTAssertEqual(count, 50)
    }
}
