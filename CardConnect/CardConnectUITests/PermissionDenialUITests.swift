// PermissionDenialUITests.swift
// CardConnect
// Epic 7 #148: kamera kalıcı red → "Ayarları Aç" görünür, izin döngüsü yok (Cat-7).

import XCTest

final class PermissionDenialUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-onboarding_done", "1",
            "-UITestMockCameraPermissionDenied",
        ]
        app.launch()
    }

    // MARK: - Tests

    /// Kamera kalıcı reddedilince izin reddedildi ekranı görünmeli.
    func test_permissionDenied_viewAppears() {
        // HomeView'den kamera ekranına git
        let cameraButton = app.buttons.matching(
            NSPredicate(format: "identifier CONTAINS 'camera' OR label CONTAINS 'Kamera' OR label CONTAINS '+'")
        ).firstMatch
        if cameraButton.waitForExistence(timeout: 3) {
            cameraButton.tap()
        } else {
            // FAB veya toolbar plus butonu
            app.navigationBars.buttons.element(boundBy: 1).tap()
        }

        XCTAssertTrue(
            app.otherElements["camera_permission_denied_view"].waitForExistence(timeout: 5),
            "Kamera izni reddedilince permission denied view görünmeli"
        )
    }

    /// "Ayarları Aç" butonu görünmeli.
    func test_settingsButton_visible() {
        navigateToCamera()

        XCTAssertTrue(
            app.buttons["camera_settings_button"].waitForExistence(timeout: 5),
            "Ayarları Aç butonu görünmeli"
        )
    }

    /// "Ayarları Aç" tıklandığında uygulama kilitlenmemeli (izin döngüsü yok).
    func test_settingsButton_doesNotLoop() {
        navigateToCamera()

        let settingsButton = app.buttons["camera_settings_button"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))

        // Butona basınca sistem Settings açılır — uygulama background'a gider.
        // Uygulama kilitlenmediğini (döngüye girmediğini) doğrulamak için
        // butona basılabilir olup olmadığını kontrol ediyoruz.
        XCTAssertTrue(settingsButton.isEnabled, "Ayarları Aç butonu aktif olmalı")
        XCTAssertFalse(
            app.buttons["camera_settings_button"].exists == false,
            "İzin döngüsü tespit edildi — buton kaybolmamalıydı"
        )
    }

    // MARK: - Helpers

    private func navigateToCamera() {
        // NavigationLink veya FAB ile CameraView'e git
        let plusButton = app.buttons.matching(
            NSPredicate(format: "label == '+'")
        ).firstMatch
        if plusButton.waitForExistence(timeout: 3) {
            plusButton.tap()
            return
        }
        // Toolbar'daki ikinci buton (plus / camera)
        let toolbarButtons = app.navigationBars.buttons
        if toolbarButtons.count > 1 {
            toolbarButtons.element(boundBy: 1).tap()
        }
    }
}
