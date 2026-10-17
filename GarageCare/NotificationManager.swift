import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func authorizationGranted() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    func refresh(
        vehicle: Vehicle,
        tasks: [MaintenanceTask],
        warningKm: Int,
        warningDays: Int,
        warningEngineHours: Double = 10
    ) {
        let center = UNUserNotificationCenter.current()
        let identifiers = tasks.flatMap { ["date-\($0.id.uuidString)", "km-\($0.id.uuidString)", "hours-\($0.id.uuidString)"] }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for task in tasks {
            scheduleDateNotification(vehicle: vehicle, task: task, warningDays: warningDays)
            scheduleMileageNotification(vehicle: vehicle, task: task, warningKm: warningKm)
            scheduleEngineHoursNotification(vehicle: vehicle, task: task, warningEngineHours: warningEngineHours)
        }
    }

    func scheduleMileageEntryReminder(
        vehicle: Vehicle,
        lastUpdate: Date,
        afterDays days: Int
    ) {
        let center = UNUserNotificationCenter.current()
        let identifier = "mileage-entry-\(vehicle.id.uuidString)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard days > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Обнови пробег"
        content.body = "Внеси актуальный пробег для \(vehicle.displayName), чтобы расчёт регламентных работ оставался точным."
        content.sound = .default

        let targetDate = Calendar.current.date(byAdding: .day, value: days, to: lastUpdate) ?? lastUpdate
        let trigger: UNNotificationTrigger
        if targetDate <= .now {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        } else {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
            components.hour = 18
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    func cancelNotifications(for task: MaintenanceTask) {
        let center = UNUserNotificationCenter.current()
        let identifiers = [
            "date-\(task.id.uuidString)",
            "km-\(task.id.uuidString)",
            "hours-\(task.id.uuidString)"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func cancelNotifications(for vehicle: Vehicle, tasks: [MaintenanceTask]) {
        let center = UNUserNotificationCenter.current()
        let identifiers =
            tasks.flatMap { ["date-\($0.id.uuidString)", "km-\($0.id.uuidString)", "hours-\($0.id.uuidString)"] } +
            ["mileage-entry-\(vehicle.id.uuidString)",
             "hu-\(vehicle.id.uuidString)",
             "insurance-\(vehicle.id.uuidString)"]

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func scheduleDateNotification(vehicle: Vehicle, task: MaintenanceTask, warningDays: Int) {
        guard let dueDate = task.nextDate() else { return }
        let notificationDate = Calendar.current.date(byAdding: .day, value: -warningDays, to: dueDate) ?? dueDate

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = "Для \(vehicle.displayName) приближается регламентная работа."
        content.sound = .default

        if notificationDate <= .now {
            let request = UNNotificationRequest(
                identifier: "date-\(task.id.uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
            )
            UNUserNotificationCenter.current().add(request)
            return
        }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: notificationDate)
        components.hour = 10
        let request = UNNotificationRequest(
            identifier: "date-\(task.id.uuidString)",
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleMileageNotification(vehicle: Vehicle, task: MaintenanceTask, warningKm: Int) {
        guard let remaining = task.kilometersRemaining(currentMileage: vehicle.currentMileage), remaining <= warningKm else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = remaining < 0
            ? "Для \(vehicle.displayName) работа просрочена на \(Formatters.mileage(abs(remaining)))."
            : "Для \(vehicle.displayName) осталось \(Formatters.mileage(remaining))."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "km-\(task.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }
    private func scheduleEngineHoursNotification(vehicle: Vehicle, task: MaintenanceTask, warningEngineHours: Double) {
        guard let remaining = task.engineHoursRemaining(currentEngineHours: vehicle.engineHours),
              remaining <= warningEngineHours else { return }
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = remaining < 0
            ? "Для \(vehicle.displayName) работа просрочена на \(String(format: "%.1f", abs(remaining))) моточасов."
            : "Для \(vehicle.displayName) осталось \(String(format: "%.1f", remaining)) моточасов."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "hours-\(task.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Date-based notices are separate from engine-hour and odometer service
    /// intervals. One-time notifications never imply the insurance was paid.
    func refreshVehicleDeadlines(vehicle: Vehicle) {
        let center = UNUserNotificationCenter.current()
        let ids = ["hu-\(vehicle.id.uuidString)", "insurance-\(vehicle.id.uuidString)"]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        if let huDate = vehicle.huDueDate {
            scheduleDeadline(
                id: ids[0], title: "HU / TÜV: \(vehicle.displayName)",
                body: "Проверь срок техосмотра: до \(Formatters.russianDate(huDate)).",
                dueDate: huDate, advanceDays: 30
            )
        }
        if let debit = vehicle.insuranceNextDebitDate {
            scheduleDeadline(
                id: ids[1], title: "Страховка: \(vehicle.displayName)",
                body: "Ожидаемое списание страховки \(Formatters.russianDate(debit)). Проверь платёж в банке.",
                dueDate: debit, advanceDays: 7
            )
        }
    }

    private func scheduleDeadline(id: String, title: String, body: String, dueDate: Date, advanceDays: Int) {
        // Do not schedule notifications in the past or spam after expiry.
        guard Calendar.current.startOfDay(for: dueDate) >= Calendar.current.startOfDay(for: .now) else {
            return
        }
        let target = Calendar.current.date(byAdding: .day, value: -advanceDays, to: dueDate) ?? dueDate
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger: UNNotificationTrigger
        if target <= .now {
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        } else {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: target)
            components.hour = 9
            components.minute = 0
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        )
    }

}
