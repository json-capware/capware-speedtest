import Foundation
import Mixpanel
#if os(iOS) && !targetEnvironment(macCatalyst)
import MixpanelSessionReplay
#endif

// MARK: - Analytics
// Single entry point for all Mixpanel tracking.
// Uses a persistent device-scoped distinct ID (no login flow).

enum Analytics {

    // MARK: - Environment

    static var environment: String {
        #if targetEnvironment(simulator)
        return "development"
        #else
        guard let url = Bundle.main.appStoreReceiptURL else { return "development" }
        return url.lastPathComponent == "sandboxReceipt" ? "testflight" : "production"
        #endif
    }

    static func initialize() {
        // useUniqueDistinctId generates a stable UUID on first launch and
        // persists it — this is what populates the People section.
        Mixpanel.initialize(token: "ca5c29f99220473d213df79a1ac35a5c",
                            trackAutomaticEvents: true,
                            useUniqueDistinctId: true)

        let mixpanel = Mixpanel.mainInstance()

        // Tag every event with the build environment so TestFlight and
        // production data can be filtered independently in Mixpanel.
        mixpanel.registerSuperProperties(["environment": environment])

        // Link this device's event stream to a People profile.
        mixpanel.identify(distinctId: mixpanel.distinctId)
        mixpanel.people.setOnce(properties: ["$first_seen": Date(), "environment": environment])

        // Session Replay — iOS only (not available on Catalyst/tvOS/macOS).
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let replayConfig = MPSessionReplayConfig(wifiOnly: false)
        MPSessionReplay.initialize(
            token: mixpanel.apiToken,
            distinctId: mixpanel.distinctId,
            config: replayConfig
        )
        #endif
    }

    // MARK: - Navigation

    static func tabViewed(_ tab: String) {
        track("tab_viewed", properties: ["tab": tab])
    }

    // MARK: - History

    static func historyDeleted(recordCount: Int) {
        track("history_deleted", properties: ["record_count": recordCount])
    }

    // MARK: - Speed test lifecycle

    static func speedTestStarted() {
        track("speed_test_started")
    }

    static func speedTestCompleted(
        downloadMbps: Double,
        uploadMbps: Double,
        unloadedPingMs: Double,
        jitterMs: Double,
        downloadLoadedPingMs: Double,
        downloadJitterMs: Double,
        uploadLoadedPingMs: Double,
        uploadJitterMs: Double,
        ispName: String?,
        durationSeconds: Double
    ) {
        var props: Properties = [
            "download_mbps":           downloadMbps,
            "upload_mbps":             uploadMbps,
            "unloaded_ping_ms":        unloadedPingMs,
            "jitter_ms":               jitterMs,
            "download_loaded_ping_ms": downloadLoadedPingMs,
            "download_jitter_ms":      downloadJitterMs,
            "upload_loaded_ping_ms":   uploadLoadedPingMs,
            "upload_jitter_ms":        uploadJitterMs,
            "duration_seconds":        durationSeconds,
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
