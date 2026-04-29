import Foundation

enum SpeedTestError: Error, LocalizedError {
    case invalidURL
    case noData
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid server URL"
        case .noData:               return "No data received"
        case .networkError(let e):  return e.localizedDescription
        }
    }
}

enum TestPhase {
    case ping, download, upload
}

struct SpeedResult {
    var unloadedPingMs: Double       = 0  // idle baseline
    var downloadLoadedPingMs: Double = 0  // ping while link is saturated
    var uploadLoadedPingMs: Double   = 0
    var downloadMbps: Double         = 0
    var uploadMbps: Double           = 0
}

final class SpeedTestService: NSObject {

    static let backendURL = "https://capware-speedtest-458492091300.us-central1.run.app"
    // CDN-backed GCS file — served from the nearest Google edge node globally.
    // Cert provisioning: https://34.36.55.236.sslip.io (allow ~15 min after first deploy)
    static let cdnFileURL = "https://34.36.55.236.sslip.io/test-200mb.bin"

    private let unloadedPingCount = 10
    private let downloadMB        = 200
    private let uploadMB          = 25

    // Separate sessions so delegate callbacks never bleed into ping tasks
    private let pingSession = URLSession(configuration: .ephemeral)
    private var streamSession: URLSession!

    // Callbacks — always called on main thread
    var onPhaseStart: ((TestPhase) -> Void)?
    /// phase, live speed (Mbps) or latency (ms), 0–1 progress, optional loaded ping ms
    var onProgress:   ((TestPhase, Double, Double, Double?) -> Void)?
    var onComplete:   ((Result<SpeedResult, SpeedTestError>) -> Void)?

    // State for the active streaming task
    private var taskStart      = Date()
    private var bytesMoved: Int64 = 0
    private var expectedBytes: Int64 = 0
    private var streamContinuation: CheckedContinuation<Double, Error>?
    private var cancelled = false

    override init() {
        super.init()
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        streamSession = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    func start() {
        cancelled = false
        Task { await runAll() }
    }

    func cancel() {
        cancelled = true
        streamSession.invalidateAndCancel()
    }

    // MARK: - Runner

    private func runAll() async {
        var result = SpeedResult()
        do {
            // 1. Unloaded ping
            fire { self.onPhaseStart?(.ping) }
            result.unloadedPingMs = try await measurePings(count: unloadedPingCount) { avg, progress in
                self.fire { self.onProgress?(.ping, avg, progress, nil) }
            }

            guard !cancelled else { return }

            // 2. Download + concurrent loaded ping
            fire { self.onPhaseStart?(.download) }
            let (dlMbps, dlPing) = try await measureTransferWithLoadedPing(isDownload: true)
            result.downloadMbps        = dlMbps
            result.downloadLoadedPingMs = dlPing

            guard !cancelled else { return }

            // 3. Upload + concurrent loaded ping
            fire { self.onPhaseStart?(.upload) }
            let (ulMbps, ulPing) = try await measureTransferWithLoadedPing(isDownload: false)
            result.uploadMbps        = ulMbps
            result.uploadLoadedPingMs = ulPing

            fire { self.onComplete?(.success(result)) }
        } catch {
            fire { self.onComplete?(.failure(.networkError(error))) }
        }
    }

    // MARK: - Ping helpers

    /// Fires `count` HEAD requests to google.com sequentially, returns average RTT ms.
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
            samples.append(Date().timeIntervalSince(t) * 1000)
            let avg = samples.reduce(0, +) / Double(samples.count)
            onSample(avg, Double(i + 1) / Double(count))
        }
        return samples.reduce(0, +) / Double(samples.count)
    }

    /// Runs a single HEAD to google.com, returns RTT ms.
    private func singlePing() async -> Double? {
        guard !cancelled else { return nil }
        let url = URL(string: "https://www.google.com")!
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        req.httpMethod = "HEAD"
        let t = Date()
        guard (try? await pingSession.data(for: req)) != nil else { return nil }
        return Date().timeIntervalSince(t) * 1000
    }

    // MARK: - Transfer with concurrent loaded latency

    private func measureTransferWithLoadedPing(isDownload: Bool) async throws -> (Double, Double) {
        // Shared state between the two concurrent tasks
        actor PingAccumulator {
            var samples: [Double] = []
            var running = true
            func add(_ ms: Double) { samples.append(ms) }
            func stop() { running = false }
            var isRunning: Bool { running }
            var average: Double {
                guard !samples.isEmpty else { return 0 }
                return samples.reduce(0, +) / Double(samples.count)
            }
        }
        let acc = PingAccumulator()

        // Ping loop runs concurrently for the duration of the transfer
        let pingTask = Task {
            while await acc.isRunning {
                if let ms = await self.singlePing() {
                    await acc.add(ms)
                }
            }
        }

        // Run the actual transfer
        let speed = try await (isDownload ? runDownload() : runUpload())

        await acc.stop()
        pingTask.cancel()

        return (speed, await acc.average)
    }

    // MARK: - Download

    private func runDownload() async throws -> Double {
        bytesMoved    = 0
        expectedBytes = Int64(downloadMB) * 1_000_000
        taskStart     = Date()

        return try await withCheckedThrowingContinuation { cont in
            self.streamContinuation = cont
            guard let url = URL(string: Self.cdnFileURL) else {
                cont.resume(throwing: SpeedTestError.invalidURL); return
            }
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            streamSession.dataTask(with: req).resume()
        }
    }

    // MARK: - Upload

    private func runUpload() async throws -> Double {
        let bytes     = uploadMB * 1_000_000
        bytesMoved    = 0
        expectedBytes = Int64(bytes)
        taskStart     = Date()

        let payload = Data(count: bytes) // zeros are fine for throughput testing

        return try await withCheckedThrowingContinuation { cont in
            self.streamContinuation = cont
            guard let url = URL(string: "\(Self.backendURL)/upload") else {
                cont.resume(throwing: SpeedTestError.invalidURL); return
            }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            streamSession.uploadTask(with: req, from: payload).resume()
        }
    }

    // MARK: - Helpers

    private func currentMbps() -> Double {
        let elapsed = Date().timeIntervalSince(taskStart)
        guard elapsed > 0.05 else { return 0 }
        return Double(bytesMoved) / elapsed / 125_000
    }

    private func fire(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}

// MARK: - URLSession delegates

extension SpeedTestService: URLSessionDataDelegate, URLSessionTaskDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        bytesMoved += Int64(data.count)
        let speed    = currentMbps()
        let progress = min(Double(bytesMoved) / Double(expectedBytes), 1)
        fire { self.onProgress?(.download, speed, progress, nil) }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        bytesMoved = totalBytesSent
        let speed    = currentMbps()
        let progress = totalBytesExpectedToSend > 0
            ? Double(totalBytesSent) / Double(totalBytesExpectedToSend) : 0
        fire { self.onProgress?(.upload, speed, progress, nil) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let cont = streamContinuation
        streamContinuation = nil
        if let error { cont?.resume(throwing: error); return }
        cont?.resume(returning: currentMbps())
    }
}
