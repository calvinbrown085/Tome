import Foundation
import Testing
@testable import Tome

@Suite("PlayerEngine session lifecycle (stub service)")
@MainActor
struct PlayerEngineTests {

    nonisolated private static func makeContext(itemID: String = "li_42", startTime: TimeInterval = 0, totalDuration: TimeInterval = 60) -> PlaybackContext {
        PlaybackContext(
            sessionID: "sess_\(itemID)",
            libraryItemID: itemID,
            tracks: [
                PlaybackContext.Track(
                    index: 0, startOffset: 0, duration: 30,
                    url: URL(string: "https://example.com/api/items/\(itemID)/file/a")!,
                    mimeType: "audio/mpeg"
                ),
                PlaybackContext.Track(
                    index: 1, startOffset: 30, duration: 30,
                    url: URL(string: "https://example.com/api/items/\(itemID)/file/b")!,
                    mimeType: "audio/mpeg"
                )
            ],
            chapters: [],
            totalDuration: totalDuration,
            startTime: startTime,
            title: "Test Book",
            author: "Test Author",
            coverItemID: itemID
        )
    }

    nonisolated private static func makeItem(id: String = "li_42") -> LibraryItemDTO {
        LibraryItemDTO(
            id: id, libraryId: "lib", folderId: nil, mediaType: "book",
            isInvalid: nil, isMissing: nil, numFiles: nil, size: nil, addedAt: nil, updatedAt: nil,
            media: MediaDTO(
                libraryItemId: id,
                metadata: BookMetadataDTO(
                    title: "Test Book", titleIgnorePrefix: nil, subtitle: nil,
                    authors: nil, authorName: "Test Author", authorNameLF: nil,
                    narrators: nil, narratorName: nil, series: nil, genres: nil,
                    publishedYear: nil, publishedDate: nil, publisher: nil, description: nil,
                    isbn: nil, asin: nil, language: nil, explicit: nil
                ),
                coverPath: nil, tags: nil, audioFiles: nil, chapters: nil,
                duration: 60, size: nil, numTracks: 2, numAudioFiles: 2, numChapters: 0
            ),
            userMediaProgress: nil
        )
    }

    @Test("play() opens a session and surfaces the title/author/cover")
    func playOpensSession() async throws {
        let stub = StubSessionService(opener: { _ in Self.makeContext() })
        let loader = AuthenticatingAssetLoader(tokenProvider: { "tok" }, tokenRefresher: { "tok" })
        let engine = PlayerEngine(sessionService: stub, assetLoader: loader)

        engine.play(item: Self.makeItem())
        try await Task.sleep(for: .milliseconds(200))

        #expect(engine.nowPlayingTitle == "Test Book")
        #expect(engine.nowPlayingAuthor == "Test Author")
        #expect(engine.coverItemID == "li_42")
        await #expect(stub.openCount() == 1)
    }

    @Test("stop() closes the session and resets state")
    func stopClosesSession() async throws {
        let stub = StubSessionService(opener: { _ in Self.makeContext() })
        let loader = AuthenticatingAssetLoader(tokenProvider: { "tok" }, tokenRefresher: { "tok" })
        let engine = PlayerEngine(sessionService: stub, assetLoader: loader)

        engine.play(item: Self.makeItem())
        try await Task.sleep(for: .milliseconds(200))
        engine.stop()
        try await Task.sleep(for: .milliseconds(200))

        #expect(engine.state == .idle)
        #expect(engine.coverItemID == nil)
        await #expect(stub.closeCount() == 1)
    }

    @Test("playing a different item closes the prior session")
    func playDifferentItemClosesPrior() async throws {
        let stub = StubSessionService(opener: { item in Self.makeContext(itemID: item.id) })
        let loader = AuthenticatingAssetLoader(tokenProvider: { "tok" }, tokenRefresher: { "tok" })
        let engine = PlayerEngine(sessionService: stub, assetLoader: loader)

        engine.play(item: Self.makeItem(id: "first"))
        try await Task.sleep(for: .milliseconds(200))
        engine.play(item: Self.makeItem(id: "second"))
        try await Task.sleep(for: .milliseconds(300))

        await #expect(stub.openCount() == 2)
        await #expect(stub.closeCount() == 1, "starting a 2nd item must close the 1st session")
        let closed = await stub.closedSessions()
        #expect(closed.contains("sess_first"))
    }

    @Test("PlaybackContext.track(forGlobalTime:) maps global time to the right track")
    func contextTrackLookup() {
        let ctx = Self.makeContext(startTime: 0, totalDuration: 60)
        #expect(ctx.track(forGlobalTime: 0)?.index == 0)
        #expect(ctx.track(forGlobalTime: 15)?.index == 0)
        #expect(ctx.track(forGlobalTime: 30)?.index == 1)
        #expect(ctx.track(forGlobalTime: 59)?.index == 1)
        #expect(ctx.track(forGlobalTime: 9999)?.index == 1, "past end clamps to last track")
    }
}

/// Trivial in-memory stub of `PlaybackSessionServicing`. Synchronizes counters with an actor.
private actor StubSessionService: PlaybackSessionServicing {
    typealias Opener = @Sendable (LibraryItemDTO) -> PlaybackContext
    private let opener: Opener
    private var opens = 0
    private var closes = 0
    private var syncs: [(id: String, currentTime: TimeInterval)] = []
    private var closed: [String] = []

    init(opener: @escaping Opener) { self.opener = opener }

    func openSession(item: LibraryItemDTO) async throws -> PlaybackContext {
        opens += 1
        return opener(item)
    }
    func syncSession(id: String, currentTime: TimeInterval, timeListened: TimeInterval, duration: TimeInterval) async throws {
        syncs.append((id: id, currentTime: currentTime))
    }
    func closeSession(id: String, currentTime: TimeInterval, timeListened: TimeInterval, duration: TimeInterval) async throws {
        closes += 1
        closed.append(id)
    }

    func openCount() -> Int { opens }
    func closeCount() -> Int { closes }
    func syncCount() -> Int { syncs.count }
    func closedSessions() -> [String] { closed }
}
