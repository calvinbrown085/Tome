import Foundation
import Observation
import os

@Observable
@MainActor
final class BookDetailViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let itemID: String
    private let client: ABSClient

    private(set) var item: LibraryItemDTO?
    private(set) var state: LoadState = .idle

    init(client: ABSClient, itemID: String) {
        self.client = client
        self.itemID = itemID
    }

    var errorMessage: String? {
        if case .failed(let m) = state { return m }
        return nil
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    func load() async {
        if case .loading = state { return }
        state = .loading
        do {
            let fetched = try await client.libraryItem(id: itemID)
            item = fetched
            state = .loaded
        } catch {
            state = .failed(message(for: error))
            Log.net.error("Book detail load failed: \(String(describing: error), privacy: .public)")
        }
    }

#if DEBUG
    convenience init(previewClient: ABSClient, item: LibraryItemDTO) {
        self.init(client: previewClient, itemID: item.id)
        self.item = item
        self.state = .loaded
    }
#endif

    private func message(for error: any Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .transport: return "Couldn't reach the server."
            case .http(let status, _) where status == 404: return "This book isn't on the server anymore."
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
