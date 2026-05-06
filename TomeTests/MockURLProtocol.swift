import Foundation

/// URLProtocol subclass for tests. Routes every request through a
/// caller-provided handler and logs the request for later assertions.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    nonisolated(unsafe) private static var _handler: Handler?
    nonisolated(unsafe) private static var _log: [URLRequest] = []
    private static let lock = NSLock()

    static func reset(handler: @escaping Handler) {
        lock.lock(); defer { lock.unlock() }
        _handler = handler
        _log = []
    }

    static func capturedRequests() -> [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _log
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._log.append(request)
        let handler = Self._handler
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
