// DuplicateMergeUITests.swift
// CardConnect
// Bug #138: duplikat ekranı görünür; merge → geri; yeni kayıt → geri.

import XCTest

final class DuplicateMergeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-onboarding_done", "1",
            "-UITestMockDuplicate"
        ]
        app.launch()
    }

    // MARK: - Tests

    func test_duplicateViewAppears() {
        XCTAssertTrue(
            app.otherElements["duplicate_view"].waitForExistence(timeout: 5),
            "DuplicateView görünmeli"
        )
    }

    func test_mergeButtonExists() {
        XCTAssertTrue(
            app.buttons["duplicate_merge_button"].waitForExistence(timeout: 5),
            "Merge butonu görünmeli"
        )
    }

    func test_newContactButtonExists() {
        XCTAssertTrue(
            app.buttons["duplicate_new_button"].waitForExistence(timeout: 5),
            "Yeni kayıt butonu görünmeli"
        )
    }
}
