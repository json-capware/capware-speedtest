import Foundation
import Mixpanel

// MARK: - Analytics
// Single entry point for all Mixpanel tracking.
// No user identity — anonymous device tracking only (no login flow).

enum Analytics {

    static func initialize() {
        Mixpanel.initialize(token: "ca5c29f99220473d213df79a1ac35a5c",
                            trackAutomaticEvents: true)
    }

    // MARK: - Speed test lifecycle

    static func speedTestStarted() {
        track("speed_test_started")
    }

    static func speedTestCompleted(
        downloadMbps: Double,
        uploadMbps: Double,
        pingMs: Double,
        jitterMs: Double,
        ispName: String?,
        durationSeconds: Double
    ) {
        var props: Properties = [
            "download_mbps":     downloadMbps,
            "upload_mbps":       uploadMbps,
            "ping_ms":           pingMs,
            "jitter_ms":         jitterMs,
            "duration_seconds":  durationSeconds,
        ]
        if let isp = ispName { props["isp_name"] = isp }
        track("speed_test_completed", properties: props)
    }

    static func speedTestFailed(error: String) {
        track("speed_test_failed", properties: ["error": error])
    }

    // MARK: - Private

    private static func track(_ event: String, properties: Properties = [:]) {
        Mixpanel.mainInstance().track(event: event, properties: properties)
    }
}
