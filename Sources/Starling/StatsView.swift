import SwiftUI
import Charts
import AppKit

enum StatsTab: Hashable {
    case overview, sessions, playground, vocabulary, settings
}

struct StatsView: View {
    @ObservedObject var stats: SessionStats
    @ObservedObject var corrections: Corrections
    @ObservedObject var liveTranscripts: LiveTranscripts
    @Binding var selection: StatsTab

    var body: some View {
        TabView(selection: $selection) {
            OverviewTab(stats: stats)
                .tabItem { Label("Overview", systemImage: "chart.bar") }
                .tag(StatsTab.overview)

            SessionsTab(stats: stats)
                .tabItem { Label("Sessions", systemImage: "list.bullet") }
                .tag(StatsTab.sessions)

            PlaygroundTab(liveTranscripts: liveTranscripts)
                .tabItem { Label("Playground", systemImage: "text.cursor") }
                .tag(StatsTab.playground)

            VocabularyTab(corrections: corrections)
                .tabItem { Label("Vocabulary", systemImage: "character.book.closed") }
                .tag(StatsTab.vocabulary)

            SettingsTab()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(StatsTab.settings)
        }
        .frame(minWidth: 640, minHeight: 560)
        .padding(.top, 8)
    }
}

// MARK: - Overview

private struct OverviewTab: View {
    @ObservedObject var stats: SessionStats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(stats.wordsToday.formatted()) words")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                }
                HStack(spacing: 12) {
                    StatCard(label: "Last 7 days", value: stats.wordsLast7Days.formatted())
                    StatCard(label: "Lifetime", value: stats.wordsLifetime.formatted())
                    StatCard(label: "Avg WPM", value: "\(stats.averageWPM)")
                }
                let data = stats.wordsPerDay(days: 30)
                VStack(alignment: .leading, spacing: 8) {
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
                    .frame(height: 140)
                    .chartYAxis { AxisMarks(position: .leading) }
                }
            }
            .padding(24)
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

// MARK: - Sessions

private struct SessionsTab: View {
    @ObservedObject var stats: SessionStats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if stats.recentSessions.isEmpty {
                    Text("No sessions yet — try dictating something.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .padding()
                } else {
                    ForEach(stats.recentSessions) { session in
                        SessionRow(session: session)
                        Divider()
                    }
                }
            }
            .padding(24)
        }
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
                .lineLimit(3)
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

// MARK: - Playground

private struct PlaygroundTab: View {
    @ObservedObject var liveTranscripts: LiveTranscripts
    @State private var playgroundText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test playground")
                .font(.headline)
            Text("Click into the field, then hold Right Option (or double-tap for hands-free) to dictate. The transcript pastes here just like any other app.")
                .font(.callout)
                .foregroundStyle(.secondary)

            TextEditor(text: $playgroundText)
                .font(.body)
                .frame(minHeight: 100)
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

            Divider().padding(.vertical, 4)

            Text("Transcript log")
                .font(.headline)
            Text("Each completed dictation appears here, regardless of where it pasted.")
                .font(.callout)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if liveTranscripts.entries.isEmpty {
                        Text("(no transcripts yet)")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                            .padding(8)
                    } else {
                        ForEach(Array(liveTranscripts.entries.enumerated().reversed()), id: \.offset) { _, text in
                            Text(text)
                                .font(.callout)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(4)
            }
            .frame(minHeight: 120, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.separator)
            )
        }
        .padding(24)
    }
}

// MARK: - Vocabulary

private struct VocabularyTab: View {
    @ObservedObject var corrections: Corrections

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vocabulary")
                .font(.headline)
            Text("Teach Starling how to spell product names and jargon. The left column is what the model hears; the right column is what gets pasted. Matching is case-insensitive.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack {
                Button {
                    corrections.addBlank()
                } label: {
                    Label("Add correction", systemImage: "plus")
                }
                Spacer()
                Text("\(corrections.entries.count) entries")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            ScrollView {
                VStack(spacing: 6) {
                    if corrections.entries.isEmpty {
                        Text("No corrections yet.")
                            .foregroundStyle(.tertiary)
                            .font(.callout)
                            .padding()
                    } else {
                        ForEach($corrections.entries) { $entry in
                            HStack(spacing: 8) {
                                TextField("heard as", text: $entry.heard)
                                    .textFieldStyle(.roundedBorder)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.tertiary)
                                TextField("pastes as", text: $entry.pastesAs)
                                    .textFieldStyle(.roundedBorder)
                                Button {
                                    corrections.remove(id: entry.id)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
                .padding(8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.separator)
            )
        }
        .padding(24)
    }
}

// MARK: - Settings

private struct SettingsTab: View {
    @State private var launchAtLogin: Bool = LoginItem.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Launch at Login")
                    .font(.headline)
                Toggle("Open Starling automatically when you log in", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, new in
                        LoginItem.setEnabled(new)
                    }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Hotkey")
                    .font(.headline)
                Text("Hold Right Option to dictate. Double-tap for hands-free; Escape cancels.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Files")
                    .font(.headline)
                Text("Stats and corrections live at ~/Library/Application Support/Starling.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
            }

            Spacer()

            HStack {
                Spacer()
                Button(role: .destructive) {
                    NSApp.terminate(nil)
                } label: {
                    Text("Quit Starling")
                }
            }
        }
        .padding(24)
    }
}
