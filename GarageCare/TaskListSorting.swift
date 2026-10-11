import Foundation

/// Порядок показа регламента не изменяет записи SwiftData.
enum TaskListSortMode: String, CaseIterable, Identifiable {
    case urgency
    case calendar
    case added

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urgency: "Сначала ближайшие"
        case .calendar: "По календарному сроку"
        case .added: "По добавлению"
        }
    }
}

enum TaskListSorter {
    static func sorted(
        _ tasks: [MaintenanceTask],
        mode: TaskListSortMode,
        mileage: Int,
        engineHours: Double,
        warningKm: Int,
        warningDays: Int,
        now: Date = .now
    ) -> [MaintenanceTask] {
        let entries = tasks.map { task in
            RankedTask(
                task: task,
                state: task.state(
                    currentMileage: mileage,
                    warningKm: warningKm,
                    warningDays: warningDays,
                    currentEngineHours: engineHours,
                    now: now
                ),
                progress: task.progress(
                    currentMileage: mileage,
                    currentEngineHours: engineHours,
                    now: now
                ),
                days: task.daysRemaining(now: now),
                kilometers: task.kilometersRemaining(currentMileage: mileage),
                hours: task.engineHoursRemaining(currentEngineHours: engineHours)
            )
        }
        return entries.sorted { lhs, rhs in
            switch mode {
            case .added:
                return earlierCreated(lhs.task, rhs.task)
            case .calendar:
                if let l = lhs.days, let r = rhs.days, l != r { return l < r }
                if (lhs.days != nil) != (rhs.days != nil) { return lhs.days != nil }
                return byUrgency(lhs, rhs)
            case .urgency:
                return byUrgency(lhs, rhs)
            }
        }.map(\.task)
    }

    private static func byUrgency(_ lhs: RankedTask, _ rhs: RankedTask) -> Bool {
        let a = priority(lhs.state)
        let b = priority(rhs.state)
        if a != b { return a < b }

        // Compare exact remaining days only when BOTH tasks have calendar intervals.
        if let l = lhs.days, let r = rhs.days, l != r { return l < r }

        // Kilometer and engine-hour intervals cannot be converted to calendar dates
        // without a reliable driving/engine-hour rate. Compare fraction used instead.
        if abs(lhs.progress - rhs.progress) > 0.000001 {
            return lhs.progress > rhs.progress
        }
        if let l = lhs.kilometers, let r = rhs.kilometers, l != r { return l < r }
        if let l = lhs.hours, let r = rhs.hours, abs(l - r) > 0.000001 { return l < r }
        return earlierCreated(lhs.task, rhs.task)
    }

    private static func earlierCreated(_ lhs: MaintenanceTask, _ rhs: MaintenanceTask) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func priority(_ state: DueState) -> Int {
        switch state {
        case .overdue: 0
        case .soon: 1
        case .good: 2
        case .notConfigured: 3
        }
    }

    private struct RankedTask {
        let task: MaintenanceTask
        let state: DueState
        let progress: Double
        let days: Int?
        let kilometers: Int?
        let hours: Double?
    }
}
