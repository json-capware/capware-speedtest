import Foundation
import WatchConnectivity

// MARK: - TestResult

struct WatchTestResult {
    let download: Double
    let upload: Double
    let ping: Double
    let jitter: Double
}

// MARK: - Phase

enum WatchPhase: Equatable {
    case idle
    case testing
    case done(download: Double, upload: Double, ping: Double, jitter: Double)
    case failed(String)
}

// MARK: - WatchSessionManager

@MainActor
final class WatchSessionManager: NSObject, ObservableObject {
    static let shared = WatchSessionManager()

    @Published var phase: WatchPhase = .idle
    @Published var isReachable = false

    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func requestTest() {
        guard WCSession.default.activationState == .activated else {
            phase = .failed("Watch session not ready")
            return
        }
        guard WCSession.default.isReachable else {
            phase = .failed("iPhone not reachable")
            return
        }
        phase = .testing
        WCSession.default.sendMessage(
            ["action": "runTest"],
            replyHandler: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.phase = .failed("Couldn't reach iPhone")
            }
        }
    }

    func reset() {
        phase = .idle
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard
            let download = message["download"] as? Double,
            let upload   = message["upload"]   as? Double,
            let ping     = message["ping"]     as? Double,
            let jitter   = message["jitter"]   as? Double
        else {
            if let error = message["error"] as? String {
                Task { @MainActor in self.phase = .failed(error) }
            }
            return
        }
        Task { @MainActor in
            self.phase = .done(download: download, upload: upload, ping: ping, jitter: jitter)
        }
    }
}
