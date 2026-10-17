import Foundation
import XCTest
@testable import GarageCare

final class GarageCareSortingTests: XCTestCase {
    func testUrgencySortPlacesOverdueBeforeSoonAndFarTasks() {
        let vehicleID = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let overdue = MaintenanceTask(vehicleID: vehicleID, title: "Просрочено",
                                      intervalKm: 500, lastMileage: 1000,
                                      lastDate: now)
        let soon = MaintenanceTask(vehicleID: vehicleID, title: "Скоро",
                                   intervalKm: 1100, lastMileage: 1000,
                                   lastDate: now)
        let far = MaintenanceTask(vehicleID: vehicleID, title: "Позже",
                                  intervalKm: 10000, lastMileage: 1000,
                                  lastDate: now)
        let noInterval = MaintenanceTask(vehicleID: vehicleID, title: "Не задано",
                                         lastMileage: 1000, lastDate: now)

        let sorted = TaskListSorter.sorted(
            [far, noInterval, soon, overdue],
            mode: .urgency,
            mileage: 2020,
            engineHours: 0,
            warningKm: 100,
            warningDays: 7,
            now: now
        )
        XCTAssertEqual(sorted.map(\.id), [overdue.id, soon.id, far.id, noInterval.id])
    }

    func testCalendarSortUsesActualDueDatesAndListsUndatedWorkLast() {
        let vehicleID = UUID()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let far = MaintenanceTask(vehicleID: vehicleID, title: "Позже по календарю",
                                  intervalMonths: 6, lastMileage: 5000, lastDate: now)
        let near = MaintenanceTask(vehicleID: vehicleID, title: "Скоро по календарю",
                                   intervalMonths: 1, lastMileage: 5000, lastDate: now)
        let kmOnly = MaintenanceTask(vehicleID: vehicleID, title: "Только пробег",
                                     intervalKm: 1000, lastMileage: 5000, lastDate: now)

        let sorted = TaskListSorter.sorted(
            [kmOnly, far, near],
            mode: .calendar,
            mileage: 7000,
            engineHours: 0,
            warningKm: 100,
            warningDays: 7,
            now: now
        )
        XCTAssertEqual(sorted.map(\.id), [near.id, far.id, kmOnly.id])
    }

    func testAddedSortRetainsCreatedOrder() {
        let id = UUID()
        let old = MaintenanceTask(vehicleID: id, title: "Первая",
                                  lastMileage: 0, createdAt: Date(timeIntervalSince1970: 1000))
        let new = MaintenanceTask(vehicleID: id, title: "Вторая",
                                  lastMileage: 0, createdAt: Date(timeIntervalSince1970: 2000))
        let sorted = TaskListSorter.sorted(
            [new, old],
            mode: .added,
            mileage: 0,
            engineHours: 0,
            warningKm: 1000,
            warningDays: 7
        )
        XCTAssertEqual(sorted.map(\.id), [old.id, new.id])
    }

    func testCSVIsExplainedAsExportOnly() {
        XCTAssertNoThrow(try BackupImportFormat.validate(filename: "GarageCare-backup.JSON"))
        XCTAssertThrowsError(try BackupImportFormat.validate(filename: "GarageCare-history.csv")) { error in
            XCTAssertTrue(error.localizedDescription.contains("CSV"))
            XCTAssertTrue(error.localizedDescription.contains("JSON"))
        }
        XCTAssertThrowsError(try BackupImportFormat.validate(filename: "history.pdf"))
    }
}
