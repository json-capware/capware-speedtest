import SwiftUI

struct ContentView: View {

    @StateObject private var vm = SpeedTestViewModel()

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header.padding(.top, 56)

                Spacer()

                // Central gauge
                gaugeButton
                    .frame(width: 260, height: 260)

                Spacer().frame(height: 28)

                // Status / progress
                statusArea.frame(height: 48)

                Spacer()

                // Three result tiles
                resultTiles.padding(.horizontal, 24)

                Spacer()

                // Latency pair
                if showLatency {
                    latencyRow.padding(.bottom, 20)
                }

                // Bottom action
                bottomAction.padding(.bottom, 48)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: stateTag)
    }

    // MARK: - Subviews

    private var background: some View {
        LinearGradient(
            colors: [Color(red: 0.04, green: 0.06, blue: 0.14),
                     Color(red: 0.06, green: 0.10, blue: 0.24)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 3) {
            Text("CAPWARE")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(4)
            Text("Speed Test")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var gaugeButton: some View {
        Button {
            if case .idle = vm.state { vm.run() }
        } label: {
            SpeedGaugeView(vm: vm)
        }
        .buttonStyle(.plain)
        .disabled(!isIdle)
    }

    @ViewBuilder
    private var statusArea: some View {
        switch vm.state {
        case .idle:
            Text("Tap to start")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.3))

        case .running(let phase):
            VStack(spacing: 6) {
                ProgressView(value: vm.progress).tint(phaseColor(phase)).frame(width: 180)
                Text(phaseLabel(phase))
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }

        case .done:
            Label("Complete", systemImage: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.green)

        case .failed(let msg):
            Text(msg)
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var resultTiles: some View {
        HStack(spacing: 12) {
            MetricTile(
                icon: "arrow.down.circle.fill",
                color: .cyan,
                label: "Download",
                value: vm.downloadMbps.map { format($0) + " Mbps" },
                isActive: vm.activePhase == .download,
                liveValue: vm.activePhase == .download ? format(vm.currentMbps) + " Mbps" : nil
            )
            MetricTile(
                icon: "arrow.up.circle.fill",
                color: .indigo,
                label: "Upload",
                value: vm.uploadMbps.map { format($0) + " Mbps" },
                isActive: vm.activePhase == .upload,
                liveValue: vm.activePhase == .upload ? format(vm.currentMbps) + " Mbps" : nil
            )
        }
    }

    private var latencyRow: some View {
        HStack(spacing: 32) {
            LatencyCell(label: "Unloaded", ms: vm.unloadedPingMs)
            LatencyCell(label: "Loaded DL", ms: vm.downloadLoadedPingMs)
            LatencyCell(label: "Loaded UL", ms: vm.uploadLoadedPingMs)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 24)
        .background(.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    @ViewBuilder
    private var bottomAction: some View {
        switch vm.state {
        case .idle:
            EmptyView()
        case .running:
            Button("Cancel") { vm.reset() }
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.35))
        case .done, .failed:
            Button {
                vm.reset()
            } label: {
                Text("Test Again")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 180, height: 48)
                    .background(.white.opacity(0.1))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
            }
        }
    }

    // MARK: - Helpers

    private var isIdle: Bool {
        if case .idle = vm.state { return true }
        return false
    }

    private var showLatency: Bool {
        vm.unloadedPingMs != nil
    }

    private var stateTag: Int {
        switch vm.state {
        case .idle:    return 0
        case .running: return 1
        case .done:    return 2
        case .failed:  return 3
        }
    }

    private func phaseLabel(_ phase: TestPhase) -> String {
        switch phase {
        case .ping:     return "Measuring latency…"
        case .download: return "Testing download…"
        case .upload:   return "Testing upload…"
        }
    }

    private func phaseColor(_ phase: TestPhase) -> Color {
        switch phase {
        case .ping:     return .yellow
        case .download: return .cyan
        case .upload:   return .indigo
        }
    }

    private func format(_ mbps: Double) -> String {
        mbps >= 100 ? String(format: "%.0f", mbps) : String(format: "%.1f", mbps)
    }
}

// MARK: - MetricTile

struct MetricTile: View {
    let icon: String
    let color: Color
    let label: String
    let value: String?
    let isActive: Bool
    let liveValue: String?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(isActive ? color : color.opacity(0.5))

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .tracking(1)

            if let live = liveValue {
                Text(live)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
            } else if let v = value {
                Text(v)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Text("—")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(isActive ? color.opacity(0.12) : .white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isActive ? color.opacity(0.4) : .clear, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

// MARK: - LatencyCell

struct LatencyCell: View {
    let label: String
    let ms: Double?

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(0.5)
            if let ms {
                Text(String(format: "%.0f ms", ms))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(latencyColor(ms))
            } else {
                Text("—")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }

    private func latencyColor(_ ms: Double) -> Color {
        switch ms {
        case ..<20:  return .green
        case ..<60:  return .cyan
        case ..<150: return .yellow
        default:     return .orange
        }
    }
}

#Preview {
    ContentView()
}
