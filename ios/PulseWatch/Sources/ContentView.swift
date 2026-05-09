import SwiftUI

// MARK: - Design tokens (mirrored from iOS app)

private extension Color {
    static let capSurface = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let capBorder  = Color(red: 0.91, green: 0.89, blue: 0.89)
    static let capText    = Color(red: 0.16, green: 0.14, blue: 0.14)
    static let capSub     = Color(red: 0.47, green: 0.43, blue: 0.43)
    static let capMuted   = Color(red: 0.71, green: 0.69, blue: 0.69)
    static let capAccent  = Color(red: 0.00, green: 0.81, blue: 0.81)
    static let capAmber   = Color(red: 0.97, green: 0.65, blue: 0.12)
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var session = WatchSessionManager.shared

    var body: some View {
        ZStack {
            Color.capSurface.ignoresSafeArea()
            gauge
        }
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.3), value: session.phase)
    }

    // MARK: - Gauge

    @ViewBuilder
    private var gauge: some View {
        switch session.phase {
        case .idle:
            GaugeRing(fill: 0, colors: [.capAccent, .capAccent]) {
                Button { session.startTest() } label: {
                    idleCenter
                }
                .buttonStyle(.plain)
            }

        case .testing(let label, let currentValue, let progress):
            GaugeRing(fill: progress, colors: [.capAccent, Color(red: 0.00, green: 0.58, blue: 0.58)]) {
                testingCenter(label: label, value: currentValue)
            }

        case .done(let dl, let ul, let ping, let jitter):
            resultsView(dl: dl, ul: ul, ping: ping, jitter: jitter)

        case .failed(let msg):
            GaugeRing(fill: 0, colors: [.capAccent, .capAccent]) {
                failedCenter(msg)
            }
        }
    }

    // MARK: - Center content

    private var idleCenter: some View {
        VStack(spacing: 5) {
            Image(systemName: "play.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.capAccent)
            Text("TAP TO RUN")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.capMuted)
                .tracking(1.5)
        }
    }

    private func testingCenter(label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(label == "Measuring latency"
                 ? (value > 0 ? String(format: "%.0f", value) : "—")
                 : formatMbps(value))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.capText)
                .contentTransition(.numericText())
            Text(label == "Measuring latency" ? "ms" : "Mbps")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.capSub)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(Color.capMuted)
                .padding(.top, 1)
        }
    }

    private func resultsView(dl: Double, ul: Double, ping: Double, jitter: Double) -> some View {
        ScrollView {
            VStack(spacing: 4) {
                VStack(spacing: 1) {
                    Text(formatMbps(dl))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.capText)
                    Text("Mbps  ↓")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.capSub)
                }
                .padding(.top, 6)

                Divider().padding(.horizontal, 14).padding(.vertical, 2)

                WatchStatRow(label: "Upload", value: formatMbps(ul) + " ↑")
                WatchStatRow(label: "Ping",   value: String(format: "%.0f ms", ping))
                WatchStatRow(label: "Jitter", value: String(format: "%.0f ms", jitter))

                Button("Test Again") { session.reset() }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.capAccent)
                    .padding(.top, 6)
                    .padding(.bottom, 4)
            }
        }
        .focusable()
    }

    private func failedCenter(_ msg: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Color.capAmber)
            Text(msg)
                .font(.system(size: 9))
                .foregroundStyle(Color.capSub)
                .multilineTextAlignment(.center)
            Button("Retry") { session.reset() }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.capAccent)
        }
        .padding(.horizontal, 8)
    }

    private func formatMbps(_ v: Double) -> String {
        v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

// MARK: - GaugeRing

/// Reusable gauge ring with a static arc fill and arbitrary center content.
private struct GaugeRing<Center: View>: View {
    let fill: CGFloat
    let colors: [Color]
    @ViewBuilder let center: () -> Center

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(
                    Color.capBorder,
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )

            // Fill arc
            if fill > 0 {
                Circle()
                    .trim(from: 0, to: fill)
                    .stroke(
                        LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(90))
            }

            center()
        }
        .padding(14)
    }
}

// MARK: - WatchStatRow

private struct WatchStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color.capMuted)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.capText)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ContentView()
}
