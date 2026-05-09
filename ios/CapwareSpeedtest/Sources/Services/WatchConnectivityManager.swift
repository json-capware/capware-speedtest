import Foundation
import WatchConnectivity

/// Bridges the Apple Watch ↔ iPhone for Pulse speed tests.
/// - Watch sends `["action": "runTest"]`  → triggers `onTestRequest`
/// - iOS calls `sendResults(...)` when the test finishes → watch displays results
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    /// Called on the main actor when the watch requests a test.
    var onTestRequest: (() -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendResults(download: Double, upload: Double, ping: Double, jitter: Double) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            ["download": download, "upload": upload, "ping": ping, "jitter": jitter],
            replyHandler: nil,
            errorHandler: nil
        )
    }

    func sendError(_ message: String) {
        guard WCSession.default.activationState == .activated,
              WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["error": message], replyHandler: nil, errorHandler: nil)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate on paired watch swap
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard message["action"] as? String == "runTest" else { return }
        Task { @MainActor in
            self.onTestRequest?()
        }
    }
}
