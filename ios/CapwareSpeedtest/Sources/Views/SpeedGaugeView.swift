import SwiftUI

struct SpeedGaugeView: View {

    @ObservedObject var vm: SpeedTestViewModel

    private let maxMbps: Double = 1000

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0.1, to: 0.9)
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(135))

            // Active fill
            Circle()
                .trim(from: 0.1, to: fillEnd)
                .stroke(
                    LinearGradient(colors: arcColors, startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .animation(.easeOut(duration: 0.25), value: fillEnd)

            // Center content
            centerContent
        }
    }

    // MARK: - Center

    @ViewBuilder
    private var centerContent: some View {
        switch vm.state {
        case .idle:
            VStack(spacing: 4) {
                Image(systemName: "wifi")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white.opacity(0.3))
                Text("TAP TO TEST")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
                    .tracking(2)
            }

        case .running(let phase):
            VStack(spacing: 2) {
                switch phase {
                case .ping:
                    Text(String(format: "%.0f", vm.currentPingMs))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: vm.currentPingMs)
                    Text("ms")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("Unloaded latency")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.top, 2)
                case .download, .upload:
                    Text(formatMbps(vm.currentMbps))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.2), value: vm.currentMbps)
                    Text("Mbps")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

        case .done(let result):
            VStack(spacing: 2) {
                Text(formatMbps(result.downloadMbps))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Mbps")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                ResultBadge(mbps: result.downloadMbps)
                    .padding(.top, 6)
            }

        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Arc helpers

    private var fillEnd: CGFloat {
        switch vm.state {
        case .idle, .failed:
            return 0.1
        case .running(let phase):
            let ratio: Double = phase == .ping
                ? min(vm.currentPingMs / 300, 1)
                : min(vm.currentMbps / maxMbps, 1)
            return 0.1 + 0.8 * ratio
        case .done(let r):
            return 0.1 + 0.8 * min(r.downloadMbps / maxMbps, 1)
        }
    }

    private var arcColors: [Color] {
        switch vm.activePhase {
        case .ping:     return [.yellow, .orange]
        case .upload:   return [.purple, .indigo]
        default:        return [.cyan, .blue, .indigo]
        }
    }

    private func formatMbps(_ v: Double) -> String {
        v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}
