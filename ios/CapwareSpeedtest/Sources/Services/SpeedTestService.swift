import Foundation

enum SpeedTestError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid server URL"
        case .networkError(let e):  return e.localizedDescription
        }
    }
}

enum TestPhase {
    case ping, download, upload
}

struct SpeedResult {
    var unloadedPingMs: Double       = 0
    var downloadLoadedPingMs: Double = 0
    var uploadLoadedPingMs: Double   = 0
    var downloadMbps: Double         = 0
    var uploadMbps: Double           = 0
}

final class SpeedTestService: NSObject {

    static let backendURL = "https://capware-speedtest-458492091300.us-central1.run.app"

    private let unloadedPingCount = 10
    private let testDuration: TimeInterval = 10
    private let downloadStreams = 4
    // 200 MB gives headroom up to ~160 Mbps for 10 s; cancel early if we hit it.
    private let uploadPayloadBytes = 200 * 1_000_000

    // Ping uses a plain session (no delegate — keeps callbacks isolated)
    private let pingSession = URLSession(configuration: .ephemeral)
    // Stream session shares one delegate for byte counting
    private var streamSession: URLSession!

    // Callbacks — always delivered on the main thread
    var onPhaseStart: ((TestPhase) -> Void)?
    var onProgress:   ((TestPhase, Double, Double) -> Void)?  // phase, Mbps or ms, 0–1 progress
    var onComplete:   ((Result<SpeedResult, SpeedTestError>) -> Void)?

    // Mutable state — bytesMoved only written from the delegate serial queue
    private var taskStart   = Date()
    private var bytesMoved: Int64 = 0
    private var activeTasks: [URLSessionTask] = []
    private var cancelled = false
    private var runTask: Task<Void, Never>?

    override init() {
        super.init()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        streamSession = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    func start() {
        cancelled = false
        runTask = Task { await runAll() }
    }

    func cancel() {
        cancelled = true
        runTask?.cancel()
        activeTasks.forEach { $0.cancel() }
        activeTasks = []
    }

    // MARK: - Orchestrator

    private func runAll() async {
        var result = SpeedResult()
        do {
            // 1. Unloaded ping
            fire { self.onPhaseStart?(.ping) }
            result.unloadedPingMs = try await measurePings(count: unloadedPingCount) { avg, p in
                self.fire { self.onProgress?(.ping, avg, p) }
            }
            guard !cancelled else { return }

            // 2. Download (parallel streams) + concurrent loaded ping
            fire { self.onPhaseStart?(.download) }
            let (dl, dlPing) = try await timedTransfer(phase: .download)
            result.downloadMbps        = dl
            result.downloadLoadedPingMs = dlPing
            guard !cancelled else { return }

            // 3. Upload + concurrent loaded ping
            fire { self.onPhaseStart?(.upload) }
            let (ul, ulPing) = try await timedTransfer(phase: .upload)
            result.uploadMbps        = ul
            result.uploadLoadedPingMs = ulPing

            fire { self.onComplete?(.success(result)) }
        } catch {
            guard !cancelled else { return }
            fire { self.onComplete?(.failure(.networkError(error))) }
        }
    }

    // MARK: - Ping

    private func measurePings(
        count: Int,
        onSample: @escaping (Double, Double) -> Void
    ) async throws -> Double {
        let url = URL(string: "https://www.google.com")!
        var samples: [Double] = []
        for i in 0..<count {
            guard !cancelled else { throw CancellationError() }
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
            req.httpMethod = "HEAD"
            let t = Date()
            _ = try await pingSession.data(for: req)
            samples.append(Date().timeIntervalSince(t) * 1_000)
            let avg = samples.reduce(0, +) / Double(samples.count)
            onSample(avg, Double(i + 1) / Double(count))
        }
        return samples.reduce(0, +) / Double(samples.count)
    }

    private func singlePing() async -> Double? {
        guard !cancelled else { return nil }
        var req = URLRequest(
            url: URL(string: "https://www.google.com")!,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData
        )
        req.httpMethod = "HEAD"
        let t = Date()
        guard (try? await pingSession.data(for: req)) != nil else { return nil }
        return Date().timeIntervalSince(t) * 1_000
    }

    // MARK: - Timed transfer with concurrent loaded-latency ping

    private func timedTransfer(phase: TestPhase) async throws -> (mbps: Double, loadedPingMs: Double) {
        actor PingAccumulator {
            private var samples: [Double] = []
            private(set) var running = true
            func add(_ ms: Double) { samples.append(ms) }
            func stop() { running = false }
            var average: Double {
                samples.isEmpty ? 0 : samples.reduce(0, +) / Double(samples.count)
            }
        }

        let acc = PingAccumulator()
        let pingTask = Task {
            while await acc.running { if let ms = await singlePing() { await acc.add(ms) } }
        }
        defer { pingTask.cancel() }

        let mbps = try await (phase == .download ? runTimedDownload() : runTimedUpload())
        await acc.stop()
        return (mbps, await acc.average)
    }

    // MARK: - Download: N parallel streams, cancelled after testDuration

    private func runTimedDownload() async throws -> Double {
        guard let url = URL(string: "\(Self.backendURL)/stream") else { throw SpeedTestError.invalidURL }

        bytesMoved = 0
        taskStart  = .now
        activeTasks = (0..<downloadStreams).map { _ in
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            return streamSession.dataTask(with: req)
        }
        activeTasks.forEach { $0.resume() }

        try await runProgressTimer(phase: .download)

        let elapsed = Date().timeIntervalSince(taskStart)
        activeTasks.forEach { $0.cancel() }
        activeTasks = []
        return mbps(bytes: bytesMoved, elapsed: elapsed)
    }

    // MARK: - Upload: single stream, cancelled after testDuration

    private func runTimedUpload() async throws -> Double {
        guard let url = URL(string: "\(Self.backendURL)/upload") else { throw SpeedTestError.invalidURL }

        bytesMoved = 0
        taskStart  = .now

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let payload = Data(count: uploadPayloadBytes)
        let task = streamSession.uploadTask(with: req, from: payload)
        activeTasks = [task]
        task.resume()

        try await runProgressTimer(phase: .upload)

        let elapsed = Date().timeIntervalSince(taskStart)
        activeTasks.forEach { $0.cancel() }
        activeTasks = []
        return mbps(bytes: bytesMoved, elapsed: elapsed)
    }

    // MARK: - Helpers

    /// Fires progress updates every 200 ms for testDuration seconds.
    private func runProgressTimer(phase: TestPhase) async throws {
        let start = Date()
        while Date().timeIntervalSince(start) < testDuration {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(200))
            let elapsed = Date().timeIntervalSince(taskStart)
            let speed   = mbps(bytes: bytesMoved, elapsed: elapsed)
            let progress = min(Date().timeIntervalSince(start) / testDuration, 1)
            fire { self.onProgress?(phase, speed, progress) }
        }
    }

    private func mbps(bytes: Int64, elapsed: TimeInterval) -> Double {
        elapsed > 0.05 ? Double(bytes) / elapsed / 125_000 : 0
    }

    private func fire(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}

// MARK: - URLSession delegates

extension SpeedTestService: URLSessionDataDelegate, URLSessionTaskDelegate {

    // Download bytes
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        bytesMoved += Int64(data.count)
    }

    // Upload bytes
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        bytesMoved = totalBytesSent
    }

    // Cancellation is expected — no action needed in the time-based model
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {}
}
