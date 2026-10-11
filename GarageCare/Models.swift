import Foundation
import SwiftData
import SwiftUI
import UIKit

@Model
final class Vehicle {
    @Attribute(.unique) var id: UUID
    var make: String
    var model: String
    var year: Int
    var vin: String
    var currentMileage: Int
    var engineHours: Double = 0
    var notes: String
    var expectedFuelConsumption: Double = 0
    @Attribute(.externalStorage) var imageData: Data?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        make: String,
        model: String,
        year: Int,
        vin: String = "",
        currentMileage: Int,
        engineHours: Double = 0,
        notes: String = "",
        expectedFuelConsumption: Double = 0,
        imageData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.make = make
        self.model = model
        self.year = year
        self.vin = vin
        self.currentMileage = currentMileage
        self.engineHours = engineHours
        self.notes = notes
        self.expectedFuelConsumption = expectedFuelConsumption
        self.imageData = imageData
        self.createdAt = createdAt
    }

    var displayName: String {
        [make, model].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

@Model
final class MaintenanceTask {
    @Attribute(.unique) var id: UUID
    var vehicleID: UUID
    var title: String
    var intervalKm: Int
    var intervalMonths: Int
    var intervalEngineHours: Double = 0
    var lastEngineHours: Double = 0
    var lastMileage: Int
    var lastDate: Date
    var notes: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        vehicleID: UUID,
        title: String,
        intervalKm: Int = 0,
        intervalMonths: Int = 0,
        intervalEngineHours: Double = 0,
        lastEngineHours: Double = 0,
        lastMileage: Int,
        lastDate: Date = .now,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.title = title
        self.intervalKm = intervalKm
        self.intervalMonths = intervalMonths
        self.intervalEngineHours = intervalEngineHours
        self.lastEngineHours = lastEngineHours
        self.lastMileage = lastMileage
        self.lastDate = lastDate
        self.notes = notes
        self.createdAt = createdAt
    }

    func nextMileage() -> Int? {
        intervalKm > 0 ? lastMileage + intervalKm : nil
    }

    func kilometersRemaining(currentMileage: Int) -> Int? {
        guard let nextMileage = nextMileage() else { return nil }
        return nextMileage - currentMileage
    }

    func engineHoursRemaining(currentEngineHours: Double) -> Double? {
        guard intervalEngineHours > 0 else { return nil }
        return lastEngineHours + intervalEngineHours - currentEngineHours
    }

    func nextDate(calendar: Calendar = .current) -> Date? {
        guard intervalMonths > 0 else { return nil }
        return calendar.date(byAdding: .month, value: intervalMonths, to: lastDate)
    }

    func daysRemaining(now: Date = .now, calendar: Calendar = .current) -> Int? {
        guard let nextDate = nextDate(calendar: calendar) else { return nil }
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: nextDate)
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    func progress(currentMileage: Int, currentEngineHours: Double = 0, now: Date = .now) -> Double {
        var values: [Double] = []

        if intervalKm > 0 {
            let travelled = max(0, currentMileage - lastMileage)
            values.append(min(1, Double(travelled) / Double(intervalKm)))
        }

        if intervalEngineHours > 0 {
            let used = max(0, currentEngineHours - lastEngineHours)
            values.append(min(1, used / intervalEngineHours))
        }

        if intervalMonths > 0, let nextDate = nextDate() {
            let total = nextDate.timeIntervalSince(lastDate)
            if total > 0 {
                let elapsed = max(0, now.timeIntervalSince(lastDate))
                values.append(min(1, elapsed / total))
            }
        }

        return values.max() ?? 0
    }

    func state(
        currentMileage: Int,
        warningKm: Int,
        warningDays: Int,
        currentEngineHours: Double = 0,
        now: Date = .now
    ) -> DueState {
        let km = kilometersRemaining(currentMileage: currentMileage)
        let days = daysRemaining(now: now)
        let hours = engineHoursRemaining(currentEngineHours: currentEngineHours)

        if (km.map { $0 < 0 } ?? false) || (days.map { $0 < 0 } ?? false) || (hours.map { $0 < 0 } ?? false) {
            return .overdue
        }
        if (km.map { $0 <= warningKm } ?? false) || (days.map { $0 <= warningDays } ?? false) || (hours.map { $0 <= 10 } ?? false) {
            return .soon
        }
        if km == nil && days == nil && hours == nil {
            return .notConfigured
        }
        return .good
    }
}

@Model
final class ServiceRecord {
    @Attribute(.unique) var id: UUID
    var vehicleID: UUID
    var taskID: UUID?
    var title: String
    var mileage: Int
    var date: Date
    var cost: Double
    var currency: String
    var notes: String
    var parts: String = ""
    @Attribute(.externalStorage) var receiptImageData: Data?

    init(
        id: UUID = UUID(),
        vehicleID: UUID,
        taskID: UUID? = nil,
        title: String,
        mileage: Int,
        date: Date = .now,
        cost: Double = 0,
        currency: String = "EUR",
        notes: String = "",
        parts: String = "",
        receiptImageData: Data? = nil
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.taskID = taskID
        self.title = title
        self.mileage = mileage
        self.date = date
        self.cost = cost
        self.currency = currency
        self.notes = notes
        self.parts = parts
        self.receiptImageData = receiptImageData
    }
}

@Model
final class MileageEntry {
    @Attribute(.unique) var id: UUID
    var vehicleID: UUID
    var mileage: Int
    var date: Date

    init(id: UUID = UUID(), vehicleID: UUID, mileage: Int, date: Date = .now) {
        self.id = id
        self.vehicleID = vehicleID
        self.mileage = mileage
        self.date = date
    }
}


@Model
final class FuelEntry {
    @Attribute(.unique) var id: UUID
    var vehicleID: UUID
    var date: Date
    var mileage: Int
    var liters: Double
    var amount: Double
    var currency: String
    var isFullTank: Bool
    var fuelType: String = "Бензин"
    var notes: String

    init(
        id: UUID = UUID(),
        vehicleID: UUID,
        date: Date = .now,
        mileage: Int,
        liters: Double,
        amount: Double,
        currency: String = "EUR",
        isFullTank: Bool = true,
        fuelType: String = "Бензин",
        notes: String = ""
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.date = date
        self.mileage = mileage
        self.liters = liters
        self.amount = amount
        self.currency = currency
        self.isFullTank = isFullTank
        self.fuelType = fuelType
        self.notes = notes
    }

    var pricePerLiter: Double? {
        guard liters > 0, amount > 0 else { return nil }
        return amount / liters
    }
}

struct FuelConsumptionPoint: Identifiable {
    let id: UUID
    let date: Date
    let mileage: Int
    let distance: Int
    let liters: Double
    let consumption: Double
}

enum FuelStatisticsCalculator {
    static func consumptionPoints(entries: [FuelEntry]) -> [FuelConsumptionPoint] {
        let sorted = entries.sorted {
            if $0.mileage == $1.mileage { return $0.date < $1.date }
            return $0.mileage < $1.mileage
        }

        var result: [FuelConsumptionPoint] = []
        var previousFullMileage: Int?
        var accumulatedLiters = 0.0
        var activeFuelType: String?

        for entry in sorted {
            guard entry.liters > 0 else { continue }
            if let activeFuelType, activeFuelType != entry.fuelType {
                previousFullMileage = nil
                accumulatedLiters = 0
            }
            activeFuelType = entry.fuelType

            if previousFullMileage == nil {
                if entry.isFullTank {
                    previousFullMileage = entry.mileage
                    accumulatedLiters = 0
                }
                continue
            }

            accumulatedLiters += entry.liters

            if entry.isFullTank, let startMileage = previousFullMileage {
                let distance = entry.mileage - startMileage
                if distance > 0 {
                    result.append(
                        FuelConsumptionPoint(
                            id: entry.id,
                            date: entry.date,
                            mileage: entry.mileage,
                            distance: distance,
                            liters: accumulatedLiters,
                            consumption: accumulatedLiters / Double(distance) * 100
                        )
                    )
                }
                previousFullMileage = entry.mileage
                accumulatedLiters = 0
            }
        }

        return result
    }

    static func averageConsumption(entries: [FuelEntry]) -> Double? {
        guard Set(entries.map(\.fuelType)).count <= 1 else { return nil }
        let points = consumptionPoints(entries: entries)
        let totalDistance = points.reduce(0) { $0 + $1.distance }
        let totalLiters = points.reduce(0.0) { $0 + $1.liters }

        guard totalDistance > 0, totalLiters > 0 else { return nil }
        return totalLiters / Double(totalDistance) * 100
    }

    static func spendByCurrency(entries: [FuelEntry]) -> [String: Double] {
        Dictionary(grouping: entries.filter { $0.amount > 0 }, by: \.currency)
            .mapValues { values in
                values.reduce(0.0) { $0 + $1.amount }
            }
    }
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Система"
        case .dark: "Тёмная"
        case .light: "Светлая"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

enum DueState: Equatable {
    case good
    case soon
    case overdue
    case notConfigured

    var color: Color {
        switch self {
        case .good: .garageGreen
        case .soon: .orange
        case .overdue: .red
        case .notConfigured: .secondary
        }
    }

    var title: String {
        switch self {
        case .good: "В норме"
        case .soon: "Скоро"
        case .overdue: "Просрочено"
        case .notConfigured: "Задай интервал"
        }
    }
}

extension Color {
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    static var garageGreen: Color {
        adaptive(
            light: UIColor(red: 0.00, green: 0.478, blue: 0.208, alpha: 1),
            dark: UIColor(red: 0.18, green: 0.94, blue: 0.43, alpha: 1)
        )
    }

    static var garageOnAccent: Color {
        adaptive(
            light: .white,
            dark: .black
        )
    }

    static var garageYellow: Color {
        adaptive(
            light: UIColor(red: 0.478, green: 0.365, blue: 0.00, alpha: 1),
            dark: UIColor(red: 0.98, green: 0.79, blue: 0.18, alpha: 1)
        )
    }

    static var garageOrange: Color {
        adaptive(
            light: UIColor(red: 0.643, green: 0.278, blue: 0.00, alpha: 1),
            dark: UIColor(red: 1.00, green: 0.46, blue: 0.14, alpha: 1)
        )
    }

    static var garageRed: Color {
        adaptive(
            light: UIColor(red: 0.706, green: 0.137, blue: 0.165, alpha: 1),
            dark: UIColor(red: 1.00, green: 0.24, blue: 0.25, alpha: 1)
        )
    }

    static var garageBackground: Color {
        adaptive(
            light: UIColor(red: 0.945, green: 0.963, blue: 0.952, alpha: 1),
            dark: UIColor(red: 0.035, green: 0.047, blue: 0.057, alpha: 1)
        )
    }
    static var garageSurface: Color {
        adaptive(
            light: UIColor(red: 0.985, green: 0.992, blue: 0.988, alpha: 1),
            dark: UIColor(red: 0.075, green: 0.094, blue: 0.108, alpha: 1)
        )
    }
    static var garageSurfaceRaised: Color {
        adaptive(
            light: UIColor(red: 0.91, green: 0.94, blue: 0.92, alpha: 1),
            dark: UIColor(red: 0.095, green: 0.118, blue: 0.135, alpha: 1)
        )
    }
    static var garageStroke: Color {
        adaptive(
            light: UIColor.black.withAlphaComponent(0.08),
            dark: UIColor.white.withAlphaComponent(0.085)
        )
    }

    static func maintenanceStatus(progress: Double, state: DueState) -> Color {
        if state == .notConfigured { return Color.secondary }
        if state == .overdue { return .garageRed }

        let p = min(max(progress.isFinite ? progress : 0, 0), 1)
        let hue: Double

        switch p {
        case ..<0.50:
            hue = 0.36 - (p / 0.50) * 0.07
        case ..<0.70:
            hue = 0.29 - ((p - 0.50) / 0.20) * 0.15
        case ..<0.85:
            hue = 0.14 - ((p - 0.70) / 0.15) * 0.08
        default:
            hue = max(0, 0.06 - ((p - 0.85) / 0.15) * 0.06)
        }

        return Color(
            uiColor: UIColor { traits in
                // Keep the vivid spectrum in dark mode. In light mode the
                // same hue progression is darkened enough for AA text contrast
                // against GarageCare's light surfaces.
                let brightness: CGFloat = traits.userInterfaceStyle == .dark ? 0.97 : 0.50
                return UIColor(
                    hue: CGFloat(hue),
                    saturation: 0.88,
                    brightness: brightness,
                    alpha: 1
                )
            }
        )
    }
}

enum Formatters {
    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func mileage(_ value: Int) -> String {
        "\(integer.string(from: NSNumber(value: value)) ?? String(value)) км"
    }

    static func russianDate(_ value: Date) -> String {
        russianDateFormatter.string(from: value)
    }

    private static let russianDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "d MMMM yyyy 'г.'"
        return formatter
    }()
}
