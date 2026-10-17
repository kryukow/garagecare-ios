import XCTest

final class MaintenanceFormTests: XCTestCase {
    func testNewWorkUsesKilometerCounterAndOptionalConditions() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        let interval = app.textFields["maintenance.intervalKm"]
        XCTAssertTrue(interval.waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["Например, 24"].exists)
        XCTAssertFalse(app.textFields["Например, 250"].exists)
        app.textFields["Название"].tap()
        app.textFields["Название"].typeText("Масло")
        interval.tap()
        interval.typeText("10000")
        if app.buttons["Готово"].exists { app.buttons["Готово"].tap() }
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Следующая работа при")).firstMatch.exists)
        XCTAssertTrue(app.buttons["Сохранить"].isEnabled)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "1.4.2 — интервал в километрах"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testCompletionOffersSeparateWorkPhotoAndReceipt() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--completion", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Работа выполнена"].waitForExistence(timeout: 10))
        for _ in 0..<3 {
            if app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Прикрепить фото")).count >= 2 { break }
            app.swipeUp()
        }
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Прикрепить фото")).count, 2)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "1.4.2 — фото работы и чек"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
