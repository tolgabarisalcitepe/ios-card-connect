// EventMatchUITests.swift
// CardConnect
// Epic 4 #146: etkinlik eşleştirme ekranı görünür; Atla → Home; izin red → Home otomatik.

import XCTest

final class EventMatchUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-onboarding_done", "1",
            "-UITestMockEventMatch"
        ]
        app.resetAuthorizationStatus(for: .calendar)
        app.launch()
    }

    // MARK: - Tests

    func test_eventMatchViewAppears() {
        addUIInterruptionMonitor(withDescription: "Calendar Permission") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }
        app.tap()
        XCTAssertTrue(
            app.otherElements["event_match_view"].waitForExistence(timeout: 5),
            "EventMatchView görünmeli"
        )
    }

    func test_skipButtonExists() {
        addUIInterruptionMonitor(withDescription: "Calendar Permission") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }
        app.tap()
        XCTAssertTrue(
            app.buttons["event_match_skip_button"].waitForExistence(timeout: 5),
            "Atla butonu görünmeli"
        )
    }

    func test_skipButton_navigatesToHome() {
        addUIInterruptionMonitor(withDescription: "Calendar Permission") { alert in
            alert.buttons.firstMatch.tap()
            return true
        }
        app.tap()
        let skipButton = app.buttons["event_match_skip_button"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 5), "Atla butonu görünmeli")
        skipButton.tap()
        XCTAssertTrue(
            app.navigationBars["Kişiler"].waitForExistence(timeout: 5),
            "Atla sonrası Home görünmeli"
        )
    }

    func test_permissionDenied_navigatesToHome() {
        addUIInterruptionMonitor(withDescription: "Calendar Permission") { alert in
            // iOS sürümüne göre "İzin Verme" veya "Don't Allow"
            for title in ["İzin Verme", "Don't Allow"] {
                let btn = alert.buttons[title]
                if btn.exists { btn.tap(); return true }
            }
            // Fallback: son buton genellikle "reddet"
            alert.buttons.element(boundBy: alert.buttons.count - 1).tap()
            return true
        }
        app.tap()
        XCTAssertTrue(
            app.navigationBars["Kişiler"].waitForExistence(timeout: 8),
            "İzin reddinde EventMatchView otomatik olarak Home'a dönmeli"
        )
    }
}
