import Foundation
import SwiftData
import SwiftUI

enum GarageDeadline {
    static func days(to date: Date, now: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                to: calendar.startOfDay(for: date)).day ?? 0
    }

    static func countdown(to date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let days = days(to: date, now: now, calendar: calendar)
        if days < 0 { return "Просрочено на \(abs(days)) дн." }
        if days == 0 { return "Сегодня" }
        let parts = calendar.dateComponents([.month, .day],
            from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date))
        let months = max(0, parts.month ?? 0)
        let rest = max(0, parts.day ?? 0)
        return months > 0 ? "Через \(months) мес. \(rest) дн." : "Через \(days) дн."
    }

    static func statusColor(to date: Date, warningDays: Int, now: Date = .now) -> Color {
        let remaining = days(to: date, now: now)
        if remaining < 0 { return .garageRed }
        return remaining <= warningDays ? .garageOrange : .garageGreen
    }

    static func nextDebit(after date: Date, months: Int, calendar: Calendar = .current) -> Date? {
        guard months > 0 else { return nil }
        return calendar.date(byAdding: .month, value: months, to: date)
    }
}

/// Used below each car on the Garage screen, with no invented dates when unset.
struct GarageDeadlineLabels: View {
    let vehicle: Vehicle

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let date = vehicle.huDueDate {
                Label("HU / TÜV · \(GarageDeadline.countdown(to: date))", systemImage: "checkmark.seal")
                    .foregroundStyle(GarageDeadline.statusColor(to: date, warningDays: 30))
            }
            if let date = vehicle.insuranceNextDebitDate {
                Label("Страховка · \(GarageDeadline.countdown(to: date))", systemImage: "creditcard")
                    .foregroundStyle(GarageDeadline.statusColor(to: date, warningDays: 7))
            }
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}

struct VehicleDeadlinesCard: View {
    let vehicle: Vehicle
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("СРОКИ И ПЛАТЕЖИ")
                        .font(.caption.weight(.bold))
                        .tracking(1.1)
                        .foregroundStyle(Color.garageGreen)
                    Spacer()
                    Image(systemName: "square.and.pencil")
                        .foregroundStyle(Color.garageGreen)
                }
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.seal")
                        .frame(width: 23)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HU / TÜV").fontWeight(.semibold)
                        if let date = vehicle.huDueDate {
                            Text(GarageDeadline.countdown(to: date))
                                .foregroundStyle(GarageDeadline.statusColor(to: date, warningDays: 30))
                            Text("До \(Formatters.russianDate(date))")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Дата не задана").foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                Divider()
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "creditcard")
                        .frame(width: 23)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Страховка").fontWeight(.semibold)
                        if let date = vehicle.insuranceNextDebitDate {
                            Text(GarageDeadline.countdown(to: date))
                                .foregroundStyle(GarageDeadline.statusColor(to: date, warningDays: 7))
                            Text("Ожидаемое списание: \(Formatters.russianDate(date))")
                                .font(.caption).foregroundStyle(.secondary)
                            if vehicle.insuranceCost > 0 {
                                Text(vehicle.insuranceCost, format: .currency(code: vehicle.insuranceCurrency))
                                    .font(.caption.weight(.semibold))
                            }
                        } else {
                            Text("Дата не задана").foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                Text("Нажми, чтобы указать или изменить даты")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding(16)
            .garageCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Сроки HU и страховые списания. Изменить")
    }
}

struct VehicleDeadlinesEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let vehicle: Vehicle

    @State private var hasHU: Bool
    @State private var hasHUStart: Bool
    @State private var huStart: Date
    @State private var huDue: Date
    @State private var hasInsurance: Bool
    @State private var hasInsuranceStart: Bool
    @State private var insuranceStart: Date
    @State private var insuranceNext: Date
    @State private var periodMonths: Int
    @State private var amount: String
    @State private var currency: String
    @State private var confirmedDate: Date?
    @State private var error: String?

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _hasHU = State(initialValue: vehicle.huDueDate != nil)
        _hasHUStart = State(initialValue: vehicle.huStartDate != nil)
        _huStart = State(initialValue: vehicle.huStartDate ?? .now)
        _huDue = State(initialValue: vehicle.huDueDate ?? .now)
        _hasInsurance = State(initialValue: vehicle.insuranceNextDebitDate != nil)
        _hasInsuranceStart = State(initialValue: vehicle.insuranceStartDate != nil)
        _insuranceStart = State(initialValue: vehicle.insuranceStartDate ?? .now)
        _insuranceNext = State(initialValue: vehicle.insuranceNextDebitDate ?? .now)
        _periodMonths = State(initialValue: [1, 3, 6, 12].contains(vehicle.insurancePeriodMonths) ? vehicle.insurancePeriodMonths : 12)
        _amount = State(initialValue: vehicle.insuranceCost > 0 ? String(vehicle.insuranceCost) : "")
        _currency = State(initialValue: vehicle.insuranceCurrency)
        _confirmedDate = State(initialValue: vehicle.insuranceLastConfirmedDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Отслеживать HU / TÜV", isOn: $hasHU)
                    if hasHU {
                        Toggle("Указать дату последней проверки", isOn: $hasHUStart)
                        if hasHUStart {
                            DatePicker("Последняя проверка", selection: $huStart, displayedComponents: .date)
                            Button("Следующая через 24 месяца") {
                                huDue = Calendar.current.date(byAdding: .month, value: 24, to: huStart) ?? huStart
                            }
                        }
                        DatePicker("Действует до", selection: $huDue, displayedComponents: .date)
                        Text(GarageDeadline.countdown(to: huDue))
                            .font(.subheadline)
                            .foregroundStyle(GarageDeadline.statusColor(to: huDue, warningDays: 30))
                    }
                } header: {
                    Text("Техосмотр HU / TÜV")
                } footer: {
                    Text("Укажи фактическую дату окончания HU. Автоматический срок в 24 месяца — только подсказка, его можно изменить.")
                }

                Section {
                    Toggle("Отслеживать списания", isOn: $hasInsurance)
                    if hasInsurance {
                        Toggle("Указать начало договора", isOn: $hasInsuranceStart)
                        if hasInsuranceStart {
                            DatePicker("Начало договора", selection: $insuranceStart, displayedComponents: .date)
                        }
                        DatePicker("Следующее списание", selection: $insuranceNext, displayedComponents: .date)
                        Picker("Периодичность", selection: $periodMonths) {
                            Text("Ежемесячно").tag(1)
                            Text("Раз в 3 месяца").tag(3)
                            Text("Раз в 6 месяцев").tag(6)
                            Text("Ежегодно").tag(12)
                        }
                        LabeledContent("Сумма") {
                            TextField("Необязательно", text: $amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                        Picker("Валюта", selection: $currency) {
                            ForEach(["EUR", "USD", "UAH", "RUB"], id: \.self) { code in
                                Text(code).tag(code)
                            }
                        }
                        Text(GarageDeadline.countdown(to: insuranceNext))
                            .font(.subheadline)
                            .foregroundStyle(GarageDeadline.statusColor(to: insuranceNext, warningDays: 7))
                        if GarageDeadline.days(to: insuranceNext) <= 0 {
                            Button("Подтвердить прошедшее списание") {
                                confirmedDate = insuranceNext
                                if let following = GarageDeadline.nextDebit(after: insuranceNext, months: periodMonths) {
                                    insuranceNext = following
                                }
                            }
                            .foregroundStyle(Color.garageGreen)
                        }
                    }
                } header: {
                    Text("Автостраховка")
                } footer: {
                    Text("Это ожидаемое списание по твоему графику, а не подтверждение банка. После оплаты отметь его отдельно.")
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .garageKeyboardDismiss()
            .navigationTitle("Сроки и платежи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                }
            }
        }
    }

    private func save() {
        let normalized = amount.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let parsed = normalized.isEmpty ? 0 : Double(normalized),
              parsed.isFinite, parsed >= 0 else {
            error = "Укажи неотрицательную сумму либо оставь поле пустым."
            return
        }
        guard !hasHU || !hasHUStart || huDue >= huStart else {
            error = "Окончание HU не может быть раньше последней проверки."
            return
        }
        guard !hasInsurance || !hasInsuranceStart || insuranceNext >= insuranceStart else {
            error = "Следующее списание не может быть раньше начала договора."
            return
        }

        let oldHU = vehicle.huDueDate
        let oldDebit = vehicle.insuranceNextDebitDate
        vehicle.huStartDate = hasHU && hasHUStart ? huStart : nil
        vehicle.huDueDate = hasHU ? huDue : nil
        vehicle.insuranceStartDate = hasInsurance && hasInsuranceStart ? insuranceStart : nil
        vehicle.insuranceNextDebitDate = hasInsurance ? insuranceNext : nil
        vehicle.insurancePeriodMonths = periodMonths
        vehicle.insuranceCost = hasInsurance ? parsed : 0
        vehicle.insuranceCurrency = currency
        if oldDebit != vehicle.insuranceNextDebitDate && confirmedDate == vehicle.insuranceLastConfirmedDate {
            vehicle.insuranceLastConfirmedDate = nil
        } else {
            vehicle.insuranceLastConfirmedDate = confirmedDate
        }
        do {
            try context.save()
            NotificationManager.shared.refreshVehicleDeadlines(vehicle: vehicle)
            dismiss()
        } catch {
            context.rollback()
            vehicle.huDueDate = oldHU
            self.error = "Не удалось сохранить: \(error.localizedDescription)"
        }
    }
}
