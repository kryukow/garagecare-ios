import XCTest
@testable import GarageCare

final class GarageCare143Tests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testCountdownAndExpiry() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertEqual(GarageDeadline.days(to: date(2026, 11, 17),
                         now: date(2026, 10, 17), calendar: calendar), 31)
        XCTAssertEqual(GarageDeadline.days(to: date(2026, 10, 15),
                         now: date(2026, 10, 17), calendar: calendar), -2)
        XCTAssertTrue(GarageDeadline.countdown(to: date(2026, 10, 17),
                           now: date(2026, 10, 17), calendar: calendar).contains("Сегодня"))
    }

    func testInsurancePeriodAndManualPaymentRule() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let dateOfDebit = date(2026, 10, 17)
        XCTAssertEqual(GarageDeadline.nextDebit(after: dateOfDebit, months: 1, calendar: calendar),
                       date(2026, 11, 17))
        XCTAssertEqual(GarageDeadline.nextDebit(after: dateOfDebit, months: 12, calendar: calendar),
                       date(2027, 10, 17))
        XCTAssertNil(GarageDeadline.nextDebit(after: dateOfDebit, months: 0, calendar: calendar))
    }

    func testPhotoArchiveRetainsFirstImageAndMultipleExtraImages() {
        let originals = ["old image", "new photo 1", "receipt 2"].map { Data($0.utf8) }
        var primary: Data?
        var additional: Data?
        GaragePhotoArchive.store(originals, primary: &primary, additional: &additional)
        XCTAssertEqual(primary, originals[0])
        XCTAssertNotNil(additional)
        XCTAssertEqual(GaragePhotoArchive.images(primary: primary, additional: additional), originals)
        GaragePhotoArchive.store([], primary: &primary, additional: &additional)
        XCTAssertNil(primary)
        XCTAssertNil(additional)
    }

    func testOldVehicleStartsWithNoImaginaryDeadlines() {
        let vehicle = Vehicle(make: "Example", model: "Car", year: 2020, currentMileage: 1000)
        XCTAssertNil(vehicle.huDueDate)
        XCTAssertNil(vehicle.insuranceNextDebitDate)
        XCTAssertEqual(vehicle.insurancePeriodMonths, 12)
    }

    func testNewVehicleBackupSnapshotRoundTrips() throws {
        let vehicle = Vehicle(
            make: "Example", model: "Car", year: 2020, currentMileage: 1500,
            huStartDate: date(2026, 1, 1), huDueDate: date(2028, 1, 1),
            insuranceNextDebitDate: date(2026, 11, 1),
            insurancePeriodMonths: 3, insuranceCost: 123.45, insuranceCurrency: "EUR"
        )
        let snap = VehicleSnapshot(vehicle)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let copied = try decoder.decode(VehicleSnapshot.self, from: encoder.encode(snap))
        XCTAssertEqual(copied.huDueDate, vehicle.huDueDate)
        XCTAssertEqual(copied.insuranceNextDebitDate, vehicle.insuranceNextDebitDate)
        XCTAssertEqual(copied.insurancePeriodMonths, 3)
        XCTAssertEqual(copied.insuranceCost, 123.45)
    }
}
