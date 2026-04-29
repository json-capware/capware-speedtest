import Foundation

enum TestState {
    case idle
    case running(TestPhase)
    case done(SpeedResult)
    case failed(String)
}

@MainActor
final class SpeedTestViewModel: ObservableObject {

    @Published var state: TestState = .idle

    // Live values during the active phase
    @Published var currentMbps: Double = 0
    @Published var currentPingMs: Double = 0   // unloaded ping during ping phase
    @Published var progress: Double = 0

    // Accumulated results as each phase completes
    @Published var unloadedPingMs: Double?
    @Published var downloadMbps: Double?
    @Published var downloadLoadedPingMs: Double?
    @Published var uploadMbps: Double?
    @Published var uploadLoadedPingMs: Double?

    private var service: SpeedTestService?

    func run() {
        guard case .idle = state else { return }
        resetValues()
        state = .running(.ping)

        let svc = SpeedTestService()
        service = svc

        svc.onPhaseStart = { [weak self] phase in
            guard let self else { return }
            self.state = .running(phase)
            self.currentMbps  = 0
            self.progress     = 0
        }

        svc.onProgress = { [weak self] phase, value, progress, _ in
            guard let self else { return }
            self.progress = progress
            switch phase {
            case .ping:
                self.currentPingMs = value
            case .download, .upload:
                self.currentMbps = value
            }
        }

        svc.onComplete = { [weak self] result in
            guard let self else { return }
            self.service = nil
            switch result {
            case .success(let r):
                self.unloadedPingMs      = r.unloadedPingMs
                self.downloadMbps        = r.downloadMbps
                self.downloadLoadedPingMs = r.downloadLoadedPingMs
                self.uploadMbps          = r.uploadMbps
                self.uploadLoadedPingMs  = r.uploadLoadedPingMs
                self.state = .done(r)
            case .failure(let err):
                self.state = .failed(err.localizedDescription)
            }
        }

        svc.start()
    }

    func reset() {
        service?.cancel()
        service = nil
        resetValues()
        state = .idle
    }

    private func resetValues() {
        currentMbps       = 0
        currentPingMs     = 0
        progress          = 0
        unloadedPingMs    = nil
        downloadMbps      = nil
        downloadLoadedPingMs = nil
        uploadMbps        = nil
        uploadLoadedPingMs = nil
    }

    var activePhase: TestPhase? {
        if case .running(let p) = state { return p }
        return nil
    }
}
