import Foundation
import Combine

enum TestState {
    case idle
    case running
    case done(Double)   // final Mbps
    case failed(String)
}

@MainActor
final class SpeedTestViewModel: ObservableObject {

    @Published var state: TestState = .idle
    @Published var currentMbps: Double = 0
    @Published var peakMbps: Double = 0
    @Published var progress: Double = 0   // 0–1 based on bytes vs expected

    private var service: SpeedTestService?
    private let expectedBytes: Int64 = 25 * 1_000_000

    func run() {
        guard case .idle = state else { return }
        currentMbps = 0
        peakMbps = 0
        progress = 0
        state = .running

        let svc = SpeedTestService()
        service = svc

        svc.start { [weak self] sample in
            guard let self else { return }
            self.currentMbps = sample.mbps
            self.peakMbps = max(self.peakMbps, sample.mbps)
            self.progress = min(Double(sample.bytesReceived) / Double(self.expectedBytes), 1.0)
        } onComplete: { [weak self] result in
            guard let self else { return }
            self.service = nil
            switch result {
            case .success(let sample):
                self.currentMbps = sample.mbps
                self.peakMbps = max(self.peakMbps, sample.mbps)
                self.progress = 1.0
                self.state = .done(sample.mbps)
            case .failure(let err):
                self.state = .failed(err.localizedDescription)
            }
        }
    }

    func reset() {
        service?.cancel()
        service = nil
        state = .idle
        currentMbps = 0
        peakMbps = 0
        progress = 0
    }
}
