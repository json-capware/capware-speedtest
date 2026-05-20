import SwiftUI

// MARK: - Root

struct TVRootView: View {
    @ObservedObject var history: HistoryStore
    @StateObject private var vm: SpeedTestViewModel
    @State private var showHistory = false

    init(history: HistoryStore) {
        self.history = history
        _vm = StateObject(wrappedValue: SpeedTestViewModel(history: history))
    }

    var body: some View {
        ZStack {
            Color.capSurface.ignoresSafeArea()
            if showHistory {
                TVHistoryView(history: history, showHistory: $showHistory)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                TVTestView(vm: vm, showHistory: $showHistory)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showHistory)
    }
}

// MARK: - Test View

struct TVTestView: View {
    @ObservedObject var vm: SpeedTestViewModel
    @Binding var showHistory: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 80) {

            // Left column: gauge + controls
            VStack(spacing: 40) {
                Text("Pulse Speed Test")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.capText)

                Button {
                    switch vm.state {
                    case .idle:             vm.run()
                    case .done, .failed:    vm.reset()
                    case .running:          break
                    }
                } label: {
                    SpeedGaugeView(vm: vm)
                        .frame(width: 420, height: 420)
                }
                .buttonStyle(TVGaugeButtonStyle())
                .disabled(isRunning)

                // Status / phase label
                statusLabel
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.capMuted)
                    .frame(height: 36)

                // ISP name
                if let isp = vm.ispName {
                    Text(isp)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(Color.capSub)
                }

                // History button — only visible at rest
                if !isRunning {
                    Button("View History") { showHistory = true }
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color.capSub)
                        .padding(.top, 8)
                }
            }
            .frame(maxWidth: 600)

            // Right column: result panels (slide in when done)
            if hasResults {
                TVResultPanel(vm: vm)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .frame(maxWidth: 480)
            }
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasResults)
    }

    // MARK: Helpers

    private var isRunning: Bool {
        if case .running = vm.state { return true }
        return false
    }

    private var hasResults: Bool {
        if case .done = vm.state { return true }
        return false
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch vm.state {
        case .idle:
            Text("Press \u{25B6} to start")
        case .running(let phase):
            Text(phaseLabel(phase))
                .foregroundStyle(Color.capSub)
        case .done:
            Text("Press \u{25B6} to run again")
        case .failed(let msg):
            Text(msg)
                .foregroundStyle(Color.capError)
        }
    }

    private func phaseLabel(_ phase: TestPhase) -> String {
        switch phase {
        case .ping:     return "Measuring latency\u{2026}"
        case .download: return "Testing download\u{2026}"
        case .upload:   return "Testing upload\u{2026}"
        }
    }
}

// MARK: - Result Panel

struct TVResultPanel: View {
    @ObservedObject var vm: SpeedTestViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TVMetricRow(
                icon: "arrow.down.circle.fill",
                label: "Download",
                value: vm.downloadMbps,
                unit: "Mbps",
                color: .capAccent
            )
            Divider().background(Color.capBorder).padding(.vertical, 4)
            TVMetricRow(
                icon: "arrow.up.circle.fill",
                label: "Upload",
                value: vm.uploadMbps,
                unit: "Mbps",
                color: .capDark
            )
            Divider().background(Color.capBorder).padding(.vertical, 16)
            TVLatencyRow(label: "Ping",   value: vm.unloadedPingMs)
            TVLatencyRow(label: "Jitter", value: vm.jitterMs)
        }
        .padding(40)
        .background(Color.capCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.capBorder, lineWidth: 1))
    }
}

struct TVMetricRow: View {
    let icon: String
    let label: String
    let value: Double?
    let unit: String
    let color: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(label.uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.capMuted)
                    .tracking(1.5)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(value.map { format($0) } ?? "\u{2014}")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(value != nil ? Color.capText : Color.capMuted)
                    if value != nil {
                        Text(unit)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(Color.capSub)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private func format(_ v: Double) -> String {
        v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

struct TVLatencyRow: View {
    let label: String
    let value: Double?

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(Color.capSub)
            Spacer()
            Text(value.map { String(format: "%.0f ms", $0) } ?? "\u{2014}")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(value != nil ? Color.capText : Color.capMuted)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - History View

struct TVHistoryView: View {
    @ObservedObject var history: HistoryStore
    @Binding var showHistory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 40) {
            HStack {
                Button("Back") { showHistory = false }
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.capAccent)
                Text("History")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.capText)
                    .padding(.leading, 24)
                Spacer()
            }

            if history.records.isEmpty {
                Spacer()
                Text("No tests yet")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.capMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(history.records) { record in
                            TVHistoryRow(record: record)
                        }
                    }
                }
            }
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TVHistoryRow: View {
    let record: TestRecord

    var body: some View {
        HStack(spacing: 40) {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.date, style: .date)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.capText)
                if let isp = record.ispName {
                    Text(isp)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.capMuted)
                }
            }
            .frame(minWidth: 200, alignment: .leading)

            Spacer()

            TVStatChip(label: "↓", value: record.downloadMbps, color: .capAccent)
            TVStatChip(label: "↑", value: record.uploadMbps,   color: .capDark)
            TVStatChip(label: "ms", value: record.pingMs,       color: .capAmber)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(Color.capCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.capBorder, lineWidth: 1))
    }
}

struct TVStatChip: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(value >= 100 ? String(format: "%.0f", value) : String(format: "%.1f", value))
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Color.capText)
        }
        .frame(minWidth: 100, alignment: .trailing)
    }
}

// MARK: - Button Style

struct TVGaugeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
