import Foundation
import Testing
@testable import Tome

@Suite("PlaybackSessionDTO decoding")
struct PlaybackSessionDTOTests {

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    @Test("decodes a multi-track session response with chapters")
    func decodeMultiTrack() throws {
        let json = """
        {
          "id": "play_session_42",
          "userId": "u1",
          "libraryId": "lib_books",
          "libraryItemId": "li_42",
          "mediaType": "book",
          "displayTitle": "Project Hail Mary",
          "displayAuthor": "Andy Weir",
          "coverPath": "/li_42/cover.jpg",
          "duration": 64800.0,
          "playMethod": 1,
          "mediaPlayer": "AVPlayer",
          "timeListening": 0,
          "startedAt": 1700000000000,
          "updatedAt": 1700000000000,
          "currentTime": 1234.5,
          "audioTracks": [
            {
              "index": 1,
              "startOffset": 0.0,
              "duration": 32400.0,
              "title": "part-1.mp3",
              "contentUrl": "/api/items/li_42/file/ino_a",
              "mimeType": "audio/mpeg",
              "codec": "mp3",
              "metadata": { "filename": "part-1.mp3", "ext": ".mp3", "path": "/audiobooks/li_42/part-1.mp3", "size": 12345 }
            },
            {
              "index": 2,
              "startOffset": 32400.0,
              "duration": 32400.0,
              "title": "part-2.mp3",
              "contentUrl": "/api/items/li_42/file/ino_b",
              "mimeType": "audio/mpeg",
              "codec": "mp3"
            }
          ],
          "chapters": [
            { "id": 0, "start": 0.0, "end": 1800.0, "title": "Chapter 1" },
            { "id": 1, "start": 1800.0, "end": 3600.0, "title": "Chapter 2" }
          ]
        }
        """.data(using: .utf8)!

        let session = try Self.decoder.decode(PlaybackSessionDTO.self, from: json)
        #expect(session.id == "play_session_42")
        #expect(session.libraryItemId == "li_42")
        #expect(session.duration == 64800.0)
        #expect(session.currentTime == 1234.5)

        let tracks = try #require(session.audioTracks)
        #expect(tracks.count == 2)
        #expect(tracks[0].startOffset == 0.0)
        #expect(tracks[1].startOffset == 32400.0)
        // Global time math: track2.startOffset + track2.localCurrentTime
        let globalAtTrack2_5min = (tracks[1].startOffset ?? 0) + 300.0
        #expect(globalAtTrack2_5min == 32700.0)
        #expect(tracks[0].contentUrl == "/api/items/li_42/file/ino_a")
        #expect(tracks[0].metadata?.filename == "part-1.mp3")

        let chapters = try #require(session.chapters)
        #expect(chapters.count == 2)
        #expect(chapters[0].title == "Chapter 1")
    }

    @Test("decodes a single-track session with no chapters")
    func decodeSingleTrack() throws {
        let json = """
        {
          "id": "play_session_99",
          "libraryItemId": "li_99",
          "duration": 60.0,
          "currentTime": 0.0,
          "audioTracks": [
            {
              "index": 1,
              "startOffset": 0.0,
              "duration": 60.0,
              "contentUrl": "/api/items/li_99/file/x",
              "mimeType": "audio/mp4",
              "codec": "aac"
            }
          ],
          "chapters": []
        }
        """.data(using: .utf8)!

        let session = try Self.decoder.decode(PlaybackSessionDTO.self, from: json)
        #expect(session.audioTracks?.count == 1)
        #expect(session.chapters?.isEmpty == true)
        #expect(session.audioTracks?.first?.codec == "aac")
    }
}
