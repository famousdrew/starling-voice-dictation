import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var stats: SessionStats
    @State private var playgroundText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                cards
                chart
                recent
                Divider()
                playground
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 640)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(stats.wordsToday.formatted()) words")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
        }
    }

    private var cards: some View {
        HStack(spacing: 12) {
            StatCard(label: "Last 7 days", value: stats.wordsLast7Days.formatted())
            StatCard(label: "Lifetime", value: stats.wordsLifetime.formatted())
            StatCard(label: "Avg WPM", value: "\(stats.averageWPM)")
        }
    }

    private var chart: some View {
        let data = stats.wordsPerDay(days: 30)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Last 30 days")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Chart(data, id: \.date) { entry in
                BarMark(
                    x: .value("Day", entry.date, unit: .day),
                    y: .value("Words", entry.words)
                )
                .foregroundStyle(.tint)
                .cornerRadius(2)
            }
            .frame(height: 120)
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent sessions")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if stats.recentSessions.isEmpty {
                Text("No sessions yet — try dictating something.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            } else {
                ForEach(stats.recentSessions) { session in
                    SessionRow(session: session)
                    Divider()
                }
            }
        }
    }

    private var playground: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test playground")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Click into the field, then hold Right Option (or double-tap for hands-free) to dictate. The transcript pastes here just like any other app.")
                .font(.callout)
                .foregroundStyle(.secondary)
            TextEditor(text: $playgroundText)
                .font(.body)
                .frame(minHeight: 120)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator)
                )
            HStack {
                Spacer()
                Button("Clear") { playgroundText = "" }
                    .disabled(playgroundText.isEmpty)
            }
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SessionRow: View {
    let session: SessionRecord

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(session.wordCount) words · \(formatDuration(session.audioSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 140, alignment: .leading)
            Text(session.transcript)
                .lineLimit(2)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
