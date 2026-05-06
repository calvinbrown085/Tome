import Foundation
import Observation
import os

@Observable
@MainActor
final class SeriesDetailViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    let seriesID: String
    let libraryID: String
    let name: String
    private let client: ABSClient

    private(set) var items: [LibraryItemDTO] = []
    private(set) var state: LoadState = .idle

    init(client: ABSClient, seriesID: String, libraryID: String, name: String) {
        self.client = client
        self.seriesID = seriesID
        self.libraryID = libraryID
        self.name = name
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
            let filter = "series." + Data(seriesID.utf8).base64EncodedString()
            let response = try await client.libraryItems(
                libraryID: libraryID,
                limit: 100,
                page: 0,
                sort: "media.metadata.series.\(seriesID).sequence",
                desc: false,
                filter: filter
            )
            items = response.results
            state = .loaded
        } catch {
            state = .failed(message(for: error))
            Log.net.error("Series detail load failed: \(String(describing: error), privacy: .public)")
        }
    }

#if DEBUG
    convenience init(previewClient: ABSClient, seriesID: String, libraryID: String, name: String, items: [LibraryItemDTO]) {
        self.init(client: previewClient, seriesID: seriesID, libraryID: libraryID, name: name)
        self.items = items
        self.state = .loaded
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
