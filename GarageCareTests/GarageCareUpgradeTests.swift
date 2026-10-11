import Foundation
import XCTest
@testable import GarageCare

final class GarageCareUpgradeTests: XCTestCase {
    func testEngineHoursDeadline() {
        let vehicleID = UUID()
        let task = MaintenanceTask(vehicleID: vehicleID, title: "Масло",
                                   intervalEngineHours: 200, lastEngineHours: 100,
                                   lastMileage: 50_000)
        XCTAssertEqual(task.state(currentMileage: 50_000, warningKm: 500,
                                  warningDays: 7, currentEngineHours: 210), .good)
        XCTAssertEqual(task.state(currentMileage: 50_000, warningKm: 500,
                                  warningDays: 7, currentEngineHours: 290), .soon)
        XCTAssertEqual(task.state(currentMileage: 50_000, warningKm: 500,
                                  warningDays: 7, currentEngineHours: 301), .overdue)
        XCTAssertEqual(task.engineHoursRemaining(currentEngineHours: 290) ?? -1, 10, accuracy: 0.0001)
    }

    func testDifferentFuelTypesNeverCombineIntoOneConsumptionInterval() {
        let id = UUID()
        let entries = [
            FuelEntry(vehicleID: id, mileage: 1000, liters: 35, amount: 25, isFullTank: true, fuelType: "LPG"),
            FuelEntry(vehicleID: id, mileage: 1200, liters: 15, amount: 25, isFullTank: false, fuelType: "LPG"),
            FuelEntry(vehicleID: id, mileage: 1300, liters: 30, amount: 50, isFullTank: true, fuelType: "Бензин"),
            FuelEntry(vehicleID: id, mileage: 1500, liters: 32, amount: 55, isFullTank: true, fuelType: "Бензин")
        ]
        let points = FuelStatisticsCalculator.consumptionPoints(entries: entries)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].fuelType, "Бензин")
        XCTAssertEqual(points[0].distance, 200)
        XCTAssertNil(FuelStatisticsCalculator.averageConsumption(entries: entries))
    }

    func testVersionThreeBackupKeepsReceiptsPartsAndLPG() throws {
        let vehicle = Vehicle(make: "Example", model: "Sample", year: 2010,
                              currentMileage: 150_000, engineHours: 320)
        let task = MaintenanceTask(vehicleID: vehicle.id, title: "ТО",
                                   intervalEngineHours: 200, lastEngineHours: 310,
                                   lastMileage: 149_000)
        let record = ServiceRecord(vehicleID: vehicle.id, taskID: task.id, title: "Масло",
                                   mileage: 149_000, cost: 60, parts: "Oil filter",
                                   receiptImageData: Data([1,2,3]))
        let fuel = FuelEntry(vehicleID: vehicle.id, mileage: 150_000,
                             liters: 35, amount: 27, fuelType: "LPG")
        let snapshot = BackupPayload(version: 3, exportedAt: .now,
            vehicles: [VehicleSnapshot(vehicle)],
            tasks: [TaskSnapshot(task)],
            records: [RecordSnapshot(record)],
            mileageEntries: [],
            fuelEntries: [FuelSnapshot(fuel)])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode(BackupPayload.self, from: data)
        try BackupValidator.validate(restored)
        XCTAssertEqual(restored.vehicles.first?.engineHours, 320)
        XCTAssertEqual(restored.tasks.first?.intervalEngineHours, 200)
        XCTAssertEqual(restored.records.first?.parts, "Oil filter")
        XCTAssertEqual(restored.records.first?.receiptImageData, Data([1,2,3]))
        XCTAssertEqual(restored.fuelEntries?.first?.fuelType, "LPG")
    }

    func testCorruptForeignReferenceIsRejectedBeforeRestore() {
        let vehicle = Vehicle(make: "Example", model: "Sample", year: 2010,
                              currentMileage: 10)
        let foreign = MaintenanceTask(vehicleID: UUID(), title: "Foreign",
                                      lastMileage: 0)
        let payload = BackupPayload(version: 3, exportedAt: .now,
            vehicles: [VehicleSnapshot(vehicle)],
            tasks: [TaskSnapshot(foreign)], records: [],
            mileageEntries: [], fuelEntries: [])
        XCTAssertThrowsError(try BackupValidator.validate(payload))
    }

    func testEmptyLegacyBackupStillValid() throws {
        let json = """
        {"version":1,"exportedAt":"2026-01-01T00:00:00Z",
         "vehicles":[],"tasks":[],"records":[],"mileageEntries":[]}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: json)
        XCTAssertNoThrow(try BackupValidator.validate(payload))
    }

    func testPDFHasValidHeader() {
        let pdf = ServicePDFExporter.makePDF(vehicles: [], records: [])
        XCTAssertTrue(pdf.starts(with: Data("%PDF".utf8)))
    }
}
