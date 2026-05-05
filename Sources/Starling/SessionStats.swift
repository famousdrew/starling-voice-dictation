import Foundation

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let audioSeconds: Double
    let wordCount: Int
    let transcript: String
}

/// Persists per-session dictation records to JSON in Application Support.
///
/// Used as both the data layer and the SwiftUI observable for the stats UI.
@MainActor
final class SessionStats: ObservableObject {
    @Published private(set) var sessions: [SessionRecord] = []

    private let url: URL

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Starling", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent("stats.json")
        load()
    }

    func record(audioSeconds: Double, transcript: String) {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace }).count
        let session = SessionRecord(
            id: UUID(),
            timestamp: Date(),
            audioSeconds: audioSeconds,
            wordCount: words,
            transcript: trimmed
        )
        sessions.append(session)
        persist()
    }

    // MARK: - Aggregates used by the UI

    /// Word count for sessions whose timestamp falls within `Calendar.current` today.
    var wordsToday: Int {
        let cal = Calendar.current
        return sessions
            .filter { cal.isDateInToday($0.timestamp) }
            .reduce(0) { $0 + $1.wordCount }
    }

    var wordsLast7Days: Int {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        return sessions
            .filter { $0.timestamp >= cutoff }
            .reduce(0) { $0 + $1.wordCount }
    }

    var wordsLifetime: Int {
        sessions.reduce(0) { $0 + $1.wordCount }
    }

    /// Words per minute of *audio* time — i.e., speaking rate.
    var averageWPM: Int {
        let totalSeconds = sessions.reduce(0.0) { $0 + $1.audioSeconds }
        guard totalSeconds > 0 else { return 0 }
        return Int(Double(wordsLifetime) / (totalSeconds / 60))
    }

    /// Words-per-day for the last 30 days, ordered oldest → newest.
    /// Days with no sessions are emitted as 0 so a chart can render evenly.
    func wordsPerDay(days: Int = 30) -> [(date: Date, words: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var totals: [Date: Int] = [:]
        for session in sessions {
            let day = cal.startOfDay(for: session.timestamp)
            totals[day, default: 0] += session.wordCount
        }
        return (0..<days).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            return (day, totals[day] ?? 0)
        }
    }

    var recentSessions: [SessionRecord] {
        Array(sessions.suffix(10).reversed())
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([SessionRecord].self, from: data) {
            sessions = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(sessions)
            try data.write(to: url, options: .atomic)
        } catch {
            fputs("stats persist error: \(error)\n", stderr)
        }
    }
}
