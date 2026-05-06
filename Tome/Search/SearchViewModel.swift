import Foundation
import Observation
import os

@Observable
@MainActor
final class SearchViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    var query: String = ""
    private(set) var results: SearchResultDTO?
    private(set) var state: LoadState = .idle

    private let client: ABSClient

    init(client: ABSClient) {
        self.client = client
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var errorMessage: String? {
        if case .failed(let m) = state { return m }
        return nil
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var hasResults: Bool {
        guard let r = results else { return false }
        let count = (r.book?.count ?? 0) + (r.authors?.count ?? 0) + (r.series?.count ?? 0)
        return count > 0
    }

    func runSearch(libraryID: String) async {
        let q = trimmedQuery
        guard !q.isEmpty else {
            results = nil
            state = .idle
            return
        }
        state = .loading
        do {
            let response = try await client.search(libraryID: libraryID, query: q, limit: 20)
            // Drop stale responses if the query changed during the request.
            guard trimmedQuery == q else { return }
            results = response
            state = .loaded
        } catch is CancellationError {
            return
        } catch {
            if let urlErr = error as? URLError, urlErr.code == .cancelled { return }
            state = .failed(message(for: error))
            Log.net.error("Search failed: \(String(describing: error), privacy: .public)")
        }
    }

#if DEBUG
    convenience init(previewClient: ABSClient, query: String, results: SearchResultDTO?) {
        self.init(client: previewClient)
        self.query = query
        self.results = results
        self.state = (results == nil) ? .idle : .loaded
    }
#endif

    private func message(for error: any Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .transport: return "Couldn't reach the server."
            case .http(let status, _): return "Server returned HTTP \(status)."
            case .decoding: return "Couldn't read the server response."
            case .invalidURL: return "The server URL is invalid."
            case .noResponse: return "No response from server."
            case .unauthorized: return "Your session expired. Please sign in again."
            }
        }
        return error.localizedDescription
    }
}
