import Foundation

struct TestRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let downloadMbps: Double
    let uploadMbps: Double
    let pingMs: Double
    let jitterMs: Double
    let ispName: String?
}
