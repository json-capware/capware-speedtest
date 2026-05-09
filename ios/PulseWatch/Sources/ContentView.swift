import SwiftUI

// Colours live in Shared/DesignTokens.swift — watchOS uses hardcoded dark values

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var session = WatchSessionManager.shared

    var body: some View {
        ZStack {
            Color.capSurface.ignoresSafeArea()
            gauge
        }
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .preferredColorScheme(.light)
        .animation(.easeInOut(duration: 0.3), value: session.phase)
    }

    // MARK: - Gauge switcher

    @ViewBuilder
    private var gauge: some View {
        switch session.phase {
        case .idle:
            GaugeRing(fill: 0, colors: [.capAccent, .capAccent]) {
                Button { session.startTest() } label: { idleCenter }
                    .buttonStyle(.plain)
            }

        case .testing(let label, let currentValue, let progress):
            GaugeRing(
                fill: progress,
                colors: [.capAccent, Color(red: 0.00, green: 0.58, blue: 0.58)]
            ) {
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

    // MARK: - Idle center

    private var idleCenter: some View {
        VStack(spacing: 6) {
            Image(systemName: "play.fill")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.capAccent)
            Text("TAP TO RUN")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Color.capMuted)
                .tracking(2)
        }
    }

    // MARK: - Testing center

    private func testingCenter(label: String, value: Double) -> some View {
        let isPing = label == "Measuring latency"
        return VStack(spacing: 2) {
            Text(isPing
                 ? (value > 0 ? String(format: "%.0f", value) : "—")
                 : formatMbps(value))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(Color.capText)
                .contentTransition(.numericText())
            Text(isPing ? "ms" : "Mbps")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.capSub)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(Color.capMuted)
                .padding(.top, 1)
        }
    }

    // MARK: - Results — single screen, no scroll

    private func resultsView(dl: Double, ul: Double, ping: Double, jitter: Double) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 1) {
                Text(formatMbps(dl))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.capText)
                Text("Mbps  ↓")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.capSub)
            }
            .padding(.bottom, 6)

            Color.capBorder.frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            WatchStatRow(label: "Upload", value: formatMbps(ul) + " ↑")
            WatchStatRow(label: "Ping",   value: String(format: "%.0f ms", ping))
            WatchStatRow(label: "Jitter", value: String(format: "%.0f ms", jitter))

            Button("Test Again") { session.reset() }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.capAccent)
                .padding(.top, 8)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Failed center

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

private struct GaugeRing<Center: View>: View {
    let fill: CGFloat
    let colors: [Color]
    @ViewBuilder let center: () -> Center

    var body: some View {
        GeometryReader { geo in
            let diameter = min(geo.size.width, geo.size.height) - 16
            ZStack {
                Circle()
                    .stroke(Color.capBorder,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))

                if fill > 0 {
                    Circle()
                        .trim(from: 0, to: fill)
                        .stroke(
                            LinearGradient(colors: colors,
                                           startPoint: .leading,
                                           endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(90))
                        .animation(.easeOut(duration: 0.25), value: fill)
                }

                center()
            }
            .frame(width: diameter, height: diameter)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
        .padding(.vertical, 2)
    }
}

#Preview {
    ContentView()
}
