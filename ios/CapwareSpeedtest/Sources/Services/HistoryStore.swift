import Foundation

final class HistoryStore: ObservableObject {
    @Published private(set) var records: [TestRecord] = []

    private let key = "speedtest.history"

    init() { load() }

    func add(_ record: TestRecord) {
        records.insert(record, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    func deleteAll() {
        records = []
        save()
    }

    var best: TestRecord? {
        records.max(by: { $0.downloadMbps < $1.downloadMbps })
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TestRecord].self, from: data)
        else { return }
        records = decoded
    }
}
