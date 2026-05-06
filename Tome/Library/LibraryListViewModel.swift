import Foundation
import Observation
import os

@Observable
@MainActor
final class LibraryListViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case loadingMore
        case failed(String)
    }

    let libraryID: String
    let pageSize: Int
    private let client: ABSClient

    private(set) var items: [LibraryItemDTO] = []
    private(set) var state: LoadState = .idle
    private(set) var total: Int = 0
    private(set) var page: Int = 0

    var sort: LibrarySort = .recentlyAdded
    var filter: LibraryFilter = .all

    init(client: ABSClient, libraryID: String, pageSize: Int = 50) {
        self.client = client
        self.libraryID = libraryID
        self.pageSize = pageSize
    }

    var hasMore: Bool { items.count < total }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var isLoadingMore: Bool {
        if case .loadingMore = state { return true }
        return false
    }

    var errorMessage: String? {
        if case .failed(let m) = state { return m }
        return nil
    }

    func refresh() async {
        state = .loading
        do {
            let response = try await fetch(page: 0)
            items = response.results
            total = response.total ?? response.results.count
            page = 0
            state = .loaded
        } catch {
            state = .failed(message(for: error))
            Log.net.error("Library refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Called from the list's onAppear for each row. Triggers a load of the next page when nearing the bottom.
    func loadNextIfNeeded(after item: LibraryItemDTO) async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        if idx < items.count - 10 { return }
        await loadNext()
    }

    func loadNext() async {
        guard hasMore, !isLoadingMore, !isLoading else { return }
        state = .loadingMore
        do {
            let next = page + 1
            let response = try await fetch(page: next)
            let existing = Set(items.map(\.id))
            let additions = response.results.filter { !existing.contains($0.id) }
            items.append(contentsOf: additions)
            total = response.total ?? total
            page = next
            state = .loaded
        } catch {
            state = .failed(message(for: error))
            Log.net.error("Library next-page failed: \(String(describing: error), privacy: .public)")
        }
    }

    func apply(sort: LibrarySort, filter: LibraryFilter) async {
        guard sort != self.sort || filter != self.filter else { return }
        self.sort = sort
        self.filter = filter
        await refresh()
    }

    private func fetch(page: Int) async throws -> PaginatedDTO<LibraryItemDTO> {
        try await client.libraryItems(
            libraryID: libraryID,
            limit: pageSize,
            page: page,
            sort: sort.sortField,
            desc: sort.descending,
            filter: filter.apiValue
        )
    }

#if DEBUG
    convenience init(previewClient: ABSClient, libraryID: String, items: [LibraryItemDTO], total: Int? = nil) {
        self.init(client: previewClient, libraryID: libraryID)
        self.items = items
        self.total = total ?? items.count
        self.state = .loaded
    }
#endif

    private func message(for error: any Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .transport: return "Couldn't reach the server."
            case .http(let status, _) where status == 401: return "Your session expired. Please sign in again."
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
