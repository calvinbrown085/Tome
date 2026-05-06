import Foundation

// MARK: - Request bodies

nonisolated struct PlaySessionRequestDTO: Encodable, Sendable {
    let deviceInfo: PlaySessionDeviceInfoDTO?
    let forceDirectPlay: Bool
    let forceTranscode: Bool
    let supportedMimeTypes: [String]
    let mediaPlayer: String
}

nonisolated struct PlaySessionDeviceInfoDTO: Encodable, Sendable {
    let deviceId: String
    let clientName: String
    let clientVersion: String
    let manufacturer: String
    let model: String
    let osName: String
    let osVersion: String
}

nonisolated struct PlaySessionSyncRequestDTO: Encodable, Sendable {
    let currentTime: Double
    let timeListened: Double
    let duration: Double
}

// MARK: - Response

nonisolated struct PlaybackSessionDTO: Decodable, Sendable {
    let id: String
    let userId: String?
    let libraryId: String?
    let libraryItemId: String?
    let mediaType: String?
    let displayTitle: String?
    let displayAuthor: String?
    let coverPath: String?
    let duration: Double?
    let playMethod: Int?
    let mediaPlayer: String?
    let date: String?
    let dayOfWeek: String?
    let timeListening: Double?
    let startedAt: Int64?
    let updatedAt: Int64?
    let currentTime: Double?
    let audioTracks: [AudioTrackDTO]?
    let chapters: [ChapterDTO]?
}

nonisolated struct AudioTrackDTO: Decodable, Sendable {
    let index: Int?
    let startOffset: Double?
    let duration: Double?
    let title: String?
    let contentUrl: String?
    let mimeType: String?
    let codec: String?
    let metadata: FileMetadataDTO?
}
