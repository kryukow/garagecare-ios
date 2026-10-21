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

}
