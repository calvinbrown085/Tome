import Foundation
import Testing
@testable import Tome

@Suite("LibrarySelection persistence")
@MainActor
struct LibrarySelectionTests {

    private static func uniqueDefaults() -> UserDefaults {
        let suite = "tome.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test("Initial selectedLibraryID is nil when defaults are empty")
    func emptyDefaults() {
        let selection = LibrarySelection(defaults: Self.uniqueDefaults())
        #expect(selection.selectedLibraryID == nil)
        #expect(selection.libraries.isEmpty)
    }

    @Test("Setting selectedLibraryID persists across instances")
    func persistsAcrossInstances() {
        let defaults = Self.uniqueDefaults()
        let first = LibrarySelection(defaults: defaults)
        first.selectedLibraryID = "lib_chosen"

        let second = LibrarySelection(defaults: defaults)
        #expect(second.selectedLibraryID == "lib_chosen")
    }

    @Test("select(_:) ignores ids not present in the libraries list")
    func selectIgnoresUnknownIds() async throws {
        let selection = LibrarySelection(defaults: Self.uniqueDefaults())
        selection.select("missing")
        #expect(selection.selectedLibraryID == nil)
    }

    @Test("Loading filters out non-book libraries and selects the first one")
    func loadFiltersAndSelects() async throws {
        let host = "test-\(UUID().uuidString.lowercased()).example"
        let baseURL = URL(string: "https://\(host)")!
        MockURLProtocol.register(host: host) { request in
            let body = """
            { "libraries": [
                { "id": "lib_books", "name": "Audiobooks", "mediaType": "book" },
                { "id": "lib_pods", "name": "Podcasts", "mediaType": "podcast" }
            ] }
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        defer { MockURLProtocol.unregister(host: host) }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let keychain = KeychainStore(service: "BrownGames.Tome.Test.\(UUID().uuidString)")
        let tokenStore = TokenStore(keychain: keychain)
        try await tokenStore.save(tokens: .init(accessToken: "t", refreshToken: "r"))
        let client = ABSClient(session: session, tokenStore: tokenStore, baseURL: baseURL)
        await client.bindRefreshHandler()

        let selection = LibrarySelection(defaults: Self.uniqueDefaults())
        await selection.load(using: client)

        #expect(selection.libraries.count == 1)
        #expect(selection.libraries.first?.id == "lib_books")
        #expect(selection.selectedLibraryID == "lib_books")
        #expect(selection.loadState == .loaded)

        try? await keychain.delete(account: TokenStore.AccountKey.accessToken)
        try? await keychain.delete(account: TokenStore.AccountKey.refreshToken)
    }

    @Test("Loading preserves a valid pre-existing selection")
    func loadPreservesValidSelection() async throws {
        let host = "test-\(UUID().uuidString.lowercased()).example"
        let baseURL = URL(string: "https://\(host)")!
        MockURLProtocol.register(host: host) { request in
            let body = """
            { "libraries": [
                { "id": "lib_a", "name": "A", "mediaType": "book" },
                { "id": "lib_b", "name": "B", "mediaType": "book" }
            ] }
            """.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
        }
        defer { MockURLProtocol.unregister(host: host) }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let keychain = KeychainStore(service: "BrownGames.Tome.Test.\(UUID().uuidString)")
        let tokenStore = TokenStore(keychain: keychain)
        try await tokenStore.save(tokens: .init(accessToken: "t", refreshToken: "r"))
        let client = ABSClient(session: session, tokenStore: tokenStore, baseURL: baseURL)
        await client.bindRefreshHandler()

        let defaults = Self.uniqueDefaults()
        let selection = LibrarySelection(defaults: defaults)
        selection.selectedLibraryID = "lib_b"
        await selection.load(using: client)

        #expect(selection.selectedLibraryID == "lib_b")

        try? await keychain.delete(account: TokenStore.AccountKey.accessToken)
        try? await keychain.delete(account: TokenStore.AccountKey.refreshToken)
    }
}
