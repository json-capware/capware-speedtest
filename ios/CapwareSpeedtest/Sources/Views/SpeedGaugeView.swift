import SwiftUI

struct SpeedGaugeView: View {

    @ObservedObject var vm: SpeedTestViewModel
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var s: CGFloat { sizeClass == .regular ? 1.25 : 1.0 }

    private let maxMbps: Double = 1000

    var body: some View {
        ZStack {
            // Track — full circle
            Circle()
                .stroke(Color.capBorder, style: StrokeStyle(lineWidth: 14, lineCap: .round))

            // Fill — starts at bottom center (6 o'clock), sweeps clockwise
            Circle()
                .trim(from: 0, to: fillEnd)
                .stroke(
                    LinearGradient(colors: arcColors, startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(90))   // 0° is 3 o'clock; +90° moves start to 6 o'clock
                .animation(.easeOut(duration: 0.25), value: fillEnd)

            centerContent
        }
    }

    // MARK: - Center

    @ViewBuilder
    private var centerContent: some View {
        switch vm.state {
        case .idle:
            VStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.system(size: 26 * s, weight: .regular))
                    .foregroundStyle(Color.capAccent)
                Text("TAP TO RUN")
                    .font(.system(size: 10 * s, weight: .semibold))
                    .foregroundStyle(Color.capMuted)
                    .tracking(2)
            }

        case .running(let phase):
            VStack(spacing: 2) {
                switch phase {
                case .ping:
                    Text(String(format: "%.0f", vm.currentPingMs))
                        .font(.system(size: 50 * s, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.capText)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: vm.currentPingMs)
                    Text("ms")
                        .font(.system(size: 14 * s, weight: .medium))
                        .foregroundStyle(Color.capSub)
                    Text("Latency")
                        .font(.system(size: 10 * s))
                        .foregroundStyle(Color.capMuted)
                        .padding(.top, 2)
                case .download, .upload:
                    Text(formatMbps(vm.currentMbps))
                        .font(.system(size: 50 * s, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.capText)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: vm.currentMbps)
                    Text("Mbps")
                        .font(.system(size: 14 * s, weight: .medium))
                        .foregroundStyle(Color.capSub)
                }
            }

        case .done(let result):
            VStack(spacing: 3) {
                Text(formatMbps(result.downloadMbps))
                    .font(.system(size: 46 * s, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.capText)
                Text("Mbps")
                    .font(.system(size: 13 * s, weight: .medium))
                    .foregroundStyle(Color.capSub)
                ResultBadge(mbps: result.downloadMbps)
                    .padding(.top, 6)
            }

        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32 * s, weight: .light))
                .foregroundStyle(Color(red: 0.80, green: 0.32, blue: 0.10))
        }
    }

    // MARK: - Arc helpers

    private var fillEnd: CGFloat {
        switch vm.state {
        case .idle, .failed:
            return 0
        case .running:
            return vm.progress
        case .done:
            return 1
        }
    }

    private var arcColors: [Color] {
        if case .done = vm.state {
            return [Color.capAccent, Color.capAccent]
        }
        switch vm.activePhase {
        case .ping:   return [Color.capAmber, Color(red: 0.95, green: 0.48, blue: 0.05)]
        case .upload: return [Color(red: 0.36, green: 0.33, blue: 0.33), Color.capDark]
        default:      return [Color.capAccent, Color(red: 0.00, green: 0.58, blue: 0.58)]
        }
    }

    private func formatMbps(_ v: Double) -> String {
        v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}
