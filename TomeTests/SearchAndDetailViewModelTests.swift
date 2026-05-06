import Foundation
import Testing
@testable import Tome

@Suite("SearchViewModel & detail view models")
@MainActor
struct SearchAndDetailViewModelTests {

    private struct Harness {
        let host: String
        let client: ABSClient
        let keychain: KeychainStore
    }

    nonisolated private static func makeHarness() async throws -> Harness {
        let host = "test-\(UUID().uuidString.lowercased()).example"
        let baseURL = URL(string: "https://\(host)")!
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let keychain = KeychainStore(service: "BrownGames.Tome.Test.\(UUID().uuidString)")
        let tokenStore = TokenStore(keychain: keychain)
        try await tokenStore.save(tokens: .init(accessToken: "t", refreshToken: "r"))
        let client = ABSClient(session: session, tokenStore: tokenStore, baseURL: baseURL)
        await client.bindRefreshHandler()
        return Harness(host: host, client: client, keychain: keychain)
    }

    nonisolated private static func teardown(_ h: Harness) async {
        MockURLProtocol.unregister(host: h.host)
        try? await h.keychain.delete(account: TokenStore.AccountKey.accessToken)
        try? await h.keychain.delete(account: TokenStore.AccountKey.refreshToken)
    }

    nonisolated private static func ok(_ url: URL, body: String) -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
         body.data(using: .utf8)!)
    }

    // MARK: - SearchViewModel

    @Test("Search with empty query stays idle and clears results")
    func searchEmptyQuery() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: "{}")
        }

        let vm = SearchViewModel(client: h.client)
        vm.query = "   "
        await vm.runSearch(libraryID: "lib_1")
        #expect(vm.state == .idle)
        #expect(vm.results == nil)
        #expect(MockURLProtocol.capturedRequests(host: h.host).isEmpty)
    }

    @Test("Search hits per-library search endpoint and surfaces results")
    func searchSucceeds() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: """
                {
                  "book": [
                    {
                      "libraryItem": {
                        "id": "li_1",
                        "media": { "metadata": { "title": "Project Hail Mary", "authorName": "Andy Weir" } }
                      },
                      "matchKey": "title", "matchText": "Project Hail Mary"
                    }
                  ],
                  "podcast": [], "tags": [],
                  "authors": [{ "id": "aut_1", "name": "Andy Weir", "numBooks": 3 }],
                  "series": []
                }
                """)
        }

        let vm = SearchViewModel(client: h.client)
        vm.query = "weir"
        await vm.runSearch(libraryID: "lib_1")

        #expect(vm.state == .loaded)
        #expect(vm.hasResults == true)
        #expect(vm.results?.book?.count == 1)
        #expect(vm.results?.authors?.first?.name == "Andy Weir")

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/libraries/lib_1/search")
    }

    @Test("Search transport error transitions to failed")
    func searchTransportError() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = SearchViewModel(client: h.client)
        vm.query = "anything"
        await vm.runSearch(libraryID: "lib_1")

        #expect(vm.errorMessage != nil)
        #expect(vm.hasResults == false)
    }

    // MARK: - BookDetailViewModel

    @Test("BookDetail loads expanded item with progress query params")
    func bookDetailLoad() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: """
                {
                  "id": "li_42",
                  "libraryId": "lib_1",
                  "media": {
                    "metadata": { "title": "Some Book", "authorName": "Some Author" },
                    "chapters": [{ "id": 0, "start": 0.0, "end": 100.0, "title": "Chapter 1" }],
                    "duration": 100.0
                  },
                  "userMediaProgress": { "progress": 0.5, "currentTime": 50.0, "isFinished": false }
                }
                """)
        }

        let vm = BookDetailViewModel(client: h.client, itemID: "li_42")
        await vm.load()

        #expect(vm.state == .loaded)
        #expect(vm.item?.id == "li_42")
        #expect(vm.item?.media?.chapters?.count == 1)
        #expect(vm.item?.userMediaProgress?.progress == 0.5)

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/items/li_42")
        let q = URLComponents(url: captured.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(q.contains(URLQueryItem(name: "expanded", value: "1")))
        #expect(q.contains(URLQueryItem(name: "include", value: "progress")))
    }

    @Test("BookDetail surfaces 404 with friendly message")
    func bookDetail404() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
        }

        let vm = BookDetailViewModel(client: h.client, itemID: "li_missing")
        await vm.load()

        #expect(vm.errorMessage?.contains("isn't on the server") == true)
    }

    // MARK: - AuthorDetailViewModel

    @Test("AuthorDetail loads with library scoping")
    func authorDetailLoad() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: """
                {
                  "id": "aut_1",
                  "libraryId": "lib_1",
                  "name": "Andy Weir",
                  "description": "Bio",
                  "numBooks": 2,
                  "libraryItems": [
                    { "id": "li_a", "media": { "metadata": { "title": "Martian" } } },
                    { "id": "li_b", "media": { "metadata": { "title": "Artemis" } } }
                  ]
                }
                """)
        }

        let vm = AuthorDetailViewModel(client: h.client, authorID: "aut_1", libraryID: "lib_1")
        await vm.load()

        #expect(vm.state == .loaded)
        #expect(vm.author?.libraryItems?.count == 2)

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/authors/aut_1")
        let q = URLComponents(url: captured.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(q.contains(URLQueryItem(name: "library", value: "lib_1")))
        #expect(q.contains(URLQueryItem(name: "include", value: "items")))
    }

    // MARK: - SeriesDetailViewModel

    @Test("SeriesDetail loads books filtered by series id and sequence-sorted")
    func seriesDetailLoad() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            Self.ok(request.url!, body: """
                {
                  "results": [
                    { "id": "li_a", "media": { "metadata": { "title": "Book 1" } } },
                    { "id": "li_b", "media": { "metadata": { "title": "Book 2" } } }
                  ],
                  "total": 2
                }
                """)
        }

        let vm = SeriesDetailViewModel(client: h.client, seriesID: "ser_42", libraryID: "lib_1", name: "The Saga")
        await vm.load()

        #expect(vm.state == .loaded)
        #expect(vm.items.count == 2)

        let captured = try #require(MockURLProtocol.capturedRequests(host: h.host).first)
        #expect(captured.url?.path == "/api/libraries/lib_1/items")
        let q = URLComponents(url: captured.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let dict = Dictionary(uniqueKeysWithValues: q.compactMap { item -> (String, String)? in
            item.value.map { (item.name, $0) }
        })
        // sort key includes the seriesID
        #expect(dict["sort"] == "media.metadata.series.ser_42.sequence")
        // filter is `series.<base64(seriesID)>`
        let expectedFilter = "series." + Data("ser_42".utf8).base64EncodedString()
        #expect(dict["filter"] == expectedFilter)
        #expect(dict["desc"] == "0")
    }
}
