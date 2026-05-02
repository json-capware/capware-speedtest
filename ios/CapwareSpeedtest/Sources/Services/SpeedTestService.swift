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
    var jitterMs: Double             = 0
    var downloadLoadedPingMs: Double = 0
    var downloadJitterMs: Double     = 0
    var uploadLoadedPingMs: Double   = 0
    var uploadJitterMs: Double       = 0
    var downloadMbps: Double         = 0
    var uploadMbps: Double           = 0
    var ispName: String?             = nil
}

final class SpeedTestService: NSObject {

    static let backendURL      = "https://capware-speedtest-458492091300.us-central1.run.app"
    static let downloadURL     = "\(backendURL)/stream"
    // Unloaded ping uses Cloudflare anycast — routes to nearest PoP, reflects true internet latency
    static let unloadedPingURL = "https://1.1.1.1/cdn-cgi/trace"
    // Loaded ping uses our backend to measure latency degradation under actual test load
    static let downloadPingURL = "\(backendURL)/health"
    static let uploadPingURL   = "\(backendURL)/health"
    static let ispURL          = "https://ipwho.is/"

    private let unloadedPingCount       = 8
    private let downloadDuration: TimeInterval = 10
    private let uploadDuration: TimeInterval   = 5
    private let parallelDownloadStreams = 6
    private let parallelUploadStreams   = 4
    // 50 MB per task — small enough to be memory-safe, tasks restart when exhausted
    private let uploadChunkBytes        = 50_000_000

    private let pingSession = URLSession(configuration: .ephemeral)
    private var streamSession: URLSession!

    var onPhaseStart:  ((TestPhase) -> Void)?
    var onProgress:    ((TestPhase, Double, Double) -> Void)?
    var onLiveLatency: ((Double, Double) -> Void)?
    var onComplete:    ((Result<SpeedResult, SpeedTestError>) -> Void)?

    private var bytesMoved: Int64 = 0
    private var taskStart = Date()

    // Upload state — protected by the session's serial delegate queue
    private var uploadURL: URL? = nil
    private var uploadPayload = Data()
    private var uploadPhaseActive = false

    private var activeTasks: [URLSessionTask] = []
    private var taskError: Error? = nil
    private var cancelled = false
    private var runTask: Task<Void, Never>?

    private struct ByteSample { let time: Date; let bytes: Int64 }
    private var samples: [ByteSample] = []
    private var peakWindowMbps: Double = 0

    override init() {
        super.init()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        // Serial delegate queue so all delegate callbacks and upload-restart logic are serialized
        let q = OperationQueue()
        q.maxConcurrentOperationCount = 1
        q.name = "SpeedTestService.delegate"
        streamSession = URLSession(configuration: cfg, delegate: self, delegateQueue: q)
    }

    func start() {
        cancelled = false
        runTask = Task { await runAll() }
    }

    func cancel() {
        cancelled = true
        uploadPhaseActive = false
        runTask?.cancel()
        activeTasks.forEach { $0.cancel() }
        activeTasks = []
    }

    // MARK: - Runner

    private func runAll() async {
        var result = SpeedResult()
        async let ispFetch = fetchISP()

        do {
            fire { self.onPhaseStart?(.ping) }
            let (pingMs, jitterMs) = try await measurePings(count: unloadedPingCount) { avg, jitter, p in
                self.fire {
                    self.onProgress?(.ping, avg, p)
                    self.onLiveLatency?(avg, jitter)
                }
            }
            result.unloadedPingMs = pingMs
            result.jitterMs       = jitterMs
            guard !cancelled else { return }

            fire { self.onPhaseStart?(.download) }
            let (dl, dlPing, dlJitter) = try await withLoadedPing(pingURL: Self.downloadPingURL) { try await self.runDownload() }
            result.downloadMbps         = dl
            result.downloadLoadedPingMs = dlPing
            result.downloadJitterMs     = dlJitter
            guard !cancelled else { return }

            fire { self.onPhaseStart?(.upload) }
            let (ul, ulPing, ulJitter) = try await withLoadedPing(pingURL: Self.uploadPingURL) { try await self.runUpload() }
            result.uploadMbps         = ul
            result.uploadLoadedPingMs = ulPing
            result.uploadJitterMs     = ulJitter

            result.ispName = await ispFetch
            fire { self.onComplete?(.success(result)) }
        } catch {
            guard !cancelled else { return }
            fire { self.onComplete?(.failure(.networkError(error))) }
        }
    }

    // MARK: - ISP

    private func fetchISP() async -> String? {
        guard let url = URL(string: Self.ispURL) else { return nil }
        guard let (data, _) = try? await pingSession.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        if let conn = json["connection"] as? [String: Any],
           let isp = conn["isp"] as? String, !isp.isEmpty {
            return isp
        }
        return nil
    }

    // MARK: - Jitter

    private func jitter(_ samples: [Double]) -> Double {
        guard samples.count > 1 else { return 0 }
        let mean = samples.reduce(0, +) / Double(samples.count)
        let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(samples.count - 1)
        return sqrt(variance)
    }

    // MARK: - Unloaded ping

    private func measurePings(
        count: Int,
        onSample: @escaping (Double, Double, Double) -> Void
    ) async throws -> (Double, Double) {
        let url = URL(string: Self.unloadedPingURL)!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        req.httpMethod = "GET"

        // Warmup — establishes TCP+TLS connection so measurements below are pure RTT
        _ = try? await pingSession.data(for: req)
        guard !cancelled else { throw CancellationError() }

        // Sequential pings all reuse the same connection — no TLS overhead per-ping
        var rtts: [Double] = []
        for i in 0..<count {
            guard !cancelled else { throw CancellationError() }
            let t = Date()
            _ = try await pingSession.data(for: req)
            rtts.append(Date().timeIntervalSince(t) * 1_000)
            onSample(rtts.min()!, jitter(rtts), Double(i + 1) / Double(count))
        }
        return (rtts.min()!, jitter(rtts))
    }

    // MARK: - Loaded-latency wrapper

    private func withLoadedPing(
        pingURL: String,
        _ transfer: @escaping () async throws -> Double
    ) async throws -> (Double, Double, Double) {
        actor PingAcc {
            private var samples: [Double] = []
            private(set) var running = true
            func add(_ ms: Double) { samples.append(ms) }
            func stop() { running = false }
            var minPing: Double { samples.isEmpty ? 0 : samples.min()! }
            var currentJitter: Double {
                guard samples.count > 1 else { return 0 }
                let mean = samples.reduce(0, +) / Double(samples.count)
                let variance = samples.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(samples.count - 1)
                return sqrt(variance)
            }
        }
        let acc = PingAcc()
        let url = URL(string: pingURL)!
        let pingTask = Task { [weak self] in
            guard let self else { return }
            while await acc.running && !self.cancelled {
                var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
                req.httpMethod = "HEAD"
                let t = Date()
                guard (try? await self.pingSession.data(for: req)) != nil else { continue }
                let ms = Date().timeIntervalSince(t) * 1_000
                await acc.add(ms)
                let ping   = await acc.minPing
                let jitter = await acc.currentJitter
                self.fire { self.onLiveLatency?(ping, jitter) }
            }
        }
        defer { pingTask.cancel() }
        let mbps = try await transfer()
        await acc.stop()
        return (mbps, await acc.minPing, await acc.currentJitter)
    }

    // MARK: - Download (parallel streams)

    private func runDownload() async throws -> Double {
        guard let url = URL(string: Self.downloadURL) else { throw SpeedTestError.invalidURL }
        bytesMoved = 0
        taskStart  = .now
        samples    = []
        peakWindowMbps = 0
        taskError  = nil
        activeTasks = []

        for _ in 0..<parallelDownloadStreams {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            let task = streamSession.dataTask(with: req)
            activeTasks.append(task)
            task.resume()
        }

        defer {
            activeTasks.forEach { $0.cancel() }
            activeTasks.removeAll()
        }

        return try await timerLoop(phase: .download, duration: downloadDuration)
    }

    // MARK: - Upload (parallel fixed-payload tasks, auto-restart on completion)

    private func runUpload() async throws -> Double {
        guard let url = URL(string: "\(Self.backendURL)/upload") else { throw SpeedTestError.invalidURL }
        bytesMoved = 0
        taskStart  = .now
        samples    = []
        peakWindowMbps = 0
        taskError  = nil
        activeTasks = []

        uploadURL     = url
        uploadPayload = Data(count: uploadChunkBytes)
        uploadPhaseActive = true

        for _ in 0..<parallelUploadStreams {
            spawnUploadTask()
        }

        defer {
            uploadPhaseActive = false
            uploadURL = nil
            activeTasks.forEach { $0.cancel() }
            activeTasks.removeAll()
        }

        return try await timerLoop(phase: .upload, duration: uploadDuration)
    }

    // Called from delegate queue — must not race with activeTasks
    private func spawnUploadTask() {
        guard uploadPhaseActive, let url = uploadURL else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let task = streamSession.uploadTask(with: req, from: uploadPayload)
        activeTasks.append(task)
        task.resume()
    }

    // MARK: - Shared timer loop

    private func timerLoop(phase: TestPhase, duration: TimeInterval) async throws -> Double {
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            if cancelled    { throw CancellationError() }
            if let err = taskError { throw err }
            try await Task.sleep(for: .milliseconds(250))

            let now  = Date()
            let snap = bytesMoved
            samples.append(ByteSample(time: now, bytes: snap))
            while samples.count > 1, now.timeIntervalSince(samples[0].time) > 3.0 {
                samples.removeFirst()
            }
            let span = now.timeIntervalSince(samples[0].time)
            let speed: Double
            if samples.count >= 2, span >= 0.5 {
                speed = Double(snap - samples[0].bytes) / span / 125_000
            } else {
                let elapsed = now.timeIntervalSince(taskStart)
                speed = elapsed > 0 ? Double(snap) / elapsed / 125_000 : 0
            }
            peakWindowMbps = max(peakWindowMbps, speed)
            let progress = min(now.timeIntervalSince(start) / duration, 1)
            fire { self.onProgress?(phase, speed, progress) }
        }
        return peakWindowMbps > 0 ? peakWindowMbps
            : Double(bytesMoved) / max(Date().timeIntervalSince(taskStart), 0.1) / 125_000
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
        bytesMoved += bytesSent
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        activeTasks.removeAll { $0 === task }
        let wasCancelled = (error as NSError?)?.code == NSURLErrorCancelled
        if let error, !wasCancelled {
            if taskError == nil { taskError = error }
        } else if error == nil && uploadPhaseActive {
            // Task exhausted its payload — immediately restart to keep bandwidth saturated
            spawnUploadTask()
        }
    }
}
