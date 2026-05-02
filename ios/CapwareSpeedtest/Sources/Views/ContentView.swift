import SwiftUI

// MARK: - Design tokens

extension Color {
    static let capSurface = Color(red: 0.98, green: 0.98, blue: 0.98)   // #fafafa
    static let capCard    = Color.white
    static let capBorder  = Color(red: 0.91, green: 0.89, blue: 0.89)   // #e7e4e4
    static let capText    = Color(red: 0.16, green: 0.14, blue: 0.14)   // #282424
    static let capSub     = Color(red: 0.47, green: 0.43, blue: 0.43)   // #786d6d
    static let capMuted   = Color(red: 0.71, green: 0.69, blue: 0.69)   // #b6afaf
    static let capAccent  = Color(red: 0.00, green: 0.81, blue: 0.81)   // #00cece ≈ brand cyan
    static let capAmber   = Color(red: 0.97, green: 0.65, blue: 0.12)   // ping color
    static let capDark    = Color(red: 0.10, green: 0.09, blue: 0.09)   // upload color
}

// MARK: - ContentView

struct ContentView: View {

    @ObservedObject var vm: SpeedTestViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 56)
                .padding(.bottom, 16)

            gaugeButton
                .frame(width: 264, height: 264)

            Spacer().frame(height: 16)

            bridge
                .padding(.horizontal, 24)
                .frame(height: 44)

            Spacer().frame(height: 16)

            resultTiles
                .padding(.horizontal, 20)

            Spacer().frame(height: 12)

            pingSection
                .padding(.horizontal, 20)

            Spacer().frame(height: 8)

            jitterSection
                .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.capSurface.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 3) {
            Text("Pulse Internet Speed Test")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.capText)
            if let isp = vm.ispName {
                Text(isp)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.capSub)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: vm.ispName)
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
    private var bridge: some View {
        switch vm.state {
        case .idle:
            Text("Tap the gauge to start")
                .font(.system(size: 13))
                .foregroundStyle(Color.capMuted)
                .frame(maxWidth: .infinity, alignment: .center)

        case .running(let phase):
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(phaseLabel(phase))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.capSub)
                    if phase == .download || phase == .upload {
                        HStack(spacing: 10) {
                            Text(String(format: "%.0f ms", vm.currentPingMs))
                                .foregroundStyle(Color.capAmber)
                            Text(String(format: "±%.0f ms", vm.currentJitterMs))
                                .foregroundStyle(Color.capMuted)
                        }
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .contentTransition(.numericText())
                    }
                }
                Spacer()
                Button("Cancel") { vm.reset() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.capSub)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.capCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.capBorder, lineWidth: 1))
            }

        case .done:
            HStack {
                Label("Test complete", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 0.12, green: 0.41, blue: 0.22))
                Spacer()
                Button("Run Again") { vm.reset() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.capText)
                    .clipShape(Capsule())
            }

        case .failed(let msg):
            HStack {
                Text(msg)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.41, green: 0.12, blue: 0.12))
                Spacer()
                Button("Try Again") { vm.reset() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color(red: 0.41, green: 0.12, blue: 0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private var resultTiles: some View {
        HStack(spacing: 12) {
            MetricTile(
                icon: "arrow.down.circle.fill",
                color: .capAccent,
                label: "DOWNLOAD",
                value: vm.downloadMbps.map { format($0) + " Mbps" },
                isActive: vm.activePhase == .download,
                liveValue: vm.activePhase == .download ? format(vm.currentMbps) + " Mbps" : nil
            )
            MetricTile(
                icon: "arrow.up.circle.fill",
                color: .capDark,
                label: "UPLOAD",
                value: vm.uploadMbps.map { format($0) + " Mbps" },
                isActive: vm.activePhase == .upload,
                liveValue: vm.activePhase == .upload ? format(vm.currentMbps) + " Mbps" : nil
            )
        }
    }

    private var pingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("PING", systemImage: "wifi")
            HStack(spacing: 0) {
                LatencyCell(label: "Unloaded", ms: vm.unloadedPingMs)
                dividerLine
                LatencyCell(label: "Download", ms: vm.downloadLoadedPingMs)
                dividerLine
                LatencyCell(label: "Upload", ms: vm.uploadLoadedPingMs)
            }
            .padding(.vertical, 10)
        }
        .background(Color.capCard)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.capBorder, lineWidth: 1))
    }

    private var jitterSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("JITTER", systemImage: "waveform")
            HStack(spacing: 0) {
                LatencyCell(label: "Unloaded", ms: vm.jitterMs)
                dividerLine
                LatencyCell(label: "Download", ms: vm.downloadJitterMs)
                dividerLine
                LatencyCell(label: "Upload", ms: vm.uploadJitterMs)
            }
            .padding(.vertical, 10)
        }
        .background(Color.capCard)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.capBorder, lineWidth: 1))
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .semibold))
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
        }
        .foregroundStyle(Color.capMuted)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    private var dividerLine: some View {
        Color.capBorder.frame(width: 1, height: 32)
    }


    // MARK: - Helpers

    private var isIdle: Bool {
        if case .idle = vm.state { return true }
        return false
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
        case .ping:     return "Measuring latency"
        case .download: return "Testing download"
        case .upload:   return "Testing upload"
        }
    }

    private func phaseColor(_ phase: TestPhase) -> Color {
        switch phase {
        case .ping:     return .capAmber
        case .download: return .capAccent
        case .upload:   return .capDark
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
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(isActive ? color : Color.capMuted)

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.capMuted)
                .tracking(1.5)

            Group {
                if let live = liveValue {
                    Text(live)
                        .foregroundStyle(color)
                        .contentTransition(.numericText())
                } else if let v = value {
                    Text(v)
                        .foregroundStyle(Color.capText)
                } else {
                    Text("—")
                        .foregroundStyle(Color.capMuted)
                }
            }
            .font(.system(size: 17, weight: .semibold, design: .rounded))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(isActive ? color.opacity(0.06) : Color.capCard)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isActive ? color.opacity(0.35) : Color.capBorder, lineWidth: 1)
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
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.capMuted)
                .tracking(0.8)
            if let ms {
                Text(String(format: "%.0f ms", ms))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(latencyColor(ms))
            } else {
                Text("—")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.capMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func latencyColor(_ ms: Double) -> Color {
        switch ms {
        case ..<20:  return Color(red: 0.12, green: 0.41, blue: 0.22)
        case ..<60:  return Color.capAccent
        case ..<150: return Color.capAmber
        default:     return Color(red: 0.80, green: 0.32, blue: 0.10)
        }
    }
}

#Preview {
    let store = HistoryStore()
    ContentView(vm: SpeedTestViewModel(history: store))
}
