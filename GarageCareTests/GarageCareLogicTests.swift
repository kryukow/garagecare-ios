import XCTest
@testable import GarageCare

final class GarageCareLogicTests: XCTestCase {
    func testMaintenanceWithoutIntervalIsNotConfigured() {
        let task = MaintenanceTask(
            vehicleID: UUID(),
            title: "Масло",
            lastMileage: 100_000,
            lastDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(
            task.state(
                currentMileage: 101_000,
                currentEngineHours: 0,
                warningKm: 1_000,
                warningEngineHours: 10,
                now: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            .notConfigured
        )
    }

    func testMaintenanceMileageTransitions() {
        let task = MaintenanceTask(
            vehicleID: UUID(),
            title: "Масло",
            intervalKm: 10_000,
            lastMileage: 100_000,
            lastDate: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(
            task.state(
                currentMileage: 105_000,
                currentEngineHours: 0,
                warningKm: 1_000,
                warningEngineHours: 10,
                now: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            .good
        )

        XCTAssertEqual(
            task.state(
                currentMileage: 109_000,
                currentEngineHours: 0,
                warningKm: 1_000,
                warningEngineHours: 10,
                now: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            .soon
        )

        XCTAssertEqual(
            task.state(
                currentMileage: 110_001,
                currentEngineHours: 0,
                warningKm: 1_000,
                warningEngineHours: 10,
                now: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            .overdue
        )
    }

    func testMaintenanceEngineHoursTransitions() {
        let task = MaintenanceTask(
            vehicleID: UUID(),
            title: "Масло",
            intervalEngineHours: 100,
            lastMileage: 100_000,
            lastEngineHours: 500
        )

        XCTAssertEqual(
            task.state(
                currentMileage: 100_000,
                currentEngineHours: 550,
                warningKm: 1_000,
                warningEngineHours: 10
            ),
            .good
        )

        XCTAssertEqual(
            task.state(
                currentMileage: 100_000,
                currentEngineHours: 590,
                warningKm: 1_000,
                warningEngineHours: 10
            ),
            .soon
        )

        XCTAssertEqual(
            task.state(
                currentMileage: 100_000,
                currentEngineHours: 601,
                warningKm: 1_000,
                warningEngineHours: 10
            ),
            .overdue
        )
    }

    func testFuelConsumptionNeedsTwoFullTankAnchors() {
        let vehicleID = UUID()
        let entries = [
            FuelEntry(vehicleID: vehicleID, mileage: 1000, liters: 30, amount: 50, isFullTank: true)
        ]

        XCTAssertTrue(FuelStatisticsCalculator.consumptionPoints(entries: entries).isEmpty)
        XCTAssertNil(FuelStatisticsCalculator.averageConsumption(entries: entries))
    }

    func testFuelConsumptionIncludesPartialTopUps() {
        let vehicleID = UUID()
        let entries = [
            FuelEntry(vehicleID: vehicleID, mileage: 1000, liters: 35, amount: 50, isFullTank: true),
            FuelEntry(vehicleID: vehicleID, mileage: 1200, liters: 10, amount: 15, isFullTank: false),
            FuelEntry(vehicleID: vehicleID, mileage: 1500, liters: 30, amount: 45, isFullTank: true)
        ]

        let points = FuelStatisticsCalculator.consumptionPoints(entries: entries)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].distance, 500)
        XCTAssertEqual(points[0].liters, 40, accuracy: 0.0001)
        XCTAssertEqual(points[0].consumption, 8.0, accuracy: 0.0001)
        let average = FuelStatisticsCalculator.averageConsumption(entries: entries)
        XCTAssertNotNil(average)
        XCTAssertEqual(average!, 8.0, accuracy: 0.0001)
    }

    func testAverageFuelConsumptionIsDistanceWeighted() {
        let vehicleID = UUID()
        let entries = [
            FuelEntry(vehicleID: vehicleID, mileage: 1000, liters: 35, amount: 50, isFullTank: true),
            FuelEntry(vehicleID: vehicleID, mileage: 1500, liters: 40, amount: 60, isFullTank: true),
            FuelEntry(vehicleID: vehicleID, mileage: 1600, liters: 12, amount: 18, isFullTank: true)
        ]

        let average = FuelStatisticsCalculator.averageConsumption(entries: entries)

        XCTAssertNotNil(average)
        XCTAssertEqual(average!, 52.0 / 600.0 * 100.0, accuracy: 0.0001)
        XCTAssertNotEqual(average!, 10.0, accuracy: 0.0001)
    }

    func testEntriesBeforeFirstFullTankDoNotCorruptConsumption() {
        let vehicleID = UUID()
        let entries = [
            FuelEntry(vehicleID: vehicleID, mileage: 900, liters: 8, amount: 12, isFullTank: false),
            FuelEntry(vehicleID: vehicleID, mileage: 1000, liters: 20, amount: 30, isFullTank: true),
            FuelEntry(vehicleID: vehicleID, mileage: 1400, liters: 32, amount: 48, isFullTank: true)
        ]

        let average = FuelStatisticsCalculator.averageConsumption(entries: entries)
        XCTAssertNotNil(average)
        XCTAssertEqual(average!, 8.0, accuracy: 0.0001)
    }

    func testBackupVersionOneWithoutFuelEntriesStillDecodes() throws {
        let json = """
        {
          "version": 1,
          "exportedAt": "2026-01-01T12:00:00Z",
          "vehicles": [],
          "tasks": [],
          "records": [],
          "mileageEntries": []
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: json)

        XCTAssertEqual(payload.version, 1)
        XCTAssertNil(payload.fuelEntries)
    }

    func testFuelSpendStaysSeparatedByCurrency() {
        let vehicleID = UUID()
        let entries = [
            FuelEntry(vehicleID: vehicleID, mileage: 1000, liters: 20, amount: 30, currency: "EUR"),
            FuelEntry(vehicleID: vehicleID, mileage: 1200, liters: 20, amount: 40, currency: "EUR"),
            FuelEntry(vehicleID: vehicleID, mileage: 1400, liters: 20, amount: 5_000, currency: "RUB")
        ]

        let totals = FuelStatisticsCalculator.spendByCurrency(entries: entries)

        XCTAssertEqual(totals["EUR"] ?? -1, 70, accuracy: 0.0001)
        XCTAssertEqual(totals["RUB"] ?? -1, 5_000, accuracy: 0.0001)
        XCTAssertEqual(totals.count, 2)
    }

    func testCSVExportContainsServiceFuelAndEscapesNotes() {
        let vehicle = Vehicle(
            make: "Example",
            model: "Car",
            year: 2010,
            currentMileage: 150_000
        )
        let record = ServiceRecord(
            vehicleID: vehicle.id,
            title: "Масло; фильтр",
            mileage: 149_500,
            cost: 75.5,
            currency: "EUR",
            notes: "Synthetic oil \"5W-40\""
        )
        let fuel = FuelEntry(
            vehicleID: vehicle.id,
            mileage: 150_000,
            liters: 35.2,
            amount: 30,
            currency: "EUR",
            isFullTank: true,
            notes: "АЗС"
        )

        let csv = HistoryCSVExporter.makeCSV(
            vehicles: [vehicle],
            records: [record],
            fuelEntries: [fuel]
        )

        XCTAssertTrue(csv.contains("ТО;Example Car"))
        XCTAssertTrue(csv.contains("Заправка;Example Car"))
        XCTAssertTrue(csv.contains("\"Масло; фильтр\""))
        XCTAssertTrue(csv.contains("\"Synthetic oil \"\"5W-40\"\"\""))
    }
}
