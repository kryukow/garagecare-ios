import Foundation
import UIKit
import XCTest
@testable import GarageCare

final class MaintenanceIconTests: XCTestCase {
    func testEveryPartHasOriginalArtwork() {
        for icon in MaintenanceIcons.catalog {
            let image = UIImage(named: "Maintenance-" + icon.id)
            XCTAssertNotNil(image, icon.id)
            XCTAssertGreaterThan(image?.size.width ?? 0, 20, icon.id)
        }
    }

    func testSpecificPartWinsOverGenericKeyword() {
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Замена масляного фильтра"), "oilFilter")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Воздушный фильтр"), "airFilter")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Фильтр салонный"), "cabinFilter")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Газовый фильтр LPG"), "lpgFilter")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Тормозная жидкость"), "brakeFluid")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Тормозные диски"), "brakeDiscs")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Свечи зажигания"), "spark")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Катушки зажигания"), "ignition")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Цепь ГРМ"), "timingChain")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Ремень ГРМ"), "belt")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Стойки амортизатора"), "shock")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Дворники"), "wiper")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Резина летняя"), "wheel")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Замена масла"), "oil")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Произвольная работа"), "other")
    }

    func testGermanAndEnglishMatching() {
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Ölfilter wechseln"), "oilFilter")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Air filter"), "airFilter")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Zündkerzen"), "spark")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Steuerkette"), "timingChain")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Brake pads"), "brakePads")
        XCTAssertEqual(MaintenanceIcons.suggested(for: "Radlager"), "bearing")
    }

    func testManualChoiceSurvivesTitleChanges() {
        XCTAssertEqual(MaintenanceIcons.resolved(title: "Масло", manualKey: "spark"), "spark")
        XCTAssertEqual(MaintenanceIcons.resolved(title: "Масло", manualKey: nil), "oil")
        XCTAssertEqual(MaintenanceIcons.resolved(title: "Масло", manualKey: "missing-key"), "oil")
        XCTAssertEqual(Set(MaintenanceIcons.catalog.map(\.id)).count, MaintenanceIcons.catalog.count)
    }

    func testAllLegacyKeysResolveToSupportedCategories() {
        XCTAssertEqual(MaintenanceIcons.catalog.count, 33)
        XCTAssertEqual(MaintenanceIcons.categories.count, 12)
        XCTAssertEqual(Set(MaintenanceIcons.categories.map(\.id)).count, 12)
        XCTAssertEqual(Set(MaintenanceIcons.categories.map(\.symbolName)).count, 12)
        for item in MaintenanceIcons.catalog {
            let category = MaintenanceIcons.category(for: item.id)
            XCTAssertTrue(
                MaintenanceIcons.categories.contains(where: { $0.id == category.id }),
                "No category for \(item.id)"
            )
        }
    }

    func testSFNamesAreAvailableOnSupportedIOS() {
        for category in MaintenanceIcons.categories {
            XCTAssertNotNil(
                UIImage(systemName: category.symbolName),
                "SF Symbol \(category.symbolName) is missing on iOS \(UIDevice.current.systemVersion)"
            )
        }
    }

    func testManualLegacyIconAndNewCategoriesPreserveOverrides() {
        XCTAssertEqual(MaintenanceIcons.categoryID(for: "oilFilter"), "filters")
        XCTAssertEqual(MaintenanceIcons.categoryID(for: "lpgFilter"), "filters")
        XCTAssertEqual(MaintenanceIcons.categoryID(for: "spark"), "electrical")
        XCTAssertEqual(MaintenanceIcons.categoryID(for: "brakeDiscs"), "brakes")
        XCTAssertEqual(MaintenanceIcons.categoryID(for: "timingChain"), "transmission")
        XCTAssertEqual(MaintenanceIcons.categoryID(for: "coolant"), "fluids")
        XCTAssertEqual(MaintenanceIcons.categoryID(for: "lpg"), "fuel")
        XCTAssertEqual(MaintenanceIcons.categoryID(for: "unrecognized"), "other")
        for category in MaintenanceIcons.categories {
            XCTAssertNotNil(MaintenanceIcons.descriptor(for: category.representativeKey))
            XCTAssertEqual(
                MaintenanceIcons.categoryID(for: category.representativeKey),
                category.id
            )
        }
        XCTAssertEqual(MaintenanceIcons.resolved(title: "Масло", manualKey: "spark"), "spark")
    }

    func testIconKeySurvivesJSONAndOlderBackupsRemainReadable() throws {
        let original = MaintenanceTask(
            vehicleID: UUID(), title: "Масло", intervalKm: 10000,
            lastMileage: 160000, iconKey: "spark"
        )
        let encoder = JSONEncoder()
        let snapshot = TaskSnapshot(original)
        let encoded = try encoder.encode(snapshot)
        let decoded = try JSONDecoder().decode(TaskSnapshot.self, from: encoded)
        XCTAssertEqual(decoded.iconKey, "spark")

        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        old.removeValue(forKey: "iconKey")
        let oldEncoded = try JSONSerialization.data(withJSONObject: old)
        let oldDecoded = try JSONDecoder().decode(TaskSnapshot.self, from: oldEncoded)
        XCTAssertNil(oldDecoded.iconKey)
    }
}
