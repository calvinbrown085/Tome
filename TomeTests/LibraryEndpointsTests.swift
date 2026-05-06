import Foundation
import Testing
@testable import Tome

@Suite("ABSClient library endpoints")
struct LibraryEndpointsTests {

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

    private static func ok(_ url: URL, body: String) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
         body.data(using: .utf8)!)
    }

    @Test("listLibraries hits /api/libraries with bearer auth")
    func listLibrariesRequest() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: """
                { "libraries": [ { "id": "lib_1", "name": "Books", "mediaType": "book" } ] }
                """)
        }

        let libs = try await h.client.listLibraries()
        #expect(libs.count == 1)
        #expect(libs[0].id == "lib_1")

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/libraries")
        #expect(captured.httpMethod == "GET")
        #expect(captured.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }

    @Test("libraryItems sends pagination + sort + filter as query items")
    func libraryItemsRequestBuildsQuery() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: """
                { "results": [], "total": 0, "limit": 25, "page": 2 }
                """)
        }

        _ = try await h.client.libraryItems(
            libraryID: "lib_1",
            limit: 25,
            page: 2,
            sort: "media.metadata.title",
            desc: true,
            filter: "progress.in-progress"
        )

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/libraries/lib_1/items")
        let items = URLComponents(url: captured.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let asDict = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            item.value.map { (item.name, $0) }
        })
        #expect(asDict["limit"] == "25")
        #expect(asDict["page"] == "2")
        #expect(asDict["sort"] == "media.metadata.title")
        #expect(asDict["desc"] == "1")
        #expect(asDict["filter"] == "progress.in-progress")
        #expect(asDict["minified"] == "1")
    }

    @Test("librarySeries hits the series endpoint")
    func librarySeriesRequest() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: """
                { "results": [], "total": 0 }
                """)
        }

        _ = try await h.client.librarySeries(libraryID: "lib_1")

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/libraries/lib_1/series")
    }

    @Test("libraryItem includes expanded + progress query")
    func libraryItemExpandedQuery() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: """
                { "id": "li_42", "media": { "metadata": { "title": "X" } } }
                """)
        }

        let item = try await h.client.libraryItem(id: "li_42")
        #expect(item.id == "li_42")

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/items/li_42")
        let q = URLComponents(url: captured.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(q.contains(URLQueryItem(name: "expanded", value: "1")))
        #expect(q.contains(URLQueryItem(name: "include", value: "progress")))
    }

    @Test("author endpoint includes items by default")
    func authorRequest() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: """
                { "id": "aut_1", "name": "X" }
                """)
        }

        _ = try await h.client.author(id: "aut_1", libraryID: "lib_1")

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/authors/aut_1")
        let q = URLComponents(url: captured.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(q.contains(URLQueryItem(name: "include", value: "items")))
        #expect(q.contains(URLQueryItem(name: "library", value: "lib_1")))
    }

    @Test("search hits the per-library search endpoint")
    func searchRequest() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: """
                { "book": [], "podcast": [], "tags": [], "authors": [], "series": [] }
                """)
        }

        _ = try await h.client.search(libraryID: "lib_1", query: "weir")

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/libraries/lib_1/search")
        let q = URLComponents(url: captured.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(q.contains(URLQueryItem(name: "q", value: "weir")))
        #expect(q.contains(URLQueryItem(name: "limit", value: "12")))
    }

    @Test("coverArtData fetches raw bytes with bearer auth")
    func coverArtFetch() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        let pngHeader = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        MockURLProtocol.register(host: h.host) { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                             headerFields: ["Content-Type": "image/png"])!, pngHeader)
        }

        let data = try await h.client.coverArtData(itemID: "li_42")
        #expect(data == pngHeader)

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/items/li_42/cover")
        #expect(captured.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
    }
}
