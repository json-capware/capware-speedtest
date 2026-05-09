import SwiftUI

// MARK: - Design tokens (mirrored from iOS app)

private extension Color {
    static let capAccent = Color(red: 0.00, green: 0.81, blue: 0.81)  // #00cece
    static let capAmber  = Color(red: 0.97, green: 0.65, blue: 0.12)
    static let capDark   = Color(red: 0.10, green: 0.09, blue: 0.09)
    static let capMuted  = Color(red: 0.71, green: 0.69, blue: 0.69)
    static let capSub    = Color(red: 0.47, green: 0.43, blue: 0.43)
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var session = WatchSessionManager.shared

    var body: some View {
        Group {
            switch session.phase {
            case .idle:
                idleView
            case .testing:
                testingView
            case .done(let dl, let ul, let ping, let jitter):
                resultsView(download: dl, upload: ul, ping: ping, jitter: jitter)
            case .failed(let msg):
                failedView(msg)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.phase)
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 10) {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(Color.capAccent)

            Text("Pulse")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.capSub)

            Button {
                session.requestTest()
            } label: {
                Label("Test", systemImage: "play.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.capAccent)
        }
    }

    // MARK: - Testing

    private var testingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
                .tint(Color.capAccent)

            Text("Testing…")
                .font(.system(size: 14, weight: .medium, design: .rounded))

            Text("Running on iPhone")
                .font(.system(size: 11))
                .foregroundStyle(Color.capMuted)
        }
    }

    // MARK: - Results

    private func resultsView(download: Double, upload: Double, ping: Double, jitter: Double) -> some View {
        ScrollView {
            VStack(spacing: 6) {
                WatchResultRow(
                    icon: "arrow.down.circle.fill",
                    color: .capAccent,
                    label: "Download",
                    value: formatMbps(download)
                )
                WatchResultRow(
                    icon: "arrow.up.circle.fill",
                    color: Color(white: 0.3),
                    label: "Upload",
                    value: formatMbps(upload)
                )
                WatchResultRow(
                    icon: "wifi",
                    color: .capAmber,
                    label: "Ping",
                    value: String(format: "%.0f ms", ping)
                )
                WatchResultRow(
                    icon: "waveform",
                    color: .capMuted,
                    label: "Jitter",
                    value: String(format: "%.0f ms", jitter)
                )

                Button("Test Again") {
                    session.reset()
                }
                .buttonStyle(.bordered)
                .tint(Color.capAccent)
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
        .focusable()
    }

    // MARK: - Failed

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.orange)

            Text(message)
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.capSub)

            Button("Try Again") {
                session.reset()
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Helpers

    private func formatMbps(_ v: Double) -> String {
        (v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)) + " Mbps"
    }
}

// MARK: - WatchResultRow

private struct WatchResultRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ContentView()
}
