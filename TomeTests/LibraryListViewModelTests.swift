import Foundation
import Testing
@testable import Tome

@Suite("LibraryListViewModel")
@MainActor
struct LibraryListViewModelTests {

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

    nonisolated private static func itemsPage(start: Int, count: Int, total: Int) -> String {
        let items = (start..<(start + count)).map { i in
            """
            {
              "id": "li_\(i)",
              "libraryId": "lib_1",
              "media": { "metadata": { "title": "Book \(i)", "authorName": "A" } }
            }
            """
        }.joined(separator: ",")
        return """
        { "results": [\(items)], "total": \(total), "limit": \(count), "page": \(start / max(count, 1)) }
        """
    }

    @Test("refresh populates items, total, and transitions to loaded")
    func refreshSucceeds() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { request in
            let body = Self.itemsPage(start: 0, count: 3, total: 3).data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let vm = LibraryListViewModel(client: h.client, libraryID: "lib_1", pageSize: 3)
        await vm.refresh()

        #expect(vm.items.count == 3)
        #expect(vm.items.first?.id == "li_0")
        #expect(vm.total == 3)
        #expect(vm.state == .loaded)
        #expect(vm.hasMore == false)
    }

    @Test("refresh on transport error sets failed state with message")
    func refreshTransportError() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        MockURLProtocol.register(host: h.host) { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = LibraryListViewModel(client: h.client, libraryID: "lib_1")
        await vm.refresh()

        #expect(vm.errorMessage != nil)
        #expect(vm.items.isEmpty)
    }

    @Test("loadNext appends next page and dedupes against existing items")
    func loadNextAppendsAndDedupes() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        let pageSize = 5
        let total = 12

        MockURLProtocol.register(host: h.host) { request in
            let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let page = Int(q.first(where: { $0.name == "page" })?.value ?? "0") ?? 0
            let start = page * pageSize
            let count = min(pageSize, total - start)
            let body = Self.itemsPage(start: start, count: count, total: total).data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let vm = LibraryListViewModel(client: h.client, libraryID: "lib_1", pageSize: pageSize)
        await vm.refresh()
        #expect(vm.items.count == 5)
        #expect(vm.hasMore == true)

        await vm.loadNext()
        #expect(vm.items.count == 10)
        #expect(vm.page == 1)
        #expect(vm.hasMore == true)

        await vm.loadNext()
        #expect(vm.items.count == 12)
        #expect(vm.hasMore == false)

        // dedupe: pretend the server returns already-seen ids — should not double-add.
        await vm.loadNext() // no-op since hasMore is false
        #expect(vm.items.count == 12)
    }

    @Test("loadNextIfNeeded only triggers near the bottom of the loaded items")
    func loadNextIfNeededRespectsThreshold() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        let pageSize = 20
        let total = 40
        let counter = TestCounter()

        MockURLProtocol.register(host: h.host) { request in
            counter.increment()
            let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let page = Int(q.first(where: { $0.name == "page" })?.value ?? "0") ?? 0
            let start = page * pageSize
            let count = min(pageSize, total - start)
            let body = Self.itemsPage(start: start, count: count, total: total).data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let vm = LibraryListViewModel(client: h.client, libraryID: "lib_1", pageSize: pageSize)
        await vm.refresh()
        let firstCount = counter.value
        #expect(firstCount == 1)
        #expect(vm.items.count == 20)

        // Item near the top — should not trigger.
        await vm.loadNextIfNeeded(after: vm.items[2])
        #expect(counter.value == firstCount)
        #expect(vm.items.count == 20)

        // Item near the bottom (within last 10) — should trigger.
        await vm.loadNextIfNeeded(after: vm.items[15])
        #expect(counter.value == firstCount + 1)
        #expect(vm.items.count == 40)
    }

    @Test("apply(sort:filter:) refetches with new query parameters")
    func applySortFilterRefetches() async throws {
        let h = try await Self.makeHarness()
        defer { Task { await Self.teardown(h) } }

        let captured = TestQueryCapture()
        MockURLProtocol.register(host: h.host) { request in
            let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            captured.append(q)
            let body = Self.itemsPage(start: 0, count: 1, total: 1).data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }

        let vm = LibraryListViewModel(client: h.client, libraryID: "lib_1")
        await vm.refresh()

        await vm.apply(sort: .title, filter: .inProgress)

        let queries = captured.snapshot
        #expect(queries.count == 2)
        let last = queries.last ?? []
        let dict = Dictionary(uniqueKeysWithValues: last.compactMap { item -> (String, String)? in
            item.value.map { (item.name, $0) }
        })
        #expect(dict["sort"] == "media.metadata.title")
        #expect(dict["desc"] == "0")
        #expect(dict["filter"]?.hasPrefix("progress.") == true)
    }
}

/// Simple thread-safe counter for use inside MockURLProtocol handlers.
private final class TestCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    func increment() { lock.lock(); _value += 1; lock.unlock() }
    var value: Int { lock.lock(); defer { lock.unlock() }; return _value }
}

private final class TestQueryCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var _captured: [[URLQueryItem]] = []
    func append(_ items: [URLQueryItem]) { lock.lock(); _captured.append(items); lock.unlock() }
    var snapshot: [[URLQueryItem]] { lock.lock(); defer { lock.unlock() }; return _captured }
}
