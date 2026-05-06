import Foundation
import Observation
import os

@Observable
@MainActor
final class LibraryHomeViewModel {
    enum ShelfState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    let libraryID: String
    private let client: ABSClient
    private let pageSize: Int

    private(set) var inProgressItems: [LibraryItemDTO] = []
    private(set) var inProgressState: ShelfState = .idle

    private(set) var recentlyAddedItems: [LibraryItemDTO] = []
    private(set) var recentlyAddedState: ShelfState = .idle

    init(client: ABSClient, libraryID: String, pageSize: Int = 20) {
        self.client = client
        self.libraryID = libraryID
        self.pageSize = pageSize
    }

    var isInitialLoad: Bool {
        inProgressItems.isEmpty && recentlyAddedItems.isEmpty &&
            (inProgressState == .loading || recentlyAddedState == .loading || inProgressState == .idle)
    }

    var hasAnyError: Bool {
        if case .failed = inProgressState { return true }
        if case .failed = recentlyAddedState { return true }
        return false
    }

    func load() async {
        inProgressState = .loading
        recentlyAddedState = .loading

        async let inProg = fetchInProgress()
        async let recent = fetchRecentlyAdded()

        let inProgResult = await inProg
        let recentResult = await recent

        apply(inProgress: inProgResult)
        apply(recentlyAdded: recentResult)
    }

    private func apply(inProgress result: Result<[LibraryItemDTO], any Error>) {
        switch result {
        case .success(let items):
            inProgressItems = items
            inProgressState = items.isEmpty ? .empty : .loaded
        case .failure(let err):
            inProgressState = .failed(message(for: err))
            Log.net.error("In-progress shelf failed: \(String(describing: err), privacy: .public)")
        }
    }

    private func apply(recentlyAdded result: Result<[LibraryItemDTO], any Error>) {
        switch result {
        case .success(let items):
            recentlyAddedItems = items
            recentlyAddedState = items.isEmpty ? .empty : .loaded
        case .failure(let err):
            recentlyAddedState = .failed(message(for: err))
            Log.net.error("Recently-added shelf failed: \(String(describing: err), privacy: .public)")
        }
    }

    private func fetchInProgress() async -> Result<[LibraryItemDTO], any Error> {
        do {
            let response = try await client.libraryItems(
                libraryID: libraryID,
                limit: pageSize,
                page: 0,
                sort: nil,
                desc: true,
                filter: LibraryFilter.inProgress.apiValue
            )
            return .success(response.results)
        } catch {
            return .failure(error)
        }
    }

    private func fetchRecentlyAdded() async -> Result<[LibraryItemDTO], any Error> {
        do {
            let response = try await client.libraryItems(
                libraryID: libraryID,
                limit: pageSize,
                page: 0,
                sort: "addedAt",
                desc: true,
                filter: nil
            )
            return .success(response.results)
        } catch {
            return .failure(error)
        }
    }

#if DEBUG
    convenience init(
        previewClient: ABSClient,
        libraryID: String,
        inProgress: [LibraryItemDTO],
        recentlyAdded: [LibraryItemDTO]
    ) {
        self.init(client: previewClient, libraryID: libraryID)
        self.inProgressItems = inProgress
        self.inProgressState = inProgress.isEmpty ? .empty : .loaded
        self.recentlyAddedItems = recentlyAdded
        self.recentlyAddedState = recentlyAdded.isEmpty ? .empty : .loaded
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
