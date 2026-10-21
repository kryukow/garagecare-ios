import XCTest

final class GraphiteFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false; executionTimeAllowance = 120 }
    func testHomeGalleryAndNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--graphite-preview"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Audi A6 Avant"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["КОНТРОЛЬ АВТОМОБИЛЯ"].exists)
        capture("Graphite-home")
        app.staticTexts["КОНТРОЛЬ АВТОМОБИЛЯ"].tap()
        XCTAssertTrue(app.buttons["garage.deadlines.edit"].waitForExistence(timeout: 5))
        capture("Graphite-control-expanded")
        let gallery = app.buttons["garage.iconGallery"]
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<5 {
            if gallery.isHittable { break }
            // Stay above the fixed navigation: an app-wide swipe starts on its buttons.
            let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.70))
            let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.25))
            start.press(forDuration: 0.1, thenDragTo: end)
        }
        capture("Graphite-service-list")
        XCTAssertTrue(gallery.isHittable, "Gallery must be visible before tapping\n" + app.debugDescription)
        gallery.tap()
        XCTAssertTrue(app.textFields["maintenance.gallery.title"].waitForExistence(timeout: 5))
        capture("Graphite-icons")
        app.buttons["Закрыть"].tap()
        app.buttons["Настройки"].tap()
        XCTAssertTrue(app.navigationBars["Настройки"].waitForExistence(timeout: 5))
        capture("Graphite-settings")
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
