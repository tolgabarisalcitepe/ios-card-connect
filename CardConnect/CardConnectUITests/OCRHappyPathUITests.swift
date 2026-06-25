// OCRHappyPathUITests.swift
// CardConnect
// Mock OCR ile Confirm formu çıkarılan adı gösterir; kaydet → HomeView.

import XCTest

final class OCRHappyPathUITests: XCTestCase {

    private let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launchArguments = [
            "-onboarding_done", "1",
            "-UITestMockOCR"
        ]
        app.launch()
    }

    // MARK: - Tests

    func test_confirmForm_showsInjectedFirstName() {
        let saveButton = app.buttons["confirm_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "ConfirmView kaydet butonu görünmeli")

        let firstNameField = app.textFields["confirm_first_name_field"]
        XCTAssertTrue(firstNameField.waitForExistence(timeout: 3), "Ad alanı görünmeli")
        XCTAssertEqual(firstNameField.value as? String, "Test", "Mock OCR adı 'Test' olmalı")
    }

    func test_saveButton_enabledWhenFirstNamePresent() {
        let saveButton = app.buttons["confirm_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Kaydet butonu görünmeli")
        XCTAssertTrue(saveButton.isEnabled, "Ad dolu iken Kaydet aktif olmalı")
    }

    func test_save_navigatesBackToHome() {
        let saveButton = app.buttons["confirm_save_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Kaydet butonu görünmeli")
        saveButton.tap()

        let homeNavBar = app.navigationBars["Kişiler"]
        XCTAssertTrue(homeNavBar.waitForExistence(timeout: 5), "Kaydet sonrası HomeView görünmeli")
    }
}
