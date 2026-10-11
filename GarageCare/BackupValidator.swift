import Foundation

enum BackupValidationError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        if case .invalid(let reason) = self { return reason }
        return nil
    }
}

enum BackupValidator {
    static func validate(_ backup: BackupPayload) throws {
        guard (1...3).contains(backup.version) else {
            throw BackupValidationError.invalid("Неподдерживаемая версия резервной копии.")
        }
        func unique(_ ids: [UUID]) -> Bool {
            Set(ids).count == ids.count
        }
        guard unique(backup.vehicles.map(\.id)),
              unique(backup.tasks.map(\.id)),
              unique(backup.records.map(\.id)),
              unique(backup.mileageEntries.map(\.id)),
              unique((backup.fuelEntries ?? []).map(\.id)) else {
            throw BackupValidationError.invalid("В копии найдены повторяющиеся идентификаторы.")
        }
        let vehicleIDs = Set(backup.vehicles.map(\.id))
        guard backup.vehicles.allSatisfy({ $0.currentMileage >= 0 && $0.year >= 1886 &&
            $0.year <= Calendar.current.component(.year, from: .now) + 2 &&
            ($0.engineHours ?? 0).isFinite && ($0.engineHours ?? 0) >= 0 &&
            $0.expectedFuelConsumption.map { $0.isFinite && $0 >= 0 } ?? true
        }) else {
            throw BackupValidationError.invalid("Недопустимые сведения об автомобиле.")
        }
        guard backup.tasks.allSatisfy({
            vehicleIDs.contains($0.vehicleID) &&
            $0.intervalKm >= 0 && $0.intervalMonths >= 0 && $0.lastMileage >= 0 &&
            ($0.intervalEngineHours ?? 0).isFinite && ($0.intervalEngineHours ?? 0) >= 0 &&
            ($0.lastEngineHours ?? 0).isFinite && ($0.lastEngineHours ?? 0) >= 0
        }) else {
            throw BackupValidationError.invalid("Регламент ссылается на отсутствующий автомобиль или содержит недопустимые значения.")
        }
        guard backup.records.allSatisfy({ record in
            let relatedTaskValid = record.taskID.map { taskID in
                backup.tasks.contains(where: { $0.id == taskID && $0.vehicleID == record.vehicleID })
            } ?? true
            return vehicleIDs.contains(record.vehicleID) && relatedTaskValid &&
                record.mileage >= 0 && record.cost.isFinite && record.cost >= 0
        }) else {
            throw BackupValidationError.invalid("В истории есть отсутствующий автомобиль, работа или неверная стоимость.")
        }
        guard backup.mileageEntries.allSatisfy({ vehicleIDs.contains($0.vehicleID) && $0.mileage >= 0 }),
              (backup.fuelEntries ?? []).allSatisfy({
                vehicleIDs.contains($0.vehicleID) && $0.mileage >= 0 &&
                $0.liters.isFinite && $0.liters > 0 &&
                $0.amount.isFinite && $0.amount >= 0
              }) else {
            throw BackupValidationError.invalid("Ошибка в истории пробега или заправок.")
        }
        // Empty copies are valid; they may be intentionally created from a new installation.
    }
}


/// Из Google Drive/iCloud можно получить файлы с различными UTI.
/// Проверяем расширение в дополнение к системному фильтру документа.
enum BackupImportFormat {
    static func validate(filename: String) throws {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "json":
            return
        case "csv":
            throw BackupValidationError.invalid(
                "CSV — это таблица истории для Excel или Google Sheets, а не резервная копия. " +
                "Вся история уже входит в GarageCare-backup.json. Для восстановления выбери JSON-файл."
            )
        default:
            throw BackupValidationError.invalid(
                "Для восстановления нужна резервная копия «Мой гараж» в формате JSON (.json). " +
                "Создай её в разделе «Резервная копия JSON»."
            )
        }
    }
}
