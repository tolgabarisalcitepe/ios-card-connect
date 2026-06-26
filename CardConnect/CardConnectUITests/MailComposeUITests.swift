// MailComposeUITests.swift
// CardConnect
// Epic 5 #147: şablon seçimi; boş eventName→[Etkinlik] kaldırma; gönder akışı.

import XCTest

final class MailComposeUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-onboarding_done", "1",
            "-UITestMockMailCompose",
        ]
        app.launch()
    }

    // MARK: - Tests

    func test_mailComposeViewAppears() {
        XCTAssertTrue(
            app.otherElements["mail_compose_view"].waitForExistence(timeout: 5),
            "MailComposeView görünmeli"
        )
    }

    func test_templateChipsAppear() {
        XCTAssertTrue(
            app.otherElements["mail_compose_view"].waitForExistence(timeout: 5)
        )
        // En az bir şablon chip butonu görünmeli (seeded şablonlardan en az biri)
        let tanismaChip = app.buttons["template_chip_Tanışma"]
        XCTAssertTrue(
            tanismaChip.waitForExistence(timeout: 5),
            "Tanışma şablon chip'i görünmeli"
        )
    }

    func test_chipSelection_changesPreview() {
        XCTAssertTrue(
            app.otherElements["mail_compose_view"].waitForExistence(timeout: 5)
        )
        // İkinci şablona geç
        let takipChip = app.buttons["template_chip_Takip"]
        if takipChip.waitForExistence(timeout: 5) {
            takipChip.tap()
        }
        // Preview alanı güncellenmeli
        XCTAssertTrue(
            app.staticTexts.element(matching: NSPredicate(
                format: "label CONTAINS %@", "Merhaba"
            )).waitForExistence(timeout: 3),
            "Preview içeriği güncellenmeli"
        )
    }

    func test_emptyEventName_noLeftoverToken() {
        // Contact'ta eventName nil — [Etkinlik] içeren satır body'den kaldırılmalı
        XCTAssertTrue(
            app.otherElements["mail_compose_view"].waitForExistence(timeout: 5)
        )
        // İlk şablon otomatik seçilir; preview yüklenene kadar bekle
        _ = app.staticTexts["mail_resolved_body"].waitForExistence(timeout: 5)

        // Hiçbir ekranda "[Etkinlik]" tokeni kalmamalı
        let leftover = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "[Etkinlik]")
        )
        XCTAssertEqual(
            leftover.count, 0,
            "eventName boşken [Etkinlik] tokeni ekranda kalmamalı"
        )
    }

    func test_sendButton_exists() {
        XCTAssertTrue(
            app.otherElements["mail_compose_view"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            app.buttons["Gönder"].waitForExistence(timeout: 5),
            "Gönder butonu görünmeli"
        )
    }

    func test_sendButton_enabled_afterTemplateSelect() {
        XCTAssertTrue(
            app.otherElements["mail_compose_view"].waitForExistence(timeout: 5)
        )
        // Şablon otomatik seçilir → Gönder aktif olmalı
        let sendButton = app.buttons["Gönder"]
        XCTAssertTrue(sendButton.waitForExistence(timeout: 5))
        XCTAssertTrue(sendButton.isEnabled, "Şablon seçiliyken Gönder aktif olmalı")
    }
}
