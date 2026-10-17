import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct BackupPayload: Codable {
    let version: Int
    let exportedAt: Date
    let vehicles: [VehicleSnapshot]
    let tasks: [TaskSnapshot]
    let records: [RecordSnapshot]
    let mileageEntries: [MileageSnapshot]
    let fuelEntries: [FuelSnapshot]?
}

struct VehicleSnapshot: Codable {
    let id: UUID
    let make: String
    let model: String
    let year: Int
    let vin: String
    let currentMileage: Int
    let engineHours: Double?
    let notes: String
    let expectedFuelConsumption: Double?
    let imageData: Data?
    let createdAt: Date

    init(_ value: Vehicle) {
        id = value.id
        make = value.make
        model = value.model
        year = value.year
        vin = value.vin
        currentMileage = value.currentMileage
        engineHours = value.engineHours
        notes = value.notes
        expectedFuelConsumption = value.expectedFuelConsumption
        imageData = value.imageData
        createdAt = value.createdAt
    }
}

struct TaskSnapshot: Codable {
    let id: UUID
    let vehicleID: UUID
    let title: String
    let intervalKm: Int
    let intervalMonths: Int
    let intervalEngineHours: Double?
    let lastEngineHours: Double?
    let lastMileage: Int
    let lastDate: Date
    let notes: String
    let imageData: Data?
    let createdAt: Date

    init(_ value: MaintenanceTask) {
        id = value.id
        vehicleID = value.vehicleID
        title = value.title
        intervalKm = value.intervalKm
        intervalMonths = value.intervalMonths
        intervalEngineHours = value.intervalEngineHours
        lastEngineHours = value.lastEngineHours
        lastMileage = value.lastMileage
        lastDate = value.lastDate
        notes = value.notes
        imageData = value.imageData
        createdAt = value.createdAt
    }
}

struct RecordSnapshot: Codable {
    let id: UUID
    let vehicleID: UUID
    let taskID: UUID?
    let title: String
    let mileage: Int
    let engineHours: Double?
    let date: Date
    let cost: Double
    let currency: String
    let notes: String
    let parts: String?
    let receiptImageData: Data?
    let imageData: Data?

    init(_ value: ServiceRecord) {
        id = value.id
        vehicleID = value.vehicleID
        taskID = value.taskID
        title = value.title
        mileage = value.mileage
        engineHours = value.engineHours
        date = value.date
        cost = value.cost
        currency = value.currency
        notes = value.notes
        parts = value.parts
        receiptImageData = value.receiptImageData
        imageData = value.imageData
    }
}

struct MileageSnapshot: Codable {
    let id: UUID
    let vehicleID: UUID
    let mileage: Int
    let engineHours: Double?
    let date: Date

    init(_ value: MileageEntry) {
        id = value.id
        vehicleID = value.vehicleID
        mileage = value.mileage
        engineHours = value.engineHours
        date = value.date
    }
}


struct FuelSnapshot: Codable {
    let id: UUID
    let vehicleID: UUID
    let date: Date
    let mileage: Int
    let liters: Double
    let amount: Double
    let currency: String
    let isFullTank: Bool
    let fuelType: String?
    let notes: String

    init(_ value: FuelEntry) {
        id = value.id
        vehicleID = value.vehicleID
        date = value.date
        mileage = value.mileage
        liters = value.liters
        amount = value.amount
        currency = value.currency
        isFullTank = value.isFullTank
        fuelType = value.fuelType
        notes = value.notes
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}



struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        let data = configuration.file.regularFileContents ?? Data()
        text = String(data: data, encoding: .utf8) ?? ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

enum HistoryCSVExporter {
    static func makeCSV(
        vehicles: [Vehicle],
        records: [ServiceRecord],
        fuelEntries: [FuelEntry]
    ) -> String {
        let vehicleNames = Dictionary(uniqueKeysWithValues: vehicles.map { ($0.id, $0.displayName) })
        var rows = [
            ["Тип", "Автомобиль", "Дата", "Пробег", "Описание", "Литры", "Сумма", "Валюта", "Заметка", "Запчасти"]
        ]

        for record in records.sorted(by: { $0.date < $1.date }) {
            rows.append([
                "ТО",
                vehicleNames[record.vehicleID] ?? "Автомобиль",
                isoDate(record.date),
                String(record.mileage),
                record.title,
                "",
                record.cost > 0 ? decimal(record.cost) : "",
                record.cost > 0 ? record.currency : "",
                record.notes,
                record.parts
            ])
        }

        for entry in fuelEntries.sorted(by: { $0.date < $1.date }) {
            rows.append([
                "Заправка",
                vehicleNames[entry.vehicleID] ?? "Автомобиль",
                isoDate(entry.date),
                String(entry.mileage),
                entry.isFullTank ? "До полного" : "Долив",
                decimal(entry.liters),
                entry.amount > 0 ? decimal(entry.amount) : "",
                entry.amount > 0 ? entry.currency : "",
                entry.notes,
                ""
            ])
        }

        return rows
            .map { $0.map(escape).joined(separator: ";") }
            .joined(separator: "\n") + "\n"
    }

    private static func isoDate(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }

    private static func decimal(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func escape(_ value: String) -> String {
        let mustQuote = value.contains(";") || value.contains("\n") || value.contains("\r") || value.contains("\"")
        guard mustQuote else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
