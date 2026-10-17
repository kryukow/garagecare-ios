import SwiftData
import UIKit
import XCTest
@testable import GarageCare

final class GarageCare142Tests: XCTestCase {
    func testInputRejectsSilentChangesAndAcceptsRussianDecimals() {
        for text in ["-100", "10.5", "1x2", "999999999999999999999999"] {
            XCTAssertNil(MaintenanceInput.integer(text), text)
        }
        for text in ["-1", "nan", "inf", "2..5", "1e9"] {
            XCTAssertNil(MaintenanceInput.decimal(text), text)
        }
        XCTAssertEqual(MaintenanceInput.integer(" 10000 "), 10_000)
        XCTAssertEqual(MaintenanceInput.decimal("250,5"), 250.5)
        XCTAssertEqual(MaintenanceInput.decimal("", emptyValue: 0), 0)
        XCTAssertNil(MaintenanceInput.decimal(""))
    }

    func testKilometerCounterResetsAfterCompletionWithoutCalendar() {
        let task = MaintenanceTask(vehicleID: UUID(), title: "Масло", intervalKm: 10_000, lastMileage: 100_000)
        XCTAssertNil(task.nextDate())
        XCTAssertEqual(task.nextMileage(), 110_000)
        XCTAssertEqual(task.kilometersRemaining(currentMileage: 104_000), 6_000)
        task.lastMileage = 104_000
        XCTAssertEqual(task.nextMileage(), 114_000)
        XCTAssertEqual(task.kilometersRemaining(currentMileage: 104_000), 10_000)
    }

    @MainActor
    func testSeparateWorkPhotoAndReceiptPersistAndRoundTripJSON() throws {
        let schema = Schema([Vehicle.self, MaintenanceTask.self, ServiceRecord.self, MileageEntry.self, FuelEntry.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        let vehicle = Vehicle(make: "Test", model: "Car", year: 2020, currentMileage: 100_000)
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
            UIColor.green.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }.jpegData(compressionQuality: 0.8)!
        let receipt = UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }.pngData()!
        context.insert(vehicle)
        context.insert(ServiceRecord(vehicleID: vehicle.id, title: "Масло", mileage: 100_000,
                                     receiptImageData: receipt, imageData: photo))
        try context.save()
        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<ServiceRecord>()).first)
        XCTAssertEqual(saved.imageData, photo)
        XCTAssertEqual(saved.receiptImageData, receipt)
        let encoded = try JSONEncoder().encode(RecordSnapshot(saved))
        let decoded = try JSONDecoder().decode(RecordSnapshot.self, from: encoded)
        XCTAssertEqual(decoded.imageData, photo)
        XCTAssertEqual(decoded.receiptImageData, receipt)
        // A 1.4.1 backup has no work-photo key; its receipt must still decode.
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        old.removeValue(forKey: "imageData")
        let legacy = try JSONDecoder().decode(RecordSnapshot.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertNil(legacy.imageData)
        XCTAssertEqual(legacy.receiptImageData, receipt)
        let pdf = ServicePDFExporter.makePDF(vehicles: [vehicle], records: [saved])
        XCTAssertTrue(pdf.starts(with: Data("%PDF".utf8)))
    }
}
