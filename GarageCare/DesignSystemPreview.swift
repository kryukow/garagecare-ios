#if DEBUG
import SwiftUI

struct GarageDesignSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GarageTokens.Spacing.lg) {
                Text("GarageCare Design System")
                    .font(.title.bold())

                HStack(spacing: GarageTokens.Spacing.xs) {
                    GarageStatusPill(title: "В НОРМЕ", color: .garageGreen)
                    GarageStatusPill(title: "СКОРО", color: .garageOrange)
                    GarageStatusPill(title: "ПРОСРОЧЕНО", color: .garageRed)
                }

                VStack(alignment: .leading, spacing: GarageTokens.Spacing.sm) {
                    Text("Прогресс обслуживания")
                        .font(.headline)
                    GarageProgressBar(progress: 0.28, color: .garageGreen)
                    GarageProgressBar(progress: 0.68, color: .garageYellow)
                    GarageProgressBar(progress: 0.88, color: .garageOrange)
                }
                .padding(GarageTokens.Spacing.md)
                .garageCard()

                Button("Основное действие") {}
                    .font(.headline)
                    .foregroundStyle(Color.garageOnAccent)
                    .frame(maxWidth: .infinity, minHeight: GarageTokens.Size.minimumTouchTarget)
                    .background(Color.garageGreen, in: RoundedRectangle(cornerRadius: GarageTokens.Radius.medium))

                HStack(spacing: GarageTokens.Spacing.sm) {
                    swatch("Accent", .garageGreen)
                    swatch("Warning", .garageOrange)
                    swatch("Danger", .garageRed)
                }
            }
            .padding(GarageTokens.Spacing.md)
        }
        .background(GarageScreenBackground())
    }

    private func swatch(_ title: String, _ color: Color) -> some View {
        VStack(spacing: GarageTokens.Spacing.xs) {
            RoundedRectangle(cornerRadius: GarageTokens.Radius.small)
                .fill(color)
                .frame(height: 54)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("GarageCare Design System") {
    GarageDesignSystemPreview()
}
#endif
