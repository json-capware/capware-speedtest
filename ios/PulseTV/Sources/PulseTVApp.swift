import SwiftUI

@main
struct PulseTVApp: App {
    @StateObject private var history = HistoryStore()

    init() {
        Analytics.initialize()
    }

    var body: some Scene {
        WindowGroup {
            TVRootView(history: history)
        }
    }
}
