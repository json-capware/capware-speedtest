import SwiftUI

@main
struct CapwareSpeedtestApp: App {
    @StateObject private var history = HistoryStore()

    var body: some Scene {
        WindowGroup {
            RootView(history: history)
        }
    }
}

struct RootView: View {
    @ObservedObject var history: HistoryStore
    @StateObject private var vm: SpeedTestViewModel
    @State private var selectedTab = 0

    init(history: HistoryStore) {
        self.history = history
        _vm = StateObject(wrappedValue: SpeedTestViewModel(history: history))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content area — fully bounded, never overlaps tab bar
            ZStack {
                ContentView(vm: vm).opacity(selectedTab == 0 ? 1 : 0)
                HistoryView(history: history).opacity(selectedTab == 1 ? 1 : 0)
                SettingsView(history: history).opacity(selectedTab == 2 ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            AppTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Custom tab bar

struct AppTabBar: View {
    @Binding var selectedTab: Int

    private let items: [(label: String, icon: String)] = [
        ("Test",     "gauge.with.dots.needle.67percent"),
        ("History",  "clock"),
        ("Settings", "gearshape"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                Button {
                    selectedTab = i
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].icon)
                            .font(.system(size: 20))
                        Text(items[i].label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == i ? Color.capAccent : Color.capMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            Color.capCard
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .safeAreaPadding(.bottom)
    }
}
