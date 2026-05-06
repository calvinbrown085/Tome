import Foundation
import Testing
@testable import Tome

@Suite("LibraryHomeViewModel")
@MainActor
struct LibraryHomeViewModelTests {

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

    nonisolated private static func itemsBody(start: Int, count: Int) -> String {
        let entries = (start..<(start + count)).map { i in
            """
            { "id": "li_\(i)", "media": { "metadata": { "title": "Book \(i)", "authorName": "A" } } }
            """
        }.joined(separator: ",")
        return """
        { "results": [\(entries)], "total": \(count) }
        """
    }

    @Test("Parallel load: both shelves populate; correct filter + sort per shelf")
    func bothShelvesPopulate() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        let inProgressFilter = LibraryFilter.inProgress.apiValue!
        MockURLProtocol.register(host: h.host) { request in
            let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let dict = Dictionary(uniqueKeysWithValues: q.compactMap { item -> (String, String)? in
                item.value.map { (item.name, $0) }
            })
            // Differentiate by query: filter present → in-progress shelf, else recently-added
            let isInProgress = dict["filter"] == inProgressFilter
            let body = isInProgress
                ? Self.itemsBody(start: 0, count: 3)
                : Self.itemsBody(start: 100, count: 5)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    body.data(using: .utf8)!)
        }

        let vm = LibraryHomeViewModel(client: h.client, libraryID: "lib_1")
        await vm.load()

        #expect(vm.inProgressState == .loaded)
        #expect(vm.recentlyAddedState == .loaded)
        #expect(vm.inProgressItems.count == 3)
        #expect(vm.recentlyAddedItems.count == 5)
        #expect(vm.inProgressItems.first?.id == "li_0")
        #expect(vm.recentlyAddedItems.first?.id == "li_100")

        let captured = MockURLProtocol.capturedRequests(host: h.host)
        #expect(captured.count == 2)

        // Verify the recently-added request specifies sort=addedAt and no filter.
        let recentRequest = try #require(captured.first(where: {
            URLComponents(url: $0.url!, resolvingAgainstBaseURL: false)?
                .queryItems?.contains(where: { $0.name == "filter" }) == false
        }))
        let recentQuery = URLComponents(url: recentRequest.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(recentQuery.contains(URLQueryItem(name: "sort", value: "addedAt")))
        #expect(recentQuery.contains(URLQueryItem(name: "desc", value: "1")))
    }

    @Test("Partial failure: one shelf fails, the other still loads")
    func partialFailure() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        let inProgressFilter = LibraryFilter.inProgress.apiValue!
        MockURLProtocol.register(host: h.host) { request in
            let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let isInProgress = q.contains { $0.name == "filter" && $0.value == inProgressFilter }
            if isInProgress {
                return (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Self.itemsBody(start: 0, count: 4).data(using: .utf8)!)
        }

        let vm = LibraryHomeViewModel(client: h.client, libraryID: "lib_1")
        await vm.load()

        if case .failed = vm.inProgressState { } else {
            Issue.record("Expected inProgressState to be .failed, got \(vm.inProgressState)")
        }
        #expect(vm.recentlyAddedState == .loaded)
        #expect(vm.recentlyAddedItems.count == 4)
        #expect(vm.hasAnyError == true)
    }

    @Test("Empty in-progress shelf surfaces as .empty (so the UI can hide the row)")
    func emptyShelf() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             """
             { "results": [], "total": 0 }
             """.data(using: .utf8)!)
        }

        let vm = LibraryHomeViewModel(client: h.client, libraryID: "lib_1")
        await vm.load()

        #expect(vm.inProgressState == .empty)
        #expect(vm.recentlyAddedState == .empty)
        #expect(vm.hasAnyError == false)
    }
}
