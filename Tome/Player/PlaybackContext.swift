import Foundation

/// Immutable snapshot of an opened ABS playback session — all state the
/// `PlayerEngine` needs to construct an `AVQueuePlayer` and report progress.
nonisolated struct PlaybackContext: Sendable {
    struct Track: Sendable, Identifiable {
        var id: Int { index }
        let index: Int
        /// Global offset (seconds) of this track within the whole book.
        let startOffset: TimeInterval
        let duration: TimeInterval
        /// Absolute URL on the server (the auth-aware loader rewrites the scheme later).
        let url: URL
        let mimeType: String?
    }

    let sessionID: String
    let libraryItemID: String
    let tracks: [Track]
    let chapters: [ChapterDTO]
    let totalDuration: TimeInterval
    /// Server-reported resume position (seconds, global).
    let startTime: TimeInterval
    let title: String
    let author: String
    /// `LibraryItemDTO.id` — used by `AuthedAsyncImage` to fetch cover art via the existing path.
    let coverItemID: String

    /// Returns the track containing the given global time, or the last track if past the end.
    func track(forGlobalTime t: TimeInterval) -> Track? {
        guard !tracks.isEmpty else { return nil }
        for track in tracks where t >= track.startOffset && t < track.startOffset + track.duration {
            return track
        }
        return tracks.last
    }
}
