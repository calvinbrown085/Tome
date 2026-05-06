import Foundation

nonisolated struct LibrariesResponseDTO: Decodable, Sendable {
    let libraries: [LibraryDTO]
}

nonisolated struct LibraryDTO: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
    let mediaType: String?
    let icon: String?
    let displayOrder: Int?
    let folders: [FolderDTO]?
    let provider: String?

    var isAudiobookLibrary: Bool { (mediaType ?? "book") == "book" }
}

nonisolated struct FolderDTO: Decodable, Sendable, Identifiable {
    let id: String
    let fullPath: String?
    let libraryId: String?
    let addedAt: Int64?
}
