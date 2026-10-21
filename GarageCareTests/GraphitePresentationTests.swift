import XCTest
import SwiftUI
import SwiftData
import UIKit
@testable import GarageCare

final class GraphitePresentationTests: XCTestCase {
    @MainActor
    func testRoadPausesResumesAndDetaches() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIViewController()
        window.rootViewController = host
        window.makeKeyAndVisible()
        let road = GarageRoadSurface(frame: CGRect(x: 0, y: 0, width: 350, height: 130))
        host.view.addSubview(road)
        road.moving = true
        XCTAssertTrue(road.isAnimating)
        road.moving = false
        XCTAssertFalse(road.isAnimating)
        road.moving = true
        XCTAssertTrue(road.isAnimating)
        road.removeFromSuperview()
        XCTAssertFalse(road.isAnimating)
        window.isHidden = true
    }

    @MainActor
    func testGraphiteScreensAtCompactAndRegularWidths() throws {
        let schema = Schema([Vehicle.self, MaintenanceTask.self, ServiceRecord.self, MileageEntry.self, FuelEntry.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let car = Vehicle(make: "Audi", model: "A6 Avant", year: 2018, currentMileage: 148200)
        car.huDueDate = Calendar.current.date(byAdding: .month, value: 8, to: .now)
        car.insuranceNextDebitDate = Calendar.current.date(byAdding: .month, value: 2, to: .now)
        container.mainContext.insert(car)
        for (title, interval) in [("Воздушный фильтр", 15000), ("Тормозные колодки", 40000), ("Масло и фильтр", 10000)] {
            container.mainContext.insert(MaintenanceTask(vehicleID: car.id, title: title, intervalKm: interval, lastMileage: 140000))
        }
        try container.mainContext.save()
        for width in [320.0, 390.0] {
            let controller = UIHostingController(rootView: RootView().modelContainer(container).preferredColorScheme(.dark))
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 844))
            window.overrideUserInterfaceStyle = .dark
            window.rootViewController = controller
            window.makeKeyAndVisible()
            controller.view.frame = window.bounds
            controller.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            let attachment = XCTAttachment(image: image)
            attachment.name = "Graphite-home-\(Int(width))"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertEqual(controller.view.bounds.width, width)
            window.isHidden = true
        }
    }
}
