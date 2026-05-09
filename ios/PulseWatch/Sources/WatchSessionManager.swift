import Foundation
import WatchConnectivity

// MARK: - Phase

enum WatchPhase: Equatable {
    case idle
    case testing(label: String, currentValue: Double, progress: Double)
    case done(download: Double, upload: Double, ping: Double, jitter: Double)
    case failed(String)
}

// MARK: - WatchSessionManager

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var phase: WatchPhase = .idle

    private var service: SpeedTestService?

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    // MARK: - Run test locally on the Watch

    func startTest() {
        guard case .idle = phase else { return }
        phase = .testing(label: "Measuring latency", currentValue: 0, progress: 0)

        let svc = SpeedTestService()
        service = svc

        svc.onPhaseStart = { [weak self] testPhase in
            // SpeedTestService.fire dispatches to main already
            self?.phase = .testing(label: Self.label(for: testPhase), currentValue: 0, progress: 0)
        }

        svc.onProgress = { [weak self] testPhase, value, progress in
            self?.phase = .testing(label: Self.label(for: testPhase), currentValue: value, progress: progress)
        }

        svc.onComplete = { [weak self] result in
            guard let self else { return }
            self.service = nil
            switch result {
            case .success(let r):
                self.phase = .done(download: r.downloadMbps, upload: r.uploadMbps,
                                   ping: r.unloadedPingMs, jitter: r.jitterMs)
                self.sendToPhone(r)
            case .failure(let err):
                self.phase = .failed(err.localizedDescription)
            }
        }

        svc.start()
    }

    func reset() {
        service?.cancel()
        service = nil
        phase = .idle
    }

    // MARK: - Push result to iPhone history

    private func sendToPhone(_ r: SpeedResult) {
        guard WCSession.default.activationState == .activated else { return }
        // transferUserInfo queues delivery and doesn't need the iPhone app to be open
        WCSession.default.transferUserInfo([
            "source":   "watch",
            "id":       UUID().uuidString,
            "date":     Date().timeIntervalSince1970,
            "download": r.downloadMbps,
            "upload":   r.uploadMbps,
            "ping":     r.unloadedPingMs,
            "jitter":   r.jitterMs,
            "isp":      r.ispName ?? ""
        ])
    }

    // MARK: - Helpers

    private static func label(for phase: TestPhase) -> String {
        switch phase {
        case .ping:     return "Measuring latency"
        case .download: return "Download"
        case .upload:   return "Upload"
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {}
}
