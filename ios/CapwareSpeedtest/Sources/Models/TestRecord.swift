import Foundation

enum TestSource: String, Codable {
    case phone
    case watch
}

struct TestRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let downloadMbps: Double
    let uploadMbps: Double
    let pingMs: Double
    let jitterMs: Double
    let ispName: String?
    let source: TestSource

    init(id: UUID, date: Date, downloadMbps: Double, uploadMbps: Double,
         pingMs: Double, jitterMs: Double, ispName: String?, source: TestSource = .phone) {
        self.id          = id
        self.date        = date
        self.downloadMbps = downloadMbps
        self.uploadMbps  = uploadMbps
        self.pingMs      = pingMs
        self.jitterMs    = jitterMs
        self.ispName     = ispName
        self.source      = source
    }

    // Backward-compatible decoding: old records without `source` default to .phone
    init(from decoder: Decoder) throws {
        let c         = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,   forKey: .id)
        date          = try c.decode(Date.self,   forKey: .date)
        downloadMbps  = try c.decode(Double.self, forKey: .downloadMbps)
        uploadMbps    = try c.decode(Double.self, forKey: .uploadMbps)
        pingMs        = try c.decode(Double.self, forKey: .pingMs)
        jitterMs      = try c.decode(Double.self, forKey: .jitterMs)
        ispName       = try c.decodeIfPresent(String.self,     forKey: .ispName)
        source        = try c.decodeIfPresent(TestSource.self, forKey: .source) ?? .phone
    }
}
