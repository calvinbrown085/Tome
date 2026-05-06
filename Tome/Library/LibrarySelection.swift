import Foundation
import Observation
import os

@Observable
@MainActor
final class LibrarySelection {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private(set) var libraries: [LibraryDTO] = []
    private(set) var loadState: LoadState = .idle
    var selectedLibraryID: String? {
        didSet { defaults.set(selectedLibraryID, forKey: Self.persistKey) }
    }

    private static let persistKey = "tome.selectedLibraryID"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.selectedLibraryID = defaults.string(forKey: Self.persistKey)
    }

    var selectedLibrary: LibraryDTO? {
        guard let id = selectedLibraryID else { return libraries.first }
        return libraries.first(where: { $0.id == id }) ?? libraries.first
    }

    func load(using client: ABSClient, force: Bool = false) async {
        if !force, case .loaded = loadState, !libraries.isEmpty { return }
        loadState = .loading
        do {
            let fetched = try await client.listLibraries()
            libraries = fetched.filter(\.isAudiobookLibrary)
            if let current = selectedLibraryID, libraries.contains(where: { $0.id == current }) {
                // keep
            } else {
                selectedLibraryID = libraries.first?.id
            }
            loadState = .loaded
        } catch {
            loadState = .failed(message(for: error))
            Log.net.error("Failed to load libraries: \(String(describing: error), privacy: .public)")
        }
    }

    func select(_ id: String) {
        guard libraries.contains(where: { $0.id == id }) else { return }
        selectedLibraryID = id
    }

#if DEBUG
    func populateForPreview(libraries: [LibraryDTO], selected: String?) {
        self.libraries = libraries
        self.selectedLibraryID = selected ?? libraries.first?.id
        self.loadState = .loaded
    }
#endif

    private func message(for error: any Error) -> String {
        if let api = error as? APIError {
            switch api {
            case .transport: return "Couldn't reach the server."
            case .http(let status, _): return "Server returned HTTP \(status)."
            case .decoding: return "Couldn't read the server response."
            case .invalidURL, .noResponse, .unauthorized: return String(describing: api)
            }
        }
        return error.localizedDescription
    }
}
