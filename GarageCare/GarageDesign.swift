import SwiftUI

struct GarageProgressBar: View {
    let progress: Double
    let color: Color

    private var safeProgress: Double {
        min(max(progress.isFinite ? progress : 0, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(color)
                    .frame(width: max(proxy.size.width * safeProgress, safeProgress > 0 ? 8 : 0))
                    .shadow(color: color.opacity(0.34), radius: 7, y: 1)
            }
        }
        .frame(height: GarageTokens.Size.progressBarHeight)
        .accessibilityValue("\(Int((safeProgress * 100).rounded())) процентов")
    }
}

struct GarageStatusPill: View {
    let title: String
    let color: Color
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: GarageTokens.Size.statusDot, height: GarageTokens.Size.statusDot)
                    .shadow(color: color.opacity(0.5), radius: 5)
            }

            Text(title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: Capsule())
        .overlay {
            Capsule()
                .stroke(color.opacity(0.20), lineWidth: 1)
        }
    }
}

struct GarageCardModifier: ViewModifier {
    var cornerRadius: CGFloat = GarageTokens.Radius.large

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.garageSurface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.garageStroke, lineWidth: 1)
            }
            .shadow(color: GarageTokens.Shadow.cardColor, radius: GarageTokens.Shadow.cardRadius, y: GarageTokens.Shadow.cardY)
    }
}

extension View {
    func garageCard(cornerRadius: CGFloat = GarageTokens.Radius.large) -> some View {
        modifier(GarageCardModifier(cornerRadius: cornerRadius))
    }
}

struct GarageScreenBackground: View {
    var body: some View {
        ZStack {
            Color.garageBackground

            LinearGradient(
                colors: [
                    Color.garageGreen.opacity(GarageTokens.Opacity.backgroundAccent),
                    Color.clear,
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

extension MaintenanceTask {
    func displayProgress(currentMileage: Int, currentEngineHours: Double = 0) -> Double {
        let value = progress(currentMileage: currentMileage, currentEngineHours: currentEngineHours)
        return value.isFinite ? min(max(value, 0), 1) : 0
    }

    func displayColor(currentMileage: Int, warningKm: Int, warningDays: Int, currentEngineHours: Double = 0) -> Color {
        let dueState = state(
            currentMileage: currentMileage,
            warningKm: warningKm,
            warningDays: warningDays,
            currentEngineHours: currentEngineHours
        )
        return Color.maintenanceStatus(
            progress: displayProgress(currentMileage: currentMileage, currentEngineHours: currentEngineHours),
            state: dueState
        )
    }
}


private struct GarageAdaptiveTabBarModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            // When linked with the iOS 27 SDK, the standard SwiftUI tab bar
            // adopts the system Liquid Glass appearance automatically.
            content
        } else {
            content
                .toolbarBackground(Color.garageSurface, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
        }
    }
}

extension View {
    func garageAdaptiveTabBar() -> some View {
        modifier(GarageAdaptiveTabBarModifier())
    }
}


/// Closes numeric keyboards both on scroll and with an explicit Done control.
private struct GarageKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Готово") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil,
                            from: nil,
                            for: nil
                        )
                    }
                }
            }
    }
}

extension View {
    func garageKeyboardDismiss() -> some View {
        modifier(GarageKeyboardDismissModifier())
    }
}
