import SwiftUI

struct HistoryView: View {
    @ObservedObject var history: HistoryStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var s: CGFloat { sizeClass == .regular ? 1.25 : 1.0 }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Group {
            if history.records.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        header.padding(.top, 56)

                        if let best = history.best {
                            bestCard(best)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(history.records.enumerated()), id: \.element.id) { index, record in
                                if index > 0 {
                                    Color.capBorder.frame(height: 1)
                                        .padding(.horizontal, 16)
                                }
                                HistoryRow(record: record, formatter: dateFormatter)
                            }
                        }
                        .background(Color.capCard)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.capBorder, lineWidth: 1))
                        .padding(.horizontal, 20)

                        Spacer(minLength: 32)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.capSurface.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("History")
                .font(.system(size: 20 * s, weight: .bold, design: .rounded))
                .foregroundStyle(Color.capText)
        }
        .padding(.bottom, 8)
    }

    private func bestCard(_ record: TestRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Best Result", systemImage: "trophy.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.85, green: 0.65, blue: 0.15))
                    .tracking(0.5)
                Spacer()
                Text(dateFormatter.string(from: record.date))
                    .font(.system(size: 11))
                    .foregroundStyle(Color.capMuted)
            }

            HStack(spacing: 24) {
                BestStat(label: "DOWNLOAD", value: formatMbps(record.downloadMbps), color: .capAccent)
                BestStat(label: "UPLOAD", value: formatMbps(record.uploadMbps), color: .capDark)
                BestStat(label: "PING", value: String(format: "%.0f ms", record.pingMs), color: .capAmber)
            }

            if let isp = record.ispName {
                Text(isp)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.capMuted)
            }
        }
        .padding(16)
        .background(Color.capCard)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(red: 0.85, green: 0.65, blue: 0.15).opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            header
            Spacer()
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 48))
                .foregroundStyle(Color.capMuted)
            Text("No tests yet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.capSub)
            Text("Run your first speed test to see results here.")
                .font(.system(size: 13))
                .foregroundStyle(Color.capMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func formatMbps(_ v: Double) -> String {
        (v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)) + " Mbps"
    }
}

// MARK: - BestStat

private struct BestStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.capMuted)
                .tracking(1)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}

// MARK: - HistoryRow

struct HistoryRow: View {
    let record: TestRecord
    let formatter: DateFormatter

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(formatter.string(from: record.date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.capText)
                if let isp = record.ispName {
                    Text(isp)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.capMuted)
                }
            }

            Spacer()

            HStack(spacing: 16) {
                SpeedPill(icon: "arrow.down", value: record.downloadMbps, color: .capAccent)
                SpeedPill(icon: "arrow.up", value: record.uploadMbps, color: .capDark)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(String(format: "%.0f ms", record.pingMs))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.capAmber)
                    Text("ping")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.capMuted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - SpeedPill

private struct SpeedPill: View {
    let icon: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value >= 100 ? String(format: "%.0f", value) : String(format: "%.1f", value))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
            Text("Mbps")
                .font(.system(size: 9))
                .foregroundStyle(Color.capMuted)
        }
    }
}

#Preview {
    let store = HistoryStore()
    store.add(TestRecord(id: UUID(), date: Date(), downloadMbps: 312.4, uploadMbps: 48.1, pingMs: 14, jitterMs: 2.1, ispName: "Comcast"))
    store.add(TestRecord(id: UUID(), date: Date().addingTimeInterval(-3600), downloadMbps: 180.0, uploadMbps: 32.5, pingMs: 22, jitterMs: 4.0, ispName: "Comcast"))
    return HistoryView(history: store)
}
