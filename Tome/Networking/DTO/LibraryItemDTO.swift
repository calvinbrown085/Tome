import Foundation

nonisolated struct LibraryItemDTO: Decodable, Sendable, Identifiable {
    let id: String
    let libraryId: String?
    let folderId: String?
    let mediaType: String?
    let isInvalid: Bool?
    let isMissing: Bool?
    let numFiles: Int?
    let size: Int64?
    let addedAt: Int64?
    let updatedAt: Int64?
    let media: MediaDTO?
    let userMediaProgress: MediaProgressDTO?
}

nonisolated struct MediaDTO: Decodable, Sendable {
    let libraryItemId: String?
    let metadata: BookMetadataDTO?
    let coverPath: String?
    let tags: [String]?
    let audioFiles: [AudioFileDTO]?
    let chapters: [ChapterDTO]?
    let duration: Double?
    let size: Int64?
    let numTracks: Int?
    let numAudioFiles: Int?
    let numChapters: Int?
}

nonisolated struct BookMetadataDTO: Decodable, Sendable {
    let title: String?
    let titleIgnorePrefix: String?
    let subtitle: String?
    let authors: [AuthorMinimalDTO]?
    let authorName: String?
    let authorNameLF: String?
    let narrators: [String]?
    let narratorName: String?
    let series: [SeriesSequenceDTO]?
    let genres: [String]?
    let publishedYear: String?
    let publishedDate: String?
    let publisher: String?
    let description: String?
    let isbn: String?
    let asin: String?
    let language: String?
    let explicit: Bool?

    var displayAuthor: String {
        if let authorName, !authorName.isEmpty { return authorName }
        if let authors, !authors.isEmpty { return authors.map(\.name).joined(separator: ", ") }
        return ""
    }

    var displayNarrator: String {
        if let narratorName, !narratorName.isEmpty { return narratorName }
        if let narrators, !narrators.isEmpty { return narrators.joined(separator: ", ") }
        return ""
    }
}

nonisolated struct AuthorMinimalDTO: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
}

nonisolated struct SeriesSequenceDTO: Decodable, Sendable, Identifiable {
    let id: String
    let name: String
    let sequence: String?
}

nonisolated struct ChapterDTO: Decodable, Sendable, Identifiable {
    let id: Int
    let start: Double
    let end: Double
    let title: String?
}

nonisolated struct AudioFileDTO: Decodable, Sendable {
    let index: Int?
    let ino: String?
    let duration: Double?
    let bitRate: Int?
    let mimeType: String?
    let codec: String?
    let metadata: FileMetadataDTO?
}

nonisolated struct FileMetadataDTO: Decodable, Sendable {
    let filename: String?
    let ext: String?
    let path: String?
    let size: Int64?
}

nonisolated struct MediaProgressDTO: Decodable, Sendable {
    let id: String?
    let libraryItemId: String?
    let episodeId: String?
    let duration: Double?
    let progress: Double?
    let currentTime: Double?
    let isFinished: Bool?
    let hideFromContinueListening: Bool?
    let lastUpdate: Int64?
    let startedAt: Int64?
    let finishedAt: Int64?
}
