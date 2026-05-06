import Foundation
import Testing
@testable import Tome

@Suite("ABSClient playback session endpoints")
struct PlaybackSessionEndpointsTests {

    private struct Harness {
        let host: String
        let baseURL: URL
        let client: ABSClient
        let keychain: KeychainStore
    }

    private static func makeHarness() async throws -> Harness {
        let host = "test-\(UUID().uuidString.lowercased()).example"
        let baseURL = URL(string: "https://\(host)")!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let keychain = KeychainStore(service: "BrownGames.Tome.Test.\(UUID().uuidString)")
        let tokenStore = TokenStore(keychain: keychain)
        try await tokenStore.save(tokens: .init(accessToken: "test-token", refreshToken: "test-refresh"))
        let client = ABSClient(session: session, tokenStore: tokenStore, baseURL: baseURL)
        await client.bindRefreshHandler()
        return Harness(host: host, baseURL: baseURL, client: client, keychain: keychain)
    }

    private static func teardown(_ h: Harness) async {
        MockURLProtocol.unregister(host: h.host)
        try? await h.keychain.delete(account: TokenStore.AccountKey.accessToken)
        try? await h.keychain.delete(account: TokenStore.AccountKey.refreshToken)
    }

    private static let openSessionResponse = """
    {
      "id": "play_session_42",
      "userId": "u1",
      "libraryId": "lib_books",
      "libraryItemId": "li_42",
      "mediaType": "book",
      "displayTitle": "Project Hail Mary",
      "displayAuthor": "Andy Weir",
      "duration": 60.0,
      "playMethod": 1,
      "mediaPlayer": "AVPlayer",
      "currentTime": 12.5,
      "audioTracks": [
        {
          "index": 1,
          "startOffset": 0.0,
          "duration": 60.0,
          "title": "track-1.mp3",
          "contentUrl": "/api/items/li_42/file/abc123",
          "mimeType": "audio/mpeg",
          "codec": "mp3"
        }
      ],
      "chapters": []
    }
    """

    @Test("openPlaybackSession POSTs camelCase body to /api/items/:id/play with bearer auth")
    func openSessionRequestShape() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Self.openSessionResponse.data(using: .utf8)!)
        }

        let device = PlaySessionDeviceInfoDTO(
            deviceId: "dev-1",
            clientName: "Tome",
            clientVersion: "1.0",
            manufacturer: "Apple",
            model: "iPhone17,1",
            osName: "iOS",
            osVersion: "18.0"
        )
        let session = try await h.client.openPlaybackSession(itemID: "li_42", deviceInfo: device)
        #expect(session.id == "play_session_42")
        #expect(session.audioTracks?.count == 1)
        #expect(session.audioTracks?.first?.contentUrl == "/api/items/li_42/file/abc123")
        #expect(session.currentTime == 12.5)

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/items/li_42/play")
        #expect(captured.httpMethod == "POST")
        #expect(captured.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(captured.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let bodyData = try #require(captured.bodyData())
        let json = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(json["forceDirectPlay"] as? Bool == true, "ABS expects camelCase forceDirectPlay")
        #expect(json["mediaPlayer"] as? String == "AVPlayer")
        let supported = try #require(json["supportedMimeTypes"] as? [String])
        #expect(supported.contains("audio/mpeg"))
    }

    @Test("syncPlaybackSession POSTs to /api/session/:id/sync")
    func syncSessionRequestShape() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{}".data(using: .utf8)!)
        }

        try await h.client.syncPlaybackSession(id: "play_session_42", currentTime: 31.0, timeListened: 30.0, duration: 60.0)

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/session/play_session_42/sync")
        #expect(captured.httpMethod == "POST")
        let body = try #require(captured.bodyData())
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["currentTime"] as? Double == 31.0)
        #expect(json["timeListened"] as? Double == 30.0)
        #expect(json["duration"] as? Double == 60.0)
    }

    @Test("closePlaybackSession POSTs to /api/session/:id/close")
    func closeSessionRequestShape() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{}".data(using: .utf8)!)
        }

        try await h.client.closePlaybackSession(id: "play_session_42", currentTime: 45.0, timeListened: 60.0, duration: 60.0)

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/session/play_session_42/close")
        #expect(captured.httpMethod == "POST")
    }

    @Test("openPlaybackSession 401 triggers refresh and retries with new token")
    func openSession401TriggersRefresh() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            let path = request.url?.path ?? ""
            if path == "/auth/refresh" {
                let body = #"{"access_token":"new-access","refresh_token":"new-refresh"}"#.data(using: .utf8)!
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            }
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if auth == "Bearer new-access" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                        Self.openSessionResponse.data(using: .utf8)!)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let session = try await h.client.openPlaybackSession(itemID: "li_42", deviceInfo: nil)
        #expect(session.id == "play_session_42")

        let captured = MockURLProtocol.capturedRequests(host: h.host)
        let refreshes = captured.filter { $0.url?.path == "/auth/refresh" }
        #expect(refreshes.count == 1)
        let playCalls = captured.filter { $0.url?.path == "/api/items/li_42/play" }
        #expect(playCalls.count == 2)
        #expect(playCalls.first?.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        #expect(playCalls.last?.value(forHTTPHeaderField: "Authorization") == "Bearer new-access")
    }
}

private extension URLRequest {
    /// MockURLProtocol receives requests with `httpBody` cleared (Foundation moves it to a stream
    /// when a body is present). Read whichever side has the bytes.
    func bodyData() -> Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufSize = 4096
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bufSize)
        defer { buf.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buf, maxLength: bufSize)
            if read <= 0 { break }
            data.append(buf, count: read)
        }
        return data
    }
}
