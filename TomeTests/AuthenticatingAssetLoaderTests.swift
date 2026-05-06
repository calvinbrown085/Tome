import Foundation
import Testing
@testable import Tome

@Suite("AuthenticatingAssetLoader.fetchRange")
struct AuthenticatingAssetLoaderTests {

    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static func uniqueURL() -> (host: String, url: URL) {
        let host = "test-\(UUID().uuidString.lowercased()).example"
        return (host, URL(string: "https://\(host)/api/items/li_42/file/abc")!)
    }

    @Test("fetchRange sets Range header and Bearer auth on a non-zero length")
    func rangeHeaderAndBearer() async throws {
        let (host, url) = Self.uniqueURL()
        defer { MockURLProtocol.unregister(host: host) }

        let payload = Data(repeating: 0xAB, count: 1024)
        MockURLProtocol.register(host: host) { request in
            (HTTPURLResponse(url: request.url!, statusCode: 206, httpVersion: nil,
                             headerFields: ["Content-Range": "bytes 0-1023/4096", "Content-Type": "audio/mpeg"])!, payload)
        }

        let loader = AuthenticatingAssetLoader(
            session: Self.makeSession(),
            tokenProvider: { "tok-1" },
            tokenRefresher: { "tok-2" }
        )

        let (data, response) = try await loader.fetchRange(url: url, offset: 0, length: 1024)
        #expect(data.count == 1024)
        #expect(response.statusCode == 206)

        let captured = try #require(MockURLProtocol.capturedRequests(host: host).first)
        #expect(captured.value(forHTTPHeaderField: "Authorization") == "Bearer tok-1")
        #expect(captured.value(forHTTPHeaderField: "Range") == "bytes=0-1023")
    }

    @Test("fetchRange with length=0 and offset>0 sends open-ended Range")
    func openEndedRange() async throws {
        let (host, url) = Self.uniqueURL()
        defer { MockURLProtocol.unregister(host: host) }
        MockURLProtocol.register(host: host) { request in
            (HTTPURLResponse(url: request.url!, statusCode: 206, httpVersion: nil, headerFields: nil)!, Data())
        }
        let loader = AuthenticatingAssetLoader(
            session: Self.makeSession(),
            tokenProvider: { "tok" },
            tokenRefresher: { "tok" }
        )
        _ = try? await loader.fetchRange(url: url, offset: 1000, length: 0)
        let captured = try #require(MockURLProtocol.capturedRequests(host: host).first)
        #expect(captured.value(forHTTPHeaderField: "Range") == "bytes=1000-")
    }

    @Test("fetchRange retries once on 401 with the refreshed token")
    func retryOn401() async throws {
        let (host, url) = Self.uniqueURL()
        defer { MockURLProtocol.unregister(host: host) }

        let payload = Data([0x01, 0x02, 0x03])
        MockURLProtocol.register(host: host) { request in
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if auth == "Bearer new" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, payload)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let refreshCount = Counter()
        let providerState = Counter()
        let loader = AuthenticatingAssetLoader(
            session: Self.makeSession(),
            tokenProvider: {
                let n = await providerState.bumpAndGet()
                return n == 1 ? "old" : "new"
            },
            tokenRefresher: {
                await refreshCount.bump()
                return "new"
            }
        )

        let (data, response) = try await loader.fetchRange(url: url, offset: 0, length: 3)
        #expect(data == payload)
        #expect(response.statusCode == 200)
        await #expect(refreshCount.value() == 1)

        let captured = MockURLProtocol.capturedRequests(host: host)
        #expect(captured.count == 2)
        #expect(captured.first?.value(forHTTPHeaderField: "Authorization") == "Bearer old")
        #expect(captured.last?.value(forHTTPHeaderField: "Authorization") == "Bearer new")
    }

    @Test("a second consecutive 401 throws unauthorized — no infinite retry")
    func doubleFailureThrows() async throws {
        let (host, url) = Self.uniqueURL()
        defer { MockURLProtocol.unregister(host: host) }

        MockURLProtocol.register(host: host) { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
        }

        let refreshCount = Counter()
        let loader = AuthenticatingAssetLoader(
            session: Self.makeSession(),
            tokenProvider: { "anything" },
            tokenRefresher: {
                await refreshCount.bump()
                return "still-bad"
            }
        )

        await #expect(throws: AuthenticatingAssetLoader.FetchError.self) {
            _ = try await loader.fetchRange(url: url, offset: 0, length: 10)
        }
        await #expect(refreshCount.value() == 1)
        #expect(MockURLProtocol.capturedRequests(host: host).count == 2)
    }

    @Test("scheme rewrite roundtrips https → tomestream → https")
    func schemeRewriteRoundtrip() throws {
        let original = URL(string: "https://example.com/api/items/li_42/file/abc?expanded=1")!
        let rewritten = try #require(AuthenticatingAssetLoader.rewriteToCustomScheme(original))
        #expect(rewritten.scheme == "tomestream")
        let back = try #require(AuthenticatingAssetLoader.rewriteToOriginalScheme(rewritten))
        #expect(back.scheme == "https")
        #expect(back.host == "example.com")
        #expect(back.path == "/api/items/li_42/file/abc")
        let q = URLComponents(url: back, resolvingAgainstBaseURL: false)?.queryItems ?? []
        #expect(q.contains(URLQueryItem(name: "expanded", value: "1")))
        #expect(q.allSatisfy { $0.name != "__scheme" })
    }

    @Test("parseContentRangeTotal extracts the total")
    func parseContentRange() {
        #expect(AuthenticatingAssetLoader.parseContentRangeTotal("bytes 0-1023/4096") == 4096)
        #expect(AuthenticatingAssetLoader.parseContentRangeTotal("bytes 0-1/12345") == 12345)
        #expect(AuthenticatingAssetLoader.parseContentRangeTotal("bytes 0-1/*") == nil)
        #expect(AuthenticatingAssetLoader.parseContentRangeTotal("malformed") == nil)
    }
}

/// Async-safe counter for state assertions in tests.
private actor Counter {
    private var n = 0
    func bump() { n += 1 }
    func bumpAndGet() -> Int { n += 1; return n }
    func value() -> Int { n }
}
