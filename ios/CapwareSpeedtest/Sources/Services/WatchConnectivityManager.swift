import Foundation
import WatchConnectivity

/// Receives speed-test results from the Apple Watch and saves them to the phone's history.
/// The watch runs its own test and ships results via transferUserInfo (no app open needed).
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {

    static let shared = WatchConnectivityManager()

    /// Set by CapwareSpeedtestApp to save incoming watch results.
    var onWatchResult: ((TestRecord) -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith state: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    /// Receives queued test results from the Watch (delivered via transferUserInfo).
    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any]) {
        guard
            userInfo["source"] as? String == "watch",
            let idStr    = userInfo["id"]       as? String,
            let id       = UUID(uuidString: idStr),
            let ts       = userInfo["date"]     as? TimeInterval,
            let download = userInfo["download"] as? Double,
            let upload   = userInfo["upload"]   as? Double,
            let ping     = userInfo["ping"]     as? Double,
            let jitter   = userInfo["jitter"]   as? Double
        else { return }

        let isp = (userInfo["isp"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let record = TestRecord(
            id:           id,
            date:         Date(timeIntervalSince1970: ts),
            downloadMbps: download,
            uploadMbps:   upload,
            pingMs:       ping,
            jitterMs:     jitter,
            ispName:      isp,
            source:       .watch
        )

        Task { @MainActor in
            self.onWatchResult?(record)
        }
    }
}
