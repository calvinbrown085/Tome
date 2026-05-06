import Foundation
import AVFoundation
import UniformTypeIdentifiers
import os

/// Bridges `AVPlayer`'s media loads to an authenticated `URLSession`. AVPlayer cannot
/// set arbitrary HTTP headers on its own GETs, so we rewrite asset URLs to a custom
/// scheme — the asset URL becomes `tomestream://...` and we proxy each load via a
/// real `URLRequest` with `Authorization: Bearer <token>`.
///
/// On 401 we call `tokenRefresher` once and retry; a second consecutive 401 throws.
nonisolated final class AuthenticatingAssetLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    typealias TokenProvider = @Sendable () async throws -> String
    typealias TokenRefresher = @Sendable () async throws -> String

    static let customScheme = "tomestream"

    let queue: DispatchQueue
    private let session: URLSession
    private let tokenProvider: TokenProvider
    private let tokenRefresher: TokenRefresher

    private let tasks = OSAllocatedUnfairLock<[ObjectIdentifier: Task<Void, Never>]>(initialState: [:])

    init(
        session: URLSession = .shared,
        queue: DispatchQueue = DispatchQueue(label: "tome.player.assetloader", qos: .userInitiated),
        tokenProvider: @escaping TokenProvider,
        tokenRefresher: @escaping TokenRefresher
    ) {
        self.session = session
        self.queue = queue
        self.tokenProvider = tokenProvider
        self.tokenRefresher = tokenRefresher
    }

    // MARK: - Scheme rewriting

    /// Rewrites an `https://…` URL to the custom scheme used as an `AVURLAsset` URL.
    static func rewriteToCustomScheme(_ url: URL) -> URL? {
        guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard let scheme = c.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        c.scheme = customScheme
        // Stash the original scheme as a query item so we can restore it precisely.
        var items = c.queryItems ?? []
        items.append(URLQueryItem(name: "__scheme", value: scheme))
        c.queryItems = items
        return c.url
    }

    /// Reverses `rewriteToCustomScheme` — used inside the delegate.
    static func rewriteToOriginalScheme(_ url: URL) -> URL? {
        guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        guard c.scheme == customScheme else { return nil }
        var items = c.queryItems ?? []
        let original = items.first(where: { $0.name == "__scheme" })?.value ?? "https"
        items.removeAll(where: { $0.name == "__scheme" })
        c.queryItems = items.isEmpty ? nil : items
        c.scheme = original
        return c.url
    }

    // MARK: - AVAssetResourceLoaderDelegate

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let url = loadingRequest.request.url,
              let real = Self.rewriteToOriginalScheme(url) else {
            loadingRequest.finishLoading(with: URLError(.badURL))
            return false
        }
        let key = ObjectIdentifier(loadingRequest)
        let task = Task { [weak self] in
            guard let self else { return }
            await self.handle(loadingRequest: loadingRequest, url: real)
            self.tasks.withLock { $0.removeValue(forKey: key) }
        }
        tasks.withLock { $0[key] = task }
        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        didCancel loadingRequest: AVAssetResourceLoadingRequest) {
        let task = tasks.withLock { $0.removeValue(forKey: ObjectIdentifier(loadingRequest)) }
        task?.cancel()
    }

    // MARK: - Loading

    private func handle(loadingRequest: AVAssetResourceLoadingRequest, url: URL) async {
        if let info = loadingRequest.contentInformationRequest {
            do {
                let (_, http) = try await fetchRange(url: url, offset: 0, length: 2)
                let headerMime = http.value(forHTTPHeaderField: "Content-Type")?
                    .split(separator: ";").first.map { String($0).trimmingCharacters(in: .whitespaces) }
                let mime = http.mimeType ?? headerMime
                if let mime, let ut = UTType(mimeType: mime) {
                    info.contentType = ut.identifier
                }
                if let cr = http.value(forHTTPHeaderField: "Content-Range"),
                   let total = Self.parseContentRangeTotal(cr) {
                    info.contentLength = total
                } else if http.expectedContentLength > 0 {
                    info.contentLength = http.expectedContentLength
                }
                let acceptRanges = http.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased()
                info.isByteRangeAccessSupported = (http.statusCode == 206) || (acceptRanges == "bytes")
            } catch is CancellationError {
                return
            } catch {
                Log.player.error("contentInfo fetch failed: \(String(describing: error), privacy: .public)")
                loadingRequest.finishLoading(with: error)
                return
            }
        }

        guard let dataRequest = loadingRequest.dataRequest else {
            loadingRequest.finishLoading()
            return
        }

        let offset = Int(dataRequest.requestedOffset)
        let length = dataRequest.requestsAllDataToEndOfResource ? 0 : dataRequest.requestedLength
        do {
            try await streamRange(url: url, offset: offset, length: length, into: dataRequest)
            try Task.checkCancellation()
            loadingRequest.finishLoading()
        } catch is CancellationError {
            return
        } catch {
            Log.player.error("data fetch failed: \(String(describing: error), privacy: .public)")
            loadingRequest.finishLoading(with: error)
        }
    }

    // MARK: - Fetch (extracted for testing)

    enum FetchError: Error, Sendable {
        case unauthorized
        case badResponse
        case http(status: Int)
    }

    /// Range-aware authenticated GET. `length == 0` means "from offset to EOF".
    /// On 401, refreshes the token via `tokenRefresher` and retries once. A second
    /// 401 throws `FetchError.unauthorized`.
    func fetchRange(url: URL, offset: Int, length: Int) async throws -> (Data, HTTPURLResponse) {
        try await fetchRangeWithRetry(url: url, offset: offset, length: length, attempt: 0)
    }

    private func fetchRangeWithRetry(url: URL, offset: Int, length: Int, attempt: Int) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let token = try await tokenProvider()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if length > 0 {
            req.setValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
        } else if offset > 0 {
            req.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
        }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw FetchError.badResponse }

        if http.statusCode == 401 {
            if attempt == 0 {
                _ = try await tokenRefresher()
                return try await fetchRangeWithRetry(url: url, offset: offset, length: length, attempt: 1)
            }
            throw FetchError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FetchError.http(status: http.statusCode)
        }
        return (data, http)
    }

    /// Streams a range from the server into `dataRequest`, calling `respond(with:)` once per
    /// ~64 KB chunk so AVPlayer can begin playback while the rest is still in flight.
    /// On 401 (before any bytes are delivered) refreshes the token and retries once.
    private func streamRange(
        url: URL,
        offset: Int,
        length: Int,
        into dataRequest: AVAssetResourceLoadingDataRequest
    ) async throws {
        try await streamRangeWithRetry(url: url, offset: offset, length: length, into: dataRequest, attempt: 0)
    }

    private func streamRangeWithRetry(
        url: URL,
        offset: Int,
        length: Int,
        into dataRequest: AVAssetResourceLoadingDataRequest,
        attempt: Int
    ) async throws {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let token = try await tokenProvider()
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if length > 0 {
            req.setValue("bytes=\(offset)-\(offset + length - 1)", forHTTPHeaderField: "Range")
        } else if offset > 0 {
            req.setValue("bytes=\(offset)-", forHTTPHeaderField: "Range")
        }

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse else { throw FetchError.badResponse }

        if http.statusCode == 401 {
            if attempt == 0 {
                _ = try await tokenRefresher()
                return try await streamRangeWithRetry(url: url, offset: offset, length: length, into: dataRequest, attempt: 1)
            }
            throw FetchError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            throw FetchError.http(status: http.statusCode)
        }

        let chunkSize = 64 * 1024
        var buffer = Data()
        buffer.reserveCapacity(chunkSize)
        for try await byte in bytes {
            buffer.append(byte)
            if buffer.count >= chunkSize {
                dataRequest.respond(with: buffer)
                buffer.removeAll(keepingCapacity: true)
                try Task.checkCancellation()
            }
        }
        if !buffer.isEmpty {
            dataRequest.respond(with: buffer)
        }
    }

    static func parseContentRangeTotal(_ s: String) -> Int64? {
        // Format: "bytes 0-1/12345"; "bytes 0-1/*" means total unknown.
        guard let slash = s.lastIndex(of: "/") else { return nil }
        let totalPart = String(s[s.index(after: slash)...])
        if totalPart == "*" { return nil }
        return Int64(totalPart)
    }
}
