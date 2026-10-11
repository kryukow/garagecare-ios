import Charts
import SwiftData
import SwiftUI

struct FuelTabView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                GarageScreenBackground()
                FuelStatisticsView()
            }
            .navigationTitle("Заправки")
        }
    }
}

struct FuelStatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\FuelEntry.date, order: .reverse)])
    private var fuelEntries: [FuelEntry]
    @Query(sort: \Vehicle.createdAt)
    private var vehicles: [Vehicle]

    @State private var selectedVehicleID: UUID?
    @State private var showingAddFuel = false

    private var selectedVehicle: Vehicle? {
        if let selectedVehicleID,
           let vehicle = vehicles.first(where: { $0.id == selectedVehicleID }) {
            return vehicle
        }
        return vehicles.first
    }

    private var selectedEntries: [FuelEntry] {
        guard let vehicle = selectedVehicle else { return [] }
        return fuelEntries
            .filter { $0.vehicleID == vehicle.id }
            .sorted { $0.date > $1.date }
    }

    private var consumptionPoints: [FuelConsumptionPoint] {
        FuelStatisticsCalculator.consumptionPoints(entries: selectedEntries)
    }

    private var averageConsumption: Double? {
        FuelStatisticsCalculator.averageConsumption(entries: selectedEntries)
    }

    private var spendByCurrency: [String: Double] {
        FuelStatisticsCalculator.spendByCurrency(entries: selectedEntries)
    }

    private var currencies: [String] {
        spendByCurrency.keys.sorted()
    }

    private var hasMixedCurrencies: Bool {
        currencies.count > 1
    }

    private var currency: String {
        currencies.first ?? "EUR"
    }

    private var totalSpend: Double {
        spendByCurrency[currency] ?? 0
    }

    private var totalLiters: Double {
        selectedEntries.reduce(0) { $0 + $1.liters }
    }

    private var monthlySpend: [MonthlyFuelSpend] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: selectedEntries.filter { $0.currency == currency }) { entry in
            let components = calendar.dateComponents([.year, .month], from: entry.date)
            return calendar.date(from: components) ?? entry.date
        }

        return grouped.map { date, entries in
            MonthlyFuelSpend(
                month: date,
                amount: entries.reduce(0) { $0 + $1.amount }
            )
        }
        .sorted { $0.month < $1.month }
        .suffix(6)
        .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if vehicles.isEmpty {
                    emptyVehicleState
                } else {
                    vehicleHeader
                    summaryGrid

                    if !consumptionPoints.isEmpty {
                        consumptionChart
                    } else if let vehicle = selectedVehicle, vehicle.expectedFuelConsumption > 0 {
                        expectedConsumptionCard(vehicle)
                    } else {
                        firstConsumptionHint
                    }

                    if hasMixedCurrencies {
                        mixedCurrencyCard
                    } else if !monthlySpend.isEmpty {
                        spendChart
                    }

                    recentFuelEntries
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            if selectedVehicleID == nil {
                selectedVehicleID = vehicles.first?.id
            }
        }
        .onChange(of: vehicles.map(\.id)) { _, ids in
            if let selectedVehicleID, !ids.contains(selectedVehicleID) {
                self.selectedVehicleID = ids.first
            } else if selectedVehicleID == nil {
                selectedVehicleID = ids.first
            }
        }
        .sheet(isPresented: $showingAddFuel) {
            if let selectedVehicle {
                FuelEntryEditor(vehicle: selectedVehicle)
            }
        }
    }

    private var vehicleHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("ТОПЛИВО И РАСХОД")
                    .font(.caption.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(Color.garageGreen)

                if vehicles.count > 1 {
                    Picker("Автомобиль", selection: Binding(
                        get: { selectedVehicle?.id ?? vehicles[0].id },
                        set: { selectedVehicleID = $0 }
                    )) {
                        ForEach(vehicles) { vehicle in
                            Text(vehicle.displayName).tag(vehicle.id)
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    Text(selectedVehicle?.displayName ?? "Автомобиль")
                        .font(.headline)
                }
            }

            Spacer()

            Button {
                showingAddFuel = true
            } label: {
                Label("Заправка", systemImage: "fuelpump.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 13)
                    .frame(height: 40)
                    .foregroundStyle(Color.garageOnAccent)
                    .background(Color.garageGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(16)
        .garageCard(cornerRadius: 20)
    }

    private var summaryGrid: some View {
        HStack(spacing: 10) {
            StatisticTile(
                title: "СРЕДНИЙ РАСХОД",
                value: consumptionDisplay,
                systemImage: "gauge.with.dots.needle.50percent",
                color: .garageGreen
            )
            StatisticTile(
                title: "ЗАТРАТЫ",
                value: hasMixedCurrencies
                    ? "\(currencies.count) валюты"
                    : (totalSpend > 0 ? totalSpend.formatted(.currency(code: currency)) : "—"),
                systemImage: "banknote.fill",
                color: .garageOrange
            )
            StatisticTile(
                title: "ЗАПРАВЛЕНО",
                value: totalLiters > 0
                    ? String(format: "%.1f л", totalLiters)
                    : "—",
                systemImage: "fuelpump.fill",
                color: .garageYellow
            )
        }
    }

    private var consumptionDisplay: String {
        if let averageConsumption {
            return String(format: "%.1f л", averageConsumption)
        }
        if let selectedVehicle, selectedVehicle.expectedFuelConsumption > 0 {
            return String(format: "~%.1f л", selectedVehicle.expectedFuelConsumption)
        }
        return "—"
    }

    private var consumptionChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Расход топлива")
                        .font(.headline)
                    Text("л / 100 км · по полным бакам")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let last = consumptionPoints.last {
                    Text(String(format: "%.1f", last.consumption))
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(Color.garageGreen)
                }
            }

            Chart(consumptionPoints.suffix(12)) { point in
                LineMark(
                    x: .value("Дата", point.date),
                    y: .value("Расход", point.consumption)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.garageGreen)

                PointMark(
                    x: .value("Дата", point.date),
                    y: .value("Расход", point.consumption)
                )
                .foregroundStyle(Color.garageGreen)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 190)
            .accessibilityLabel("График расхода топлива")
            .accessibilityValue(
                averageConsumption.map { String(format: "Средний расход %.1f литра на 100 километров", $0) }
                    ?? "Недостаточно данных"
            )
        }
        .padding(16)
        .garageCard(cornerRadius: 20)
    }

    private var mixedCurrencyCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "banknote.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.garageOrange)
                .frame(width: 50, height: 50)
                .background(Color.garageOrange.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                Text("Несколько валют")
                    .font(.headline)

                Text(
                    currencies.compactMap { code in
                        guard let amount = spendByCurrency[code] else { return nil }
                        return amount.formatted(.currency(code: code))
                    }
                    .joined(separator: " · ")
                )
                .font(.subheadline.weight(.semibold))

                Text("Суммы не складываются между собой без заданного курса валют.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .garageCard(cornerRadius: 20)
    }

    private var spendChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Расходы на топливо")
                .font(.headline)

            Chart(monthlySpend) { item in
                BarMark(
                    x: .value("Месяц", item.month, unit: .month),
                    y: .value("Сумма", item.amount)
                )
                .foregroundStyle(Color.garageGreen.gradient)
                .cornerRadius(5)
            }
            .frame(height: 170)
            .accessibilityLabel("График расходов на топливо")
            .accessibilityValue(
                totalSpend > 0
                    ? "Всего (totalSpend.formatted(.currency(code: currency)))"
                    : "Расходов пока нет"
            )
        }
        .padding(16)
        .garageCard(cornerRadius: 20)
    }

    private func expectedConsumptionCard(_ vehicle: Vehicle) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "gauge.open.with.lines.needle.33percent")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Color.garageGreen)
                .frame(width: 52, height: 52)
                .background(Color.garageGreen.opacity(0.10), in: RoundedRectangle(cornerRadius: 15))

            VStack(alignment: .leading, spacing: 4) {
                Text("Ожидаемый расход")
                    .font(.headline)
                Text(String(format: "%.1f л/100 км", vehicle.expectedFuelConsumption))
                    .font(.title3.bold().monospacedDigit())
                Text("Фактический появится после двух полных заправок.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .garageCard(cornerRadius: 20)
    }

    private var firstConsumptionHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Расход посчитается автоматически", systemImage: "function")
                .font(.headline)
                .foregroundStyle(Color.garageGreen)
            Text("Внеси две заправки «до полного» с пробегом и литрами. Между ними приложение рассчитает фактический расход.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard(cornerRadius: 20)
    }

    private var recentFuelEntries: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Последние заправки")
                    .font(.headline)
                Spacer()
                Text("\(selectedEntries.count)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            if selectedEntries.isEmpty {
                Text("Заправок пока нет")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(Array(selectedEntries.prefix(8).enumerated()), id: \.element.id) { index, entry in
                    FuelEntryRow(entry: entry)
                        .contextMenu {
                            Button("Удалить", role: .destructive) {
                                modelContext.delete(entry)
                                try? modelContext.save()
                            }
                        }

                    if index < min(selectedEntries.count, 8) - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .garageCard(cornerRadius: 20)
    }

    private var emptyVehicleState: some View {
        VStack(spacing: 14) {
            Image(systemName: "car.fill")
                .font(.system(size: 38))
                .foregroundStyle(Color.garageGreen)
            Text("Сначала добавь автомобиль")
                .font(.title3.bold())
            Text("После этого здесь появятся заправки, расход и статистика.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .garageCard(cornerRadius: 22)
    }
}

private struct StatisticTile: View {
    let title: String
    let value: String
    let systemImage: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(color)

            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(title)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .garageCard(cornerRadius: 18)
    }
}

private struct FuelEntryRow: View {
    let entry: FuelEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "fuelpump.fill")
                .font(.headline)
                .foregroundStyle(Color.garageGreen)
                .frame(width: 40, height: 40)
                .background(Color.garageGreen.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(String(format: "%.2f л", entry.liters))
                        .font(.subheadline.bold())
                    if entry.isFullTank {
                        Text("ПОЛНЫЙ")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.garageGreen)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.garageGreen.opacity(0.10), in: Capsule())
                    }
                }

                Text("\(Formatters.mileage(entry.mileage)) · \(Formatters.russianDate(entry.date))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if entry.amount > 0 {
                Text(entry.amount, format: .currency(code: entry.currency))
                    .font(.subheadline.bold())
            }
        }
    }
}

private struct MonthlyFuelSpend: Identifiable {
    let month: Date
    let amount: Double

    var id: Date { month }
}

private struct FuelEntryEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let vehicle: Vehicle

    @State private var date = Date.now
    @State private var mileage: String
    @State private var liters = ""
    @State private var amount = ""
    @State private var currency = "EUR"
    @State private var isFullTank = true
    @State private var notes = ""
    @State private var errorMessage: String?

    init(vehicle: Vehicle) {
        self.vehicle = vehicle
        _mileage = State(initialValue: String(vehicle.currentMileage))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Заправка") {
                    TextField("Пробег, км", text: $mileage)
                        .keyboardType(.numberPad)
                    TextField("Литры", text: $liters)
                        .keyboardType(.decimalPad)
                    TextField("Сумма", text: $amount)
                        .keyboardType(.decimalPad)
                    Picker("Валюта", selection: $currency) {
                        Text("EUR").tag("EUR")
                        Text("USD").tag("USD")
                        Text("UAH").tag("UAH")
                        Text("RUB").tag("RUB")
                    }
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                }

                Section {
                    Toggle("Заправка до полного", isOn: $isFullTank)
                } footer: {
                    Text("Для точного расчёта л/100 км приложение сравнивает пробег между полными баками и учитывает промежуточные доливы.")
                }

                Section("Заметка") {
                    TextField("АЗС, топливо или комментарий", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle("Новая заправка")
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
        let normalizedLiters = liters.replacingOccurrences(of: ",", with: ".")
        let normalizedAmount = amount.replacingOccurrences(of: ",", with: ".")

        guard let mileageValue = Int(mileage.filter(\.isNumber)) else {
            errorMessage = "Введи пробег цифрами."
            return
        }
        guard let litersValue = Double(normalizedLiters), litersValue > 0 else {
            errorMessage = "Введи количество топлива."
            return
        }

        let amountValue = Double(normalizedAmount) ?? 0

        modelContext.insert(
            FuelEntry(
                vehicleID: vehicle.id,
                date: date,
                mileage: mileageValue,
                liters: litersValue,
                amount: amountValue,
                currency: currency,
                isFullTank: isFullTank,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )

        if mileageValue > vehicle.currentMileage {
            vehicle.currentMileage = mileageValue
            modelContext.insert(
                MileageEntry(
                    vehicleID: vehicle.id,
                    mileage: mileageValue,
                    date: date
                )
            )
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Не удалось сохранить заправку: \(error.localizedDescription)"
        }
    }
}
