import SwiftUI

struct SpeedGaugeView: View {

    let mbps: Double
    let progress: Double
    let isRunning: Bool

    private let maxMbps: Double = 1000

    var body: some View {
        ZStack {
            // Track
            Circle()
                .trim(from: 0.1, to: 0.9)
                .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))

            // Fill
            Circle()
                .trim(from: 0.1, to: 0.1 + 0.8 * min(mbps / maxMbps, 1))
                .stroke(
                    LinearGradient(
                        colors: [.cyan, .blue, .indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
                .animation(.easeOut(duration: 0.3), value: mbps)

            VStack(spacing: 4) {
                if isRunning || mbps > 0 {
                    Text(String(format: "%.1f", mbps))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.25), value: mbps)
                    Text("Mbps")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text("TAP")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("to test")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
    }
}
