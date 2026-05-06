import Foundation
import Testing
@testable import Tome

@Suite("TokenStore single-flight refresh")
struct TokenRefreshTests {

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static func uniqueKeychain() -> KeychainStore {
        KeychainStore(service: "BrownGames.Tome.Test.\(UUID().uuidString)")
    }

    private static func uniqueHost() -> (host: String, baseURL: URL) {
        let host = "test-\(UUID().uuidString.lowercased()).example"
        return (host, URL(string: "https://\(host)")!)
    }

    @Test("Five concurrent 401s collapse to a single /auth/refresh call")
    func collapsesConcurrent401s() async throws {
        let (host, baseURL) = Self.uniqueHost()

        MockURLProtocol.register(host: host) { request in
            let path = request.url?.path ?? ""
            if path == "/auth/refresh" {
                let body = #"{"access_token":"new-access","refresh_token":"new-refresh"}"#.data(using: .utf8)!
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, body)
            }
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if auth == "Bearer new-access" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "{}".data(using: .utf8)!)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let keychain = Self.uniqueKeychain()
        defer {
            MockURLProtocol.unregister(host: host)
            Task { await TokenRefreshTests.cleanup(keychain) }
        }

        let tokenStore = TokenStore(keychain: keychain)
        try await tokenStore.save(tokens: .init(accessToken: "old-access", refreshToken: "old-refresh"))

        let client = ABSClient(session: Self.makeSession(), tokenStore: tokenStore, baseURL: baseURL)
        await client.bindRefreshHandler()

        struct EmptyResponse: Decodable, Sendable {}

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    do {
                        let _: EmptyResponse = try await client.perform(APIRequest(path: "/api/me"))
                        return true
                    } catch {
                        return false
                    }
                }
            }
            var succeeded = 0
            for await ok in group {
                if ok { succeeded += 1 }
            }
            #expect(succeeded == 5, "all 5 concurrent calls should succeed after refresh")
        }

        let captured = MockURLProtocol.capturedRequests(host: host)
        let refreshCalls = captured.filter { $0.url?.path == "/auth/refresh" }
        let retriedWithNew = captured.filter {
            ($0.url?.path ?? "").hasPrefix("/api") &&
            $0.value(forHTTPHeaderField: "Authorization") == "Bearer new-access"
        }
        let initialWithOld = captured.filter {
            ($0.url?.path ?? "").hasPrefix("/api") &&
            $0.value(forHTTPHeaderField: "Authorization") == "Bearer old-access"
        }

        #expect(refreshCalls.count == 1, "expected exactly 1 /auth/refresh call, got \(refreshCalls.count)")
        #expect(initialWithOld.count == 5, "expected 5 initial /api/me calls with old token, got \(initialWithOld.count)")
        #expect(retriedWithNew.count == 5, "expected 5 retries with new token, got \(retriedWithNew.count)")

        let storedAccess = try await tokenStore.currentAccessToken()
        #expect(storedAccess == "new-access")
    }

    @Test("A failed refresh propagates and clears credentials")
    func failedRefreshClearsCredentials() async throws {
        let (host, baseURL) = Self.uniqueHost()

        MockURLProtocol.register(host: host) { request in
            let path = request.url?.path ?? ""
            if path == "/auth/refresh" {
                return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let keychain = Self.uniqueKeychain()
        defer {
            MockURLProtocol.unregister(host: host)
            Task { await TokenRefreshTests.cleanup(keychain) }
        }

        let tokenStore = TokenStore(keychain: keychain)
        try await tokenStore.save(tokens: .init(accessToken: "old-access", refreshToken: "old-refresh"))

        let client = ABSClient(session: Self.makeSession(), tokenStore: tokenStore, baseURL: baseURL)
        await client.bindRefreshHandler()

        struct EmptyResponse: Decodable, Sendable {}
        await #expect(throws: (any Error).self) {
            let _: EmptyResponse = try await client.perform(APIRequest(path: "/api/me"))
        }

        let still = await tokenStore.hasStoredCredentials()
        #expect(still == false, "credentials should be cleared after a hard refresh failure")
    }

    private static func cleanup(_ keychain: KeychainStore) async {
        try? await keychain.delete(account: TokenStore.AccountKey.accessToken)
        try? await keychain.delete(account: TokenStore.AccountKey.refreshToken)
        try? await keychain.delete(account: TokenStore.AccountKey.serverURL)
        try? await keychain.delete(account: TokenStore.AccountKey.username)
    }
}
