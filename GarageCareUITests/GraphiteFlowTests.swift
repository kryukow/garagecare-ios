import XCTest

final class GraphiteFlowTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
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
        app.swipeUp()
        let gallery = app.buttons["garage.iconGallery"]
        if !gallery.isHittable { app.swipeUp() }
        XCTAssertTrue(gallery.waitForExistence(timeout: 5))
        gallery.tap()
        XCTAssertTrue(app.textFields["maintenance.gallery.title"].waitForExistence(timeout: 5))
        capture("Graphite-icons")
        app.buttons["Закрыть"].tap()
        app.buttons["Настройки"].tap()
        XCTAssertTrue(app.staticTexts["Оформление"].waitForExistence(timeout: 5))
        capture("Graphite-settings")
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }
}
