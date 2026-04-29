import SwiftUI

struct ContentView: View {

    @StateObject private var vm = SpeedTestViewModel()

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.06, blue: 0.14),
                         Color(red: 0.06, green: 0.09, blue: 0.22)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                VStack(spacing: 4) {
                    Text("Capware")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(3)
                    Text("Speed Test")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.top, 60)

                Spacer()

                // Gauge — tappable when idle or done
                Button {
                    switch vm.state {
                    case .idle, .done, .failed: vm.run()
                    case .running: break
                    }
                } label: {
                    SpeedGaugeView(
                        mbps: vm.currentMbps,
                        progress: vm.progress,
                        isRunning: isRunning
                    )
                    .frame(width: 280, height: 280)
                }
                .buttonStyle(.plain)
                .disabled(isRunning)

                Spacer().frame(height: 32)

                // Status area
                statusView
                    .frame(height: 80)

                Spacer()

                // Stats row
                if vm.peakMbps > 0 {
                    statsRow
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Bottom action
                bottomButton
                    .padding(.bottom, 48)
            }
            .animation(.easeInOut(duration: 0.35), value: stateTag)
        }
    }

    // MARK: - Sub views

    @ViewBuilder
    private var statusView: some View {
        switch vm.state {
        case .idle:
            Text("Tap the gauge to start")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.4))

        case .running:
            VStack(spacing: 6) {
                ProgressView(value: vm.progress)
                    .tint(.cyan)
                    .frame(width: 200)
                Text("Downloading from GCP…")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }

        case .done(let mbps):
            VStack(spacing: 8) {
                ResultBadge(mbps: mbps)
                Text("Download complete")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }

        case .failed(let msg):
            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(msg)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 40) {
            statCell(title: "Peak", value: String(format: "%.1f Mbps", vm.peakMbps))
            statCell(title: "Server", value: "GCP US-Central")
        }
        .padding(.bottom, 24)
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
                .tracking(1.5)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        switch vm.state {
        case .idle: EmptyView()
        case .running:
            Button("Cancel") { vm.reset() }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        case .done, .failed:
            Button {
                vm.reset()
            } label: {
                Text("Test Again")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 200, height: 50)
                    .background(.white.opacity(0.1))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
            }
        }
    }

    // MARK: - Helpers

    private var isRunning: Bool {
        if case .running = vm.state { return true }
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
}

#Preview {
    ContentView()
}
