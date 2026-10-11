import PhotosUI
import SwiftData
import SwiftUI

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let vehicle: Vehicle
    let task: MaintenanceTask

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningDays") private var warningDays = 7

    @State private var records: [ServiceRecord] = []
    @State private var activeSheet: ActiveSheet?
    @State private var showingDeleteAlert = false
    @State private var deletionError: String?

    private enum ActiveSheet: Int, Identifiable {
        case editor
        case completion

        var id: Int { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statusCard

                detailCard(title: "Интервал") {
                    LabeledContent("По пробегу") {
                        Text(task.intervalKm > 0 ? Formatters.mileage(task.intervalKm) : "Не задан")
                    }

                    Divider()

                    LabeledContent("По времени") {
                        Text(task.intervalMonths > 0 ? "\(task.intervalMonths) мес." : "Не задан")
                    }

                    Divider()
                    LabeledContent("По моточасам") {
                        Text(task.intervalEngineHours > 0 ? String(format: "%.1f мч", task.intervalEngineHours) : "Не задан")
                    }

                    Divider()

                    LabeledContent("Последняя работа") {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Formatters.mileage(task.lastMileage))
                            Text(Formatters.russianDate(task.lastDate))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !task.notes.isEmpty {
                    detailCard(title: "Заметка") {
                        Text(task.notes)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                detailCard(title: "История") {
                    if records.isEmpty {
                        Text("Выполненных работ пока нет")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(records) { record in
                                ServiceRecordRow(record: record)

                                if record.id != records.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }

                Button("Удалить работу", role: .destructive) {
                    showingDeleteAlert = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.garageRed.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.garageRed.opacity(0.16), lineWidth: 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.garageBackground)
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Изменить") {
                    activeSheet = .editor
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                activeSheet = .completion
            } label: {
                Label("Отметить выполненной", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.garageGreen)
            .foregroundStyle(Color.garageOnAccent)
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(item: $activeSheet, onDismiss: loadRecords) { sheet in
            switch sheet {
            case .editor:
                TaskEditorView(vehicle: vehicle, task: task)
            case .completion:
                CompleteTaskView(vehicle: vehicle, task: task)
            }
        }
        .alert("Удалить работу?", isPresented: $showingDeleteAlert) {
            Button("Отмена", role: .cancel) {}
            Button("Удалить", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("История останется доступной, а связь с удалённым регламентом будет снята.")
        }
        .alert("Ошибка сохранения", isPresented: Binding(get: { deletionError != nil }, set: { if !$0 { deletionError = nil } })) {
            Button("OK", role: .cancel) { deletionError = nil }
        } message: {
            Text(deletionError ?? "")
        }
        .task {
            loadRecords()
        }
    }

    @ViewBuilder
    private func detailCard<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .garageCard(cornerRadius: 20)
    }

    private var statusCard: some View {
        let state = task.state(
            currentMileage: vehicle.currentMileage,
            warningKm: warningKm,
            warningDays: warningDays,
            currentEngineHours: vehicle.engineHours
        )
        let safeProgress = task.displayProgress(currentMileage: vehicle.currentMileage, currentEngineHours: vehicle.engineHours)
        let statusColor = task.displayColor(
            currentMileage: vehicle.currentMileage,
            warningKm: warningKm,
            warningDays: warningDays,
            currentEngineHours: vehicle.engineHours
        )

        return VStack(alignment: .leading, spacing: 15) {
            HStack(alignment: .center) {
                GarageStatusPill(
                    title: state.title.uppercased(),
                    color: statusColor,
                    systemImage: state == .overdue
                        ? "exclamationmark.triangle.fill"
                        : (state == .good ? "checkmark" : nil)
                )

                Spacer()

                if state != .notConfigured {
                    Text("\(Int((safeProgress * 100).rounded()))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(statusColor)
                }
            }

            GarageProgressBar(progress: safeProgress, color: statusColor)

            if task.intervalKm == 0 && task.intervalMonths == 0 && task.intervalEngineHours == 0 {
                Text("Задай пробег, срок или моточасы — после этого появится расчёт ресурса.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    if let km = task.kilometersRemaining(currentMileage: vehicle.currentMileage) {
                        HStack(spacing: 7) {
                            Image(systemName: "road.lanes")
                                .foregroundStyle(statusColor)
                            Text(
                                km >= 0
                                    ? "Осталось \(Formatters.mileage(km))"
                                    : "Просрочено на \(Formatters.mileage(abs(km)))"
                            )
                        }
                    }

                    if let hours = task.engineHoursRemaining(currentEngineHours: vehicle.engineHours) {
                        HStack(spacing: 7) {
                            Image(systemName: "gauge.with.dots.needle.50percent")
                                .foregroundStyle(statusColor)
                            Text(String(format: hours >= 0 ? "Осталось %.1f мч" : "Просрочено на %.1f мч", abs(hours)))
                        }
                    }

                    if let days = task.daysRemaining() {
                        HStack(spacing: 7) {
                            Image(systemName: "calendar")
                                .foregroundStyle(statusColor)
                            Text(
                                days >= 0
                                    ? "По времени осталось \(days) дн."
                                    : "По времени просрочено \(abs(days)) дн."
                            )
                        }
                    }
                }
                .font(.subheadline.weight(.medium))
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [statusColor.opacity(0.10), Color.garageSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(statusColor.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 16, y: 8)
    }

    private func loadRecords() {
        let taskID = task.id
        let descriptor = FetchDescriptor<ServiceRecord>(
            predicate: #Predicate<ServiceRecord> { record in
                record.taskID == taskID
            }
        )

        do {
            records = try modelContext.fetch(descriptor)
                .sorted { $0.date > $1.date }
        } catch {
            records = []
        }
    }

    private func deleteTask() {
        loadRecords()
        records.forEach { $0.taskID = nil }
        modelContext.delete(task)
        do {
            try modelContext.save()
            NotificationManager.shared.cancelNotifications(for: task)
            dismiss()
        } catch {
            modelContext.rollback()
            deletionError = error.localizedDescription
        }
    }
}

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let vehicle: Vehicle
    let task: MaintenanceTask?

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningDays") private var warningDays = 7

    @State private var title: String
    @State private var intervalKm: String
    @State private var intervalMonths: String
    @State private var intervalEngineHours: String
    @State private var lastEngineHours: String
    @State private var lastMileage: String
    @State private var lastDate: Date
    @State private var notes: String
    @State private var errorMessage: String?

    init(vehicle: Vehicle, task: MaintenanceTask? = nil) {
        self.vehicle = vehicle
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _intervalKm = State(initialValue: task.map { $0.intervalKm > 0 ? String($0.intervalKm) : "" } ?? "")
        _intervalMonths = State(initialValue: task.map { $0.intervalMonths > 0 ? String($0.intervalMonths) : "" } ?? "")
        _intervalEngineHours = State(initialValue: task.map { $0.intervalEngineHours > 0 ? String($0.intervalEngineHours) : "" } ?? "")
        _lastEngineHours = State(initialValue: String(task?.lastEngineHours ?? vehicle.engineHours))
        _lastMileage = State(initialValue: String(task?.lastMileage ?? vehicle.currentMileage))
        _lastDate = State(initialValue: task?.lastDate ?? .now)
        _notes = State(initialValue: task?.notes ?? "")
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Int(lastMileage.filter(\.isNumber)) != nil &&
        ((Int(intervalKm.filter(\.isNumber)) ?? 0) > 0 || (Int(intervalMonths.filter(\.isNumber)) ?? 0) > 0 || (Double(intervalEngineHours.replacingOccurrences(of: ",", with: ".")) ?? 0) > 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Работа") {
                    TextField("Название", text: $title)
                    Button("HU / TÜV — 24 месяца") {
                        title = "HU / TÜV"
                        intervalMonths = "24"
                        intervalKm = ""
                        intervalEngineHours = ""
                    }
                }

                Section {
                    TextField("Километры", text: $intervalKm)
                        .keyboardType(.numberPad)
                    TextField("Месяцы", text: $intervalMonths)
                        .keyboardType(.numberPad)
                    TextField("Моточасы", text: $intervalEngineHours)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Интервал")
                } footer: {
                    Text("Можно задать пробег, срок и моточасы. Сработает первое достигнутое условие.")
                }

                Section("Последний раз выполнено") {
                    TextField("Пробег", text: $lastMileage)
                        .keyboardType(.numberPad)
                    TextField("Моточасы на момент ТО", text: $lastEngineHours)
                        .keyboardType(.decimalPad)
                    DatePicker("Дата", selection: $lastDate, displayedComponents: .date)
                }

                Section("Заметка") {
                    TextField("Масло, артикулы, допуски и другое", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle(task == nil ? "Новая работа" : "Изменить работу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let kmInterval = Int(intervalKm.filter(\.isNumber)) ?? 0
        let monthInterval = Int(intervalMonths.filter(\.isNumber)) ?? 0
        let hourInterval = Double(intervalEngineHours.replacingOccurrences(of: ",", with: ".")) ?? 0
        let lastHours = Double(lastEngineHours.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard hourInterval.isFinite, lastHours.isFinite, hourInterval >= 0, lastHours >= 0 else {
            errorMessage = "Неверное значение моточасов."
            return
        }
        let mileage = Int(lastMileage.filter(\.isNumber)) ?? vehicle.currentMileage

        let savedTask: MaintenanceTask
        if let task {
            task.title = cleanTitle
            task.intervalKm = kmInterval
            task.intervalMonths = monthInterval
            task.intervalEngineHours = hourInterval
            task.lastEngineHours = lastHours
            task.lastMileage = mileage
            task.lastDate = lastDate
            task.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            savedTask = task
        } else {
            let newTask = MaintenanceTask(
                vehicleID: vehicle.id,
                title: cleanTitle,
                intervalKm: kmInterval,
                intervalMonths: monthInterval,
                intervalEngineHours: hourInterval,
                lastEngineHours: lastHours,
                lastMileage: mileage,
                lastDate: lastDate,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(newTask)
            savedTask = newTask
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Не удалось сохранить регламент: \(error.localizedDescription)"
            return
        }
        NotificationManager.shared.refresh(
            vehicle: vehicle,
            tasks: [savedTask],
            warningKm: warningKm,
            warningDays: warningDays
        )
        dismiss()
    }
}

private struct CompleteTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let vehicle: Vehicle
    let task: MaintenanceTask

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningDays") private var warningDays = 7
    @AppStorage("mileageReminderDays") private var mileageReminderDays = 30
    @State private var mileage: String
    @State private var engineHours: String
    @State private var parts = ""
    @State private var receiptItem: PhotosPickerItem?
    @State private var receiptImageData: Data?
    @State private var date = Date.now
    @State private var cost = ""
    @State private var currency = "EUR"
    @State private var notes = ""
    @State private var errorMessage: String?

    init(vehicle: Vehicle, task: MaintenanceTask) {
        self.vehicle = vehicle
        self.task = task
        _mileage = State(initialValue: String(vehicle.currentMileage))
        _engineHours = State(initialValue: String(vehicle.engineHours))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(task.title) {
                    TextField("Пробег", text: $mileage)
                        .keyboardType(.numberPad)
                    TextField("Моточасы", text: $engineHours)
                        .keyboardType(.decimalPad)
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                }

                Section("Расходы") {
                    TextField("Сумма (необязательно)", text: $cost)
                        .keyboardType(.decimalPad)
                    Picker("Валюта", selection: $currency) {
                        Text("EUR").tag("EUR")
                        Text("UAH").tag("UAH")
                        Text("USD").tag("USD")
                        Text("RUB").tag("RUB")
                    }
                }

                Section("Запчасти и чек") {
                    TextField("Артикулы, марки, номера деталей", text: $parts, axis: .vertical)
                        .lineLimit(2...5)
                    PhotosPicker(selection: $receiptItem, matching: .images) {
                        Label(receiptImageData == nil ? "Добавить фото чека" : "Заменить фото чека", systemImage: "doc.text.viewfinder")
                    }
                    if receiptImageData != nil {
                        Button("Удалить фото", role: .destructive) { receiptImageData = nil }
                    }
                }

                Section("Заметка") {
                    TextField("Что установлено или сделано", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .onChange(of: receiptItem) { _, item in
                Task {
                    do { receiptImageData = try await item?.loadTransferable(type: Data.self) }
                    catch { errorMessage = error.localizedDescription }
                }
            }
            .navigationTitle("Работа выполнена")
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
        guard let mileageValue = Int(mileage.filter(\.isNumber)) else {
            errorMessage = "Введи пробег цифрами."
            return
        }
        guard mileageValue >= task.lastMileage else {
            errorMessage = "Пробег не может быть меньше предыдущей работы."
            return
        }

        let normalizedCost = cost.replacingOccurrences(of: ",", with: ".")
        let costValue = Double(normalizedCost) ?? 0
        let hoursValue = Double(engineHours.replacingOccurrences(of: ",", with: ".")) ?? -1
        guard costValue.isFinite, costValue >= 0, hoursValue.isFinite, hoursValue >= task.lastEngineHours, hoursValue >= vehicle.engineHours else {
            errorMessage = "Проверь стоимость и моточасы."
            return
        }
        let record = ServiceRecord(
            vehicleID: vehicle.id,
            taskID: task.id,
            title: task.title,
            mileage: mileageValue,
            date: date,
            cost: costValue,
            currency: currency,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            parts: parts.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptImageData: receiptImageData
        )
        modelContext.insert(record)
        task.lastMileage = mileageValue
        task.lastDate = date
        task.lastEngineHours = hoursValue
        vehicle.engineHours = hoursValue

        let updatedVehicleMileage = mileageValue > vehicle.currentMileage
        if updatedVehicleMileage {
            vehicle.currentMileage = mileageValue
            modelContext.insert(MileageEntry(vehicleID: vehicle.id, mileage: mileageValue, date: date))
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Не удалось сохранить работу: \(error.localizedDescription)"
            return
        }
        NotificationManager.shared.refresh(
            vehicle: vehicle,
            tasks: [task],
            warningKm: warningKm,
            warningDays: warningDays
        )
        if updatedVehicleMileage {
            NotificationManager.shared.scheduleMileageEntryReminder(
                vehicle: vehicle,
                lastUpdate: date,
                afterDays: mileageReminderDays
            )
        }
        dismiss()
    }
}

struct ServiceRecordRow: View {
    let record: ServiceRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.title)
                    .font(.headline)
                Spacer()
                Text(Formatters.russianDate(record.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(Formatters.mileage(record.mileage))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if record.cost > 0 {
                Text(record.cost, format: .currency(code: record.currency))
                    .font(.subheadline.bold())
            }

            if !record.notes.isEmpty {
                Text(record.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
