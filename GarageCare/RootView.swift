import SwiftUI

struct RootView: View {
    @AppStorage("appearanceMode") private var appearanceMode = AppAppearance.system.rawValue

    private var appearance: AppAppearance {
        AppAppearance(rawValue: appearanceMode) ?? .system
    }

    var body: some View {
        TabView {
            GarageView()
                .tabItem {
                    Label("Гараж", systemImage: "car.fill")
                }

            HistoryView()
                .tabItem {
                    Label("История", systemImage: "list.bullet.rectangle.portrait.fill")
                }

            FuelTabView()
                .tabItem {
                    Label("Заправки", systemImage: "fuelpump.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Настройки", systemImage: "gearshape.fill")
                }
        }
        .tint(.garageGreen)
        .garageAdaptiveTabBar()
        .preferredColorScheme(appearance.colorScheme)
        .environment(\.locale, Locale(identifier: "ru_RU"))
    }
}
