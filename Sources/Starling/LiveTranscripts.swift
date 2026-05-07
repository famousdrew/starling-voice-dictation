import Foundation

/// In-memory log of transcripts produced during the current app session,
/// observed by the Playground tab so the user can see what got pasted without
/// leaving the focused app.
@MainActor
final class LiveTranscripts: ObservableObject {
    @Published var entries: [String] = []

    func append(_ text: String) {
        entries.append(text)
    }
}
