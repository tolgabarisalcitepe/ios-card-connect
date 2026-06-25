import XCTest

final class OnboardingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-privacy_accepted", "false", "-UITesting", "true"]
        app.launch()
    }

    // KVKK onaylanmadan İleri butonu disabled olmalı
    func test_kvkkGate_nextButtonDisabledWithoutAcceptance() {
        navigateToPrivacyStep()
        let nextButton = app.buttons["onboarding_next_button"]
        XCTAssertTrue(nextButton.waitForExistence(timeout: 3))
        XCTAssertFalse(nextButton.isEnabled, "İleri butonu KVKK onaylanmadan aktif olmamalı")
    }

    // KVKK onaylandıktan sonra İleri butonu aktif olmalı
    func test_kvkkGate_nextButtonEnabledAfterAcceptance() {
        navigateToPrivacyStep()
        let toggle = app.switches["onboarding_kvkk_toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.tap()
        let nextButton = app.buttons["onboarding_next_button"]
        XCTAssertTrue(nextButton.isEnabled, "KVKK onaylandıktan sonra İleri aktif olmalı")
    }

    // Step 3'teki "Şimdi Değil" → Home ekranına gitmeli
    func test_skipOnStep3_navigatesToHome() {
        navigateToStep3()
        let skipButton = app.buttons["onboarding_skip_button"]
        XCTAssertTrue(skipButton.waitForExistence(timeout: 3))
        skipButton.tap()
        XCTAssertTrue(
            app.navigationBars.firstMatch.waitForExistence(timeout: 3),
            "Home ekranı görünmeli"
        )
    }

    // MARK: - Helpers

    private func navigateToPrivacyStep() {
        app.buttons["İleri"].tap()   // step 0 → 1
        app.buttons["İleri"].tap()   // step 1 → 2
    }

    private func navigateToStep3() {
        navigateToPrivacyStep()
        let toggle = app.switches["onboarding_kvkk_toggle"]
        if toggle.waitForExistence(timeout: 2) { toggle.tap() }
        app.buttons["onboarding_next_button"].tap()  // step 2 → 3
    }
}
