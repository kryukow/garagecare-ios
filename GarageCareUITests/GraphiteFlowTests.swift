import XCTest

final class GraphiteFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false; executionTimeAllowance = 120 }
    func testHomeGalleryAndNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--graphite-preview"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Audi A6 Avant"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["РЕГЛАМЕНТ"].exists)
        XCTAssertFalse(app.staticTexts["БЛИЖАЙШИЕ РАБОТЫ"].exists)
        let layout = app.buttons["garage.layout.toggle"]
        reveal(layout, in: app)
        layout.tap()
        XCTAssertEqual(layout.label, "Показать списком")
        layout.tap()
        XCTAssertEqual(layout.label, "Показать плитками")
        // Return to the top before exercising the header and photo preference.
        scrollToTop(in: app)
        capture("Graphite-home")
        app.staticTexts["КОНТРОЛЬ АВТОМОБИЛЯ"].tap()
        XCTAssertTrue(app.buttons["garage.deadlines.edit"].waitForExistence(timeout: 5))
        capture("Graphite-control-expanded")
        let gallery = app.buttons["garage.iconGallery"]
        reveal(gallery, in: app)
        capture("Graphite-service-list")
        XCTAssertTrue(gallery.isHittable, "Gallery must be visible before tapping\n" + app.debugDescription)
        gallery.tap()
        XCTAssertTrue(app.textFields["maintenance.gallery.title"].waitForExistence(timeout: 5))
        capture("Graphite-icons")
        app.buttons["Закрыть"].tap()
        app.buttons["Настройки"].tap()
        XCTAssertTrue(app.navigationBars["Настройки"].waitForExistence(timeout: 5))
        capture("Graphite-settings")
        app.buttons["Светлая"].tap()
        app.buttons["Гараж"].tap()
        scrollToTop(in: app)
        capture("Graphite-light-home")
        app.buttons["Изменить автомобиль"].tap()
        let mode = app.segmentedControls["garage.hero.mode"]
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        mode.buttons["Фото"].tap()
        app.buttons["Готово"].tap()
        XCTAssertTrue(app.buttons["garage.hero.photo"].waitForExistence(timeout: 5))
        capture("Graphite-photo-home")
        app.buttons["Изменить автомобиль"].tap()
        app.segmentedControls["garage.hero.mode"].buttons["Анимация"].tap()
        app.buttons["Готово"].tap()
        XCTAssertFalse(app.buttons["garage.hero.photo"].exists)
    }
    private func scrollToTop(in app: XCUIApplication) {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<3 {
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.25))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.72)))
        }
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<7 {
            if element.isHittable { return }
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.70))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.25))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
