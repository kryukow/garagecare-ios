import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: [SortDescriptor(\ServiceRecord.date, order: .reverse)])
    private var records: [ServiceRecord]
    @Query private var vehicles: [Vehicle]

    var body: some View {
        NavigationStack {
            ZStack {
                GarageScreenBackground()

                if records.isEmpty {
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.garageGreen.opacity(0.11))
                                .frame(width: 88, height: 88)

                            Image(systemName: "list.bullet.rectangle.portrait.fill")
                                .font(.system(size: 35, weight: .semibold))
                                .foregroundStyle(Color.garageGreen)
                        }

                        Text("История пуста")
                            .font(.title2.bold())

                        Text("Отмечай выполненные работы — они появятся здесь.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(28)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(records) { record in
                                HistoryCard(
                                    record: record,
                                    vehicle: vehicles.first(where: { $0.id == record.vehicleID })
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
        }
    }
}

private struct HistoryCard: View {
    let record: ServiceRecord
    let vehicle: Vehicle?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.garageGreen.opacity(0.12))
                        .frame(width: 42, height: 42)

                    Image(systemName: "checkmark")
                        .font(.headline.bold())
                        .foregroundStyle(Color.garageGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.headline)

                    Text(Formatters.russianDate(record.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if record.cost > 0 {
                    Text(record.cost, format: .currency(code: record.currency))
                        .font(.subheadline.bold())
                }
            }

            Divider()
                .overlay(Color.primary.opacity(0.06))

            HStack(spacing: 14) {
                Label(Formatters.mileage(record.mileage), systemImage: "road.lanes")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                if let vehicle {
                    Label(vehicle.displayName, systemImage: "car.side.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.garageGreen)
                        .lineLimit(1)
                }
            }

            if !record.notes.isEmpty {
                Text(record.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .garageCard(cornerRadius: 20)
    }
}
