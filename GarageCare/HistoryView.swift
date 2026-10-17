import PhotosUI
import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: [SortDescriptor(\ServiceRecord.date, order: .reverse)])
    private var records: [ServiceRecord]
    @Query private var vehicles: [Vehicle]
    @State private var recordToEdit: ServiceRecord?

    private var totalByCurrency: [String: Double] {
        Dictionary(grouping: records.filter { $0.cost > 0 }, by: \.currency)
            .mapValues { $0.reduce(0.0) { $0 + $1.cost } }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GarageScreenBackground()
                if records.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.rectangle.portrait.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(Color.garageGreen)
                        Text("История пуста").font(.title2.bold())
                        Text("Отмечай выполненные работы — они появятся здесь.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(28)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if !totalByCurrency.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("ВСЕ РАСХОДЫ НА ОБСЛУЖИВАНИЕ")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                    ForEach(totalByCurrency.keys.sorted(), id: \.self) { currency in
                                        Text((totalByCurrency[currency] ?? 0).formatted(.currency(code: currency)))
                                            .font(.title3.bold().monospacedDigit())
                                    }
                                    if totalByCurrency.count > 1 {
                                        Text("Разные валюты не суммируются без обменного курса.")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                                .garageCard(cornerRadius: 20)
                            }
                            ForEach(records) { record in
                                HistoryCard(
                                    record: record,
                                    vehicle: vehicles.first(where: { $0.id == record.vehicleID }),
                                    edit: { recordToEdit = record }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("История работ")
            .sheet(item: $recordToEdit) { record in
                ServiceRecordEditor(record: record)
            }
        }
    }
}

private struct HistoryCard: View {
    let record: ServiceRecord
    let vehicle: Vehicle?
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.garageGreen)
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title).font(.headline).foregroundStyle(.primary)
                    Text(Formatters.russianDate(record.date))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if record.cost > 0 {
                    Text(record.cost, format: .currency(code: record.currency))
                        .font(.subheadline.bold()).foregroundStyle(.primary)
                }
                Button(action: edit) {
                    Image(systemName: "pencil")
                        .font(.body)
                        .frame(width: 44, height: 44)
                }
                .foregroundStyle(Color.garageGreen)
                .accessibilityLabel("Изменить запись")
            }
            Divider()
            HStack(spacing: 14) {
                Label(Formatters.mileage(record.mileage), systemImage: "road.lanes")
                if record.engineHours > 0 {
                    Label(String(format: "%.1f мч", record.engineHours), systemImage: "gauge.with.dots.needle.50percent")
                }
                if let vehicle { Label(vehicle.displayName, systemImage: "car.side.fill") }
            }
            .font(.caption).foregroundStyle(.secondary)
            if !record.parts.isEmpty {
                Label(record.parts, systemImage: "wrench.adjustable")
                    .font(.subheadline).foregroundStyle(.primary)
            }
            if !record.notes.isEmpty {
                Text(record.notes).font(.subheadline).foregroundStyle(.secondary)
            }
            GaragePhotoStrip(title: "Фото работы", primary: record.imageData, additional: record.extraPhotoData)
            GaragePhotoStrip(title: "Чеки", primary: record.receiptImageData, additional: record.extraReceiptData, height: 95)
        }
        .padding(16)
        .garageCard(cornerRadius: 20)
    }
}

private struct ServiceRecordEditor: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let record: ServiceRecord

    @State private var title: String
    @State private var mileage: String
    @State private var engineHours: String
    @State private var date: Date
    @State private var cost: String
    @State private var currency: String
    @State private var notes: String
    @State private var parts: String
    @State private var receiptData: Data?
    @State private var extraReceiptData: Data?
    @State private var imageData: Data?
    @State private var extraPhotoData: Data?
    @State private var photoLoading = false
    @State private var receiptLoading = false
    @State private var errorMessage: String?

    init(record: ServiceRecord) {
        self.record = record
        _title = State(initialValue: record.title)
        _mileage = State(initialValue: String(record.mileage))
        _engineHours = State(initialValue: record.engineHours > 0 ? String(format: "%.1f", record.engineHours) : "")
        _date = State(initialValue: record.date)
        _cost = State(initialValue: record.cost > 0 ? String(record.cost) : "")
        _currency = State(initialValue: record.currency)
        _notes = State(initialValue: record.notes)
        _parts = State(initialValue: record.parts)
        _receiptData = State(initialValue: record.receiptImageData)
        _extraReceiptData = State(initialValue: record.extraReceiptData)
        _imageData = State(initialValue: record.imageData)
        _extraPhotoData = State(initialValue: record.extraPhotoData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Работа") {
                    TextField("Название", text: $title)
                    LabeledContent("Пробег, км") {
                        TextField("Пробег", text: $mileage).keyboardType(.numberPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Моточасы") {
                        TextField("Не заданы", text: $engineHours)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    DatePicker("Дата", selection: $date, displayedComponents: .date)
                }
                Section("Расходы") {
                    LabeledContent("Стоимость") {
                        TextField("Необязательно", text: $cost).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    Picker("Валюта", selection: $currency) {
                        ForEach(["EUR", "USD", "UAH", "RUB"], id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }
                Section("Запчасти") {
                    TextField("Марки, артикулы и детали", text: $parts, axis: .vertical)
                        .lineLimit(2...5)
                }
                ServicePhotoField(title: "Фото выполненной работы", data: $imageData, additionalData: $extraPhotoData, isLoading: $photoLoading)
                ServicePhotoField(title: "Фото чека", data: $receiptData, additionalData: $extraReceiptData, isLoading: $receiptLoading)
                Section("Заметка") {
                    TextField("Дополнительные сведения", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .garageKeyboardDismiss()
            .navigationTitle("Изменить запись")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить", action: save).disabled(photoLoading || receiptLoading) }
            }
        }
    }

    private func save() {
        guard !photoLoading, !receiptLoading, let mileageValue = MaintenanceInput.integer(mileage),
              let costValue = MaintenanceInput.decimal(cost, emptyValue: 0),
              costValue.isFinite, costValue >= 0,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Проверь название, пробег и стоимость."
            return
        }
        let normalizedHours = engineHours.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        let hours = normalizedHours.isEmpty ? 0.0 : (Double(normalizedHours) ?? -1)
        guard hours.isFinite, hours >= 0 else {
            errorMessage = "Проверь моточасы."
            return
        }
        record.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        record.mileage = mileageValue
        record.engineHours = hours
        record.date = date
        record.cost = costValue
        record.currency = currency
        record.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        record.parts = parts.trimmingCharacters(in: .whitespacesAndNewlines)
        record.receiptImageData = receiptData
        record.extraReceiptData = extraReceiptData
        record.imageData = imageData
        record.extraPhotoData = extraPhotoData
        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "Не удалось сохранить запись: \(error.localizedDescription)"
        }
    }
}
