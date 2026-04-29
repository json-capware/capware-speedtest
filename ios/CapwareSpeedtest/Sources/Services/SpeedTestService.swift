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

enum TestPhase { case ping, download, upload }

struct SpeedResult {
    var unloadedPingMs: Double       = 0
    var downloadLoadedPingMs: Double = 0
    var uploadLoadedPingMs: Double   = 0
    var downloadMbps: Double         = 0
    var uploadMbps: Double           = 0
}

final class SpeedTestService: NSObject {

    // GCS object — served directly from Google Storage (much higher throughput than Cloud Run)
    static let gcsDownloadURL = "https://storage.googleapis.com/capware-speedtest-cdn/test-1gb.bin"
    static let backendURL     = "https://capware-speedtest-458492091300.us-central1.run.app"

    private let unloadedPingCount   = 10
    private let testDuration: TimeInterval = 10
    private let uploadPayloadBytes  = 200 * 1_000_000  // 200 MB ceiling for upload

    private let pingSession = URLSession(configuration: .ephemeral)
    private var streamSession: URLSession!

    var onPhaseStart: ((TestPhase) -> Void)?
    var onProgress:   ((TestPhase, Double, Double) -> Void)?  // phase, Mbps/ms, 0–1
    var onComplete:   ((Result<SpeedResult, SpeedTestError>) -> Void)?

    // Written only from the delegate's serial queue; read from async tasks.
    // Int64 loads/stores are naturally atomic on arm64 — minor staleness in the
    // progress timer is acceptable; the final result read is always after task completion.
    private var bytesMoved: Int64 = 0
    private var taskStart = Date()

    private var activeTask: URLSessionTask?
    private var transferContinuation: CheckedContinuation<Double, Error>?
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
        activeTask?.cancel()
        activeTask = nil
    }

    // MARK: - Runner

    private func runAll() async {
        var result = SpeedResult()
        do {
            fire { self.onPhaseStart?(.ping) }
            result.unloadedPingMs = try await measurePings(count: unloadedPingCount) { avg, p in
                self.fire { self.onProgress?(.ping, avg, p) }
            }
            guard !cancelled else { return }

            fire { self.onPhaseStart?(.download) }
            let (dl, dlPing) = try await withLoadedPing { try await self.runDownload() }
            result.downloadMbps        = dl
            result.downloadLoadedPingMs = dlPing
            guard !cancelled else { return }

            fire { self.onPhaseStart?(.upload) }
            let (ul, ulPing) = try await withLoadedPing { try await self.runUpload() }
            result.uploadMbps        = ul
            result.uploadLoadedPingMs = ulPing

            fire { self.onComplete?(.success(result)) }
        } catch {
            guard !cancelled else { return }
            fire { self.onComplete?(.failure(.networkError(error))) }
        }
    }

    // MARK: - Unloaded ping

    private func measurePings(count: Int, onSample: @escaping (Double, Double) -> Void) async throws -> Double {
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

    // MARK: - Loaded-latency wrapper

    /// Runs a transfer and concurrently pings google.com throughout to measure loaded latency.
    private func withLoadedPing(_ transfer: @escaping () async throws -> Double) async throws -> (Double, Double) {
        actor PingAcc {
            private var samples: [Double] = []
            private(set) var running = true
            func add(_ ms: Double) { samples.append(ms) }
            func stop() { running = false }
            var average: Double { samples.isEmpty ? 0 : samples.reduce(0, +) / Double(samples.count) }
        }
        let acc = PingAcc()
        let pingTask = Task { [weak self] in
            guard let self else { return }
            let url = URL(string: "https://www.google.com")!
            while await acc.running && !self.cancelled {
                var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
                req.httpMethod = "HEAD"
                let t = Date()
                guard (try? await self.pingSession.data(for: req)) != nil else { continue }
                await acc.add(Date().timeIntervalSince(t) * 1_000)
            }
        }
        defer { pingTask.cancel() }
        let mbps = try await transfer()
        await acc.stop()
        return (mbps, await acc.average)
    }

    // MARK: - Download (GCS, single stream, 10 s cap)

    private func runDownload() async throws -> Double {
        guard let url = URL(string: Self.gcsDownloadURL) else { throw SpeedTestError.invalidURL }
        bytesMoved = 0
        taskStart  = .now

        return try await withThrowingTaskGroup(of: Double.self) { group in
            // Task A: actual download — resolves when complete or cancelled
            group.addTask {
                try await withCheckedThrowingContinuation { cont in
                    self.transferContinuation = cont
                    var req = URLRequest(url: url)
                    req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
                    let task = self.streamSession.dataTask(with: req)
                    self.activeTask = task
                    task.resume()
                }
            }
            // Task B: 10 s timer with live progress updates; cancels the download on expiry
            group.addTask {
                let start = Date()
                while Date().timeIntervalSince(start) < self.testDuration {
                    try await Task.sleep(for: .milliseconds(250))
                    let elapsed  = Date().timeIntervalSince(self.taskStart)
                    let speed    = elapsed > 0 ? Double(self.bytesMoved) / elapsed / 125_000 : 0
                    let progress = min(Date().timeIntervalSince(start) / self.testDuration, 1)
                    self.fire { self.onProgress?(.download, speed, progress) }
                }
                // Time's up — cancel the download task; didCompleteWithError will resolve Task A
                self.activeTask?.cancel()
                self.activeTask = nil
                // Return a sentinel; Task A's value is what we actually use
                return -1.0
            }

            // Whichever finishes first wins; cancel the other
            var result = -1.0
            for try await value in group {
                if value >= 0 { result = value }
                group.cancelAll()
                break
            }
            return result >= 0 ? result : Double(bytesMoved) / max(Date().timeIntervalSince(taskStart), 0.1) / 125_000
        }
    }

    // MARK: - Upload (Cloud Run, single stream, 10 s cap)

    private func runUpload() async throws -> Double {
        guard let url = URL(string: "\(Self.backendURL)/upload") else { throw SpeedTestError.invalidURL }
        bytesMoved = 0
        taskStart  = .now
        let payload = Data(count: uploadPayloadBytes)

        return try await withThrowingTaskGroup(of: Double.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { cont in
                    self.transferContinuation = cont
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                    let task = self.streamSession.uploadTask(with: req, from: payload)
                    self.activeTask = task
                    task.resume()
                }
            }
            group.addTask {
                let start = Date()
                while Date().timeIntervalSince(start) < self.testDuration {
                    try await Task.sleep(for: .milliseconds(250))
                    let elapsed  = Date().timeIntervalSince(self.taskStart)
                    let speed    = elapsed > 0 ? Double(self.bytesMoved) / elapsed / 125_000 : 0
                    let progress = min(Date().timeIntervalSince(start) / self.testDuration, 1)
                    self.fire { self.onProgress?(.upload, speed, progress) }
                }
                self.activeTask?.cancel()
                self.activeTask = nil
                return -1.0
            }

            var result = -1.0
            for try await value in group {
                if value >= 0 { result = value }
                group.cancelAll()
                break
            }
            return result >= 0 ? result : Double(bytesMoved) / max(Date().timeIntervalSince(taskStart), 0.1) / 125_000
        }
    }

    private func fire(_ block: @escaping () -> Void) { DispatchQueue.main.async(execute: block) }
}

// MARK: - Delegates

extension SpeedTestService: URLSessionDataDelegate, URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        bytesMoved += Int64(data.count)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didSendBodyData bytesSent: Int64, totalBytesSent: Int64,
                    totalBytesExpectedToSend: Int64) {
        bytesMoved = totalBytesSent
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let cont = transferContinuation
        transferContinuation = nil

        // NSURLErrorCancelled means our 10 s timer fired — treat as a successful measurement
        let wasCancelled = (error as NSError?)?.code == NSURLErrorCancelled
        if let error, !wasCancelled {
            cont?.resume(throwing: error)
        } else {
            let elapsed = Date().timeIntervalSince(taskStart)
            let result  = elapsed > 0 ? Double(bytesMoved) / elapsed / 125_000 : 0
            cont?.resume(returning: result)
        }
    }
}
