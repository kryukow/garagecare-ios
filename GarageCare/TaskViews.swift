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
    @AppStorage("warningEngineHours") private var warningEngineHours = 10.0

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

                    if task.intervalMonths > 0 {
                        LabeledContent("По времени") {
                            Text("\(task.intervalMonths) мес.")
                        }
                        Divider()
                    }
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

                if let data = task.imageData, let image = UIImage(data: data) {
                    detailCard(title: "Фото работы") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 220)
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
            currentEngineHours: vehicle.engineHours,
            warningEngineHours: warningEngineHours
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
    @AppStorage("warningEngineHours") private var warningEngineHours = 10.0

    @State private var title: String
    @State private var intervalKm: String
    @State private var intervalMonths: String
    @State private var intervalEngineHours: String
    @State private var lastEngineHours: String
    @State private var lastMileage: String
    @State private var lastDate: Date
    @State private var notes: String
    @State private var imageData: Data?
    @State private var photoLoading = false
    @State private var useEngineHours: Bool
    @State private var useCalendar: Bool
    @State private var errorMessage: String?

    init(vehicle: Vehicle, task: MaintenanceTask? = nil) {
        self.vehicle = vehicle
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _useEngineHours = State(initialValue: (task?.intervalEngineHours ?? 0) > 0)
        _useCalendar = State(initialValue: (task?.intervalMonths ?? 0) > 0)
        _intervalKm = State(initialValue: task.map { $0.intervalKm > 0 ? String($0.intervalKm) : "" } ?? "")
        _intervalMonths = State(initialValue: task.map { $0.intervalMonths > 0 ? String($0.intervalMonths) : "" } ?? "")
        _intervalEngineHours = State(initialValue: task.map { $0.intervalEngineHours > 0 ? String($0.intervalEngineHours) : "" } ?? "")
        let startingHours = task?.lastEngineHours ?? vehicle.engineHours
        _lastEngineHours = State(initialValue: startingHours > 0 ? String(format: "%.1f", startingHours) : "")
        _lastMileage = State(initialValue: String(task?.lastMileage ?? vehicle.currentMileage))
        _lastDate = State(initialValue: task?.lastDate ?? .now)
        _notes = State(initialValue: task?.notes ?? "")
        _imageData = State(initialValue: task?.imageData)
    }

    private var parsedIntervals: (km: Int, months: Int, hours: Double, mileage: Int, lastHours: Double)? {
        guard let km = MaintenanceInput.integer(intervalKm, emptyValue: 0),
              let months = useCalendar ? MaintenanceInput.integer(intervalMonths) : 0,
              let hours = useEngineHours ? MaintenanceInput.decimal(intervalEngineHours) : 0,
              let mileage = MaintenanceInput.integer(lastMileage),
              let lastHours = MaintenanceInput.decimal(lastEngineHours, emptyValue: 0),
              (!useCalendar || months > 0), (!useEngineHours || hours > 0),
              km > 0 || months > 0 || hours > 0 else { return nil }
        return (km, months, hours, mileage, lastHours)
    }

    // Ordinary maintenance uses mileage and optionally engine hours.
    // Keep calendar intervals available only for HU/TÜV and existing calendar-based tasks.
    private var showsCalendarOption: Bool {
        (task?.intervalMonths ?? 0) > 0 ||
        title.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare("HU / TÜV") == .orderedSame
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        parsedIntervals != nil && !photoLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Работа") {
                    TextField("Название", text: $title)
                    Button("HU / TÜV — 24 месяца") {
                        title = "HU / TÜV"
                        useCalendar = true
                        useEngineHours = false
                        intervalMonths = "24"
                        intervalKm = ""
                        intervalEngineHours = ""
                    }
                }

                Section {
                    LabeledContent("Каждые, км") {
                        TextField("Например, 10000", text: $intervalKm)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("maintenance.intervalKm")
                    }
                    if let values = parsedIntervals, values.km > 0 {
                        Text("Следующая работа при \(Formatters.mileage(values.mileage + values.km)).")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Интервал до следующей работы")
                } footer: {
                    Text("Введи, через сколько километров повторять работу. Отсчёт идёт от пробега последнего выполнения.")
                }

                Section {
                    Toggle("Учитывать моточасы", isOn: $useEngineHours)
                    if useEngineHours {
                        LabeledContent("Каждые, мч") {
                            TextField("Например, 250", text: $intervalEngineHours)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    }
                    if showsCalendarOption {
                        Toggle("Учитывать календарный срок", isOn: $useCalendar)
                        if useCalendar {
                            LabeledContent("Каждые, мес.") {
                                TextField("Например, 24", text: $intervalMonths)
                                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                            }
                        }
                    }
                } header: {
                    Text("Дополнительные условия")
                } footer: {
                    Text("Для обычного ТО используй километры и, если нужно, моточасы. Календарный срок доступен для HU / TÜV и ранее созданных календарных работ.")
                }

                Section("Последний раз выполнено") {
                    LabeledContent("Пробег, км") {
                        TextField("Пробег", text: $lastMileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if useEngineHours || vehicle.engineHours > 0 || (task?.lastEngineHours ?? 0) > 0 {
                        LabeledContent("Моточасы, мч") {
                            TextField("Не заданы", text: $lastEngineHours)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    DatePicker("Дата", selection: $lastDate, displayedComponents: .date)
                }

                Section("Заметка") {
                    TextField("Масло, артикулы, допуски и другое", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
                ServicePhotoField(title: "Фото работы", data: $imageData, isLoading: $photoLoading)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
            }
            .garageKeyboardDismiss()
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
        guard canSave, let values = parsedIntervals else {
            errorMessage = "Проверь название, пробег и интервал."
            return
        }
        let kmInterval = values.km
        let monthInterval = values.months
        let hourInterval = values.hours
        let lastHours = values.lastHours
        let mileage = values.mileage

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
            task.imageData = imageData
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
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                imageData: imageData
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

struct CompleteTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let vehicle: Vehicle
    let task: MaintenanceTask

    @AppStorage("warningKm") private var warningKm = 1_000
    @AppStorage("warningDays") private var warningDays = 7
    @AppStorage("warningEngineHours") private var warningEngineHours = 10.0
    @AppStorage("mileageReminderDays") private var mileageReminderDays = 30
    @State private var mileage: String
    @State private var engineHours: String
    @State private var parts = ""
    @State private var receiptLoading = false
    @State private var photoLoading = false
    @State private var imageData: Data?
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
        let baselineHours = max(vehicle.engineHours, task.lastEngineHours)
        _engineHours = State(initialValue: baselineHours > 0 ? String(format: "%.1f", baselineHours) : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(task.title) {
                    LabeledContent("Пробег, км") {
                        TextField("Пробег", text: $mileage)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    if task.intervalEngineHours > 0 || vehicle.engineHours > 0 || task.lastEngineHours > 0 {
                        LabeledContent("Моточасы, мч") {
                            TextField("Не заданы", text: $engineHours)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                        }
                    }
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
                }
                ServicePhotoField(title: "Фото выполненной работы", data: $imageData, isLoading: $photoLoading)
                ServicePhotoField(title: "Фото чека", data: $receiptImageData, isLoading: $receiptLoading)

                Section("Заметка") {
                    TextField("Что установлено или сделано", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            .garageKeyboardDismiss()
            .scrollContentBackground(.hidden)
            .background(Color.garageBackground)
            .navigationTitle("Работа выполнена")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(photoLoading || receiptLoading)
                }
            }
        }
    }

    private func save() {
        guard !photoLoading, !receiptLoading, let mileageValue = MaintenanceInput.integer(mileage) else {
            errorMessage = "Введи пробег цифрами."
            return
        }
        guard mileageValue >= task.lastMileage else {
            errorMessage = "Пробег не может быть меньше предыдущей работы."
            return
        }

        let normalizedCost = cost.replacingOccurrences(of: ",", with: ".")
        guard let costValue = MaintenanceInput.decimal(normalizedCost, emptyValue: 0) else {
            errorMessage = "Введи стоимость цифрами или оставь поле пустым."
            return
        }
        let normalizedHours = engineHours.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let hoursValue = normalizedHours.isEmpty ? max(vehicle.engineHours, task.lastEngineHours) : (Double(normalizedHours) ?? -1)
        guard costValue.isFinite, costValue >= 0, hoursValue.isFinite, hoursValue >= task.lastEngineHours, hoursValue >= vehicle.engineHours else {
            errorMessage = "Проверь стоимость и моточасы."
            return
        }
        let record = ServiceRecord(
            vehicleID: vehicle.id,
            taskID: task.id,
            title: task.title,
            mileage: mileageValue,
            engineHours: hoursValue,
            date: date,
            cost: costValue,
            currency: currency,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            parts: parts.trimmingCharacters(in: .whitespacesAndNewlines),
            receiptImageData: receiptImageData,
            imageData: imageData
        )
        modelContext.insert(record)
        task.lastMileage = mileageValue
        task.lastDate = date
        task.lastEngineHours = hoursValue

        let updatedEngineHours = hoursValue > vehicle.engineHours
        let updatedVehicleMileage = mileageValue > vehicle.currentMileage
        vehicle.engineHours = max(vehicle.engineHours, hoursValue)
        if updatedVehicleMileage || updatedEngineHours {
            vehicle.currentMileage = max(vehicle.currentMileage, mileageValue)
            modelContext.insert(MileageEntry(vehicleID: vehicle.id, mileage: vehicle.currentMileage, engineHours: hoursValue, date: date))
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
        if updatedVehicleMileage || updatedEngineHours {
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

            HStack(spacing: 10) {
                Text(Formatters.mileage(record.mileage))
                if record.engineHours > 0 {
                    Text(String(format: "%.1f мч", record.engineHours))
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if record.cost > 0 {
                Text(record.cost, format: .currency(code: record.currency))
                    .font(.subheadline.bold())
            }

            if let data = record.imageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
                    .accessibilityLabel("Фото выполненной работы")
            }
            if let data = record.receiptImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160)
                    .accessibilityLabel("Фото чека")
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
