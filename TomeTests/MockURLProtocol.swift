import Foundation

/// URLProtocol subclass for tests. Routes every request through a per-host
/// handler so multiple test suites can run in parallel without trampling
/// each other's mock state. Each test registers a unique host (typically a
/// UUID-based subdomain) and looks up captured requests by that host.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    nonisolated(unsafe) private static var _handlers: [String: Handler] = [:]
    nonisolated(unsafe) private static var _logs: [String: [URLRequest]] = [:]
    private static let lock = NSLock()

    static func register(host: String, handler: @escaping Handler) {
        lock.lock(); defer { lock.unlock() }
        _handlers[host] = handler
        _logs[host] = []
    }

    static func unregister(host: String) {
        lock.lock(); defer { lock.unlock() }
        _handlers.removeValue(forKey: host)
        _logs.removeValue(forKey: host)
    }

    static func capturedRequests(host: String) -> [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _logs[host] ?? []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let host = request.url?.host ?? ""
        Self.lock.lock()
        Self._logs[host, default: []].append(request)
        let handler = Self._handlers[host]
        Self.lock.unlock()
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
