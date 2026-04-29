import Foundation

enum SpeedTestError: Error, LocalizedError {
    case invalidURL
    case noData
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL"
        case .noData: return "No data received"
        case .networkError(let e): return e.localizedDescription
        }
    }
}

struct SpeedSample {
    let bytesReceived: Int64
    let elapsed: TimeInterval
    var mbps: Double { Double(bytesReceived) / elapsed / 125_000 }
}

final class SpeedTestService: NSObject {

    // GCP Cloud Run backend — update with deployed URL
    static let baseURL = "https://capware-speedtest-458492091300.us-central1.run.app"

    // Download size in MB for the test
    private let testSizeMB = 25

    private var session: URLSession!
    private var task: URLSessionDataTask?

    private var startTime: Date = .now
    private var bytesReceived: Int64 = 0
    private var onProgress: ((SpeedSample) -> Void)?
    private var onComplete: ((Result<SpeedSample, SpeedTestError>) -> Void)?

    override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    func start(
        onProgress: @escaping (SpeedSample) -> Void,
        onComplete: @escaping (Result<SpeedSample, SpeedTestError>) -> Void
    ) {
        self.onProgress = onProgress
        self.onComplete = onComplete
        bytesReceived = 0

        let urlString = "\(Self.baseURL)/download?mb=\(testSizeMB)"
        guard let url = URL(string: urlString) else {
            onComplete(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        startTime = .now
        task = session.dataTask(with: request)
        task?.resume()
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

extension SpeedTestService: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        bytesReceived += Int64(data.count)
        let elapsed = Date.now.timeIntervalSince(startTime)
        guard elapsed > 0 else { return }
        let sample = SpeedSample(bytesReceived: bytesReceived, elapsed: elapsed)
        DispatchQueue.main.async { self.onProgress?(sample) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            DispatchQueue.main.async {
                self.onComplete?(.failure(.networkError(error)))
            }
            return
        }
        guard bytesReceived > 0 else {
            DispatchQueue.main.async { self.onComplete?(.failure(.noData)) }
            return
        }
        let elapsed = Date.now.timeIntervalSince(startTime)
        let result = SpeedSample(bytesReceived: bytesReceived, elapsed: elapsed)
        DispatchQueue.main.async { self.onComplete?(.success(result)) }
    }
}
