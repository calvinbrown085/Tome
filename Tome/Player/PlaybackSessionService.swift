import Foundation
#if canImport(UIKit)
import UIKit
#endif

protocol PlaybackSessionServicing: Sendable {
    func openSession(item: LibraryItemDTO) async throws -> PlaybackContext
    func syncSession(id: String, currentTime: TimeInterval, timeListened: TimeInterval, duration: TimeInterval) async throws
    func closeSession(id: String, currentTime: TimeInterval, timeListened: TimeInterval, duration: TimeInterval) async throws
}

actor PlaybackSessionService: PlaybackSessionServicing {
    enum SessionError: Error, Sendable {
        case noBaseURL
        case noTracks
        case invalidTrackURL(String)
    }

    private let client: ABSClient
    private let deviceInfo: PlaySessionDeviceInfoDTO

    init(client: ABSClient, deviceInfo: PlaySessionDeviceInfoDTO) {
        self.client = client
        self.deviceInfo = deviceInfo
    }

    func openSession(item: LibraryItemDTO) async throws -> PlaybackContext {
        let dto = try await client.openPlaybackSession(itemID: item.id, deviceInfo: deviceInfo)
        guard let baseURL = await client.currentBaseURL() else { throw SessionError.noBaseURL }
        guard let dtoTracks = dto.audioTracks, !dtoTracks.isEmpty else { throw SessionError.noTracks }

        let tracks: [PlaybackContext.Track] = try dtoTracks.enumerated().map { (i, t) in
            guard let raw = t.contentUrl, let url = URL(string: raw, relativeTo: baseURL)?.absoluteURL else {
                throw SessionError.invalidTrackURL(t.contentUrl ?? "<nil>")
            }
            return PlaybackContext.Track(
                index: t.index ?? i,
                startOffset: t.startOffset ?? 0,
                duration: t.duration ?? 0,
                url: url,
                mimeType: t.mimeType
            )
        }

        let total = dto.duration
            ?? tracks.reduce(0) { $0 + $1.duration }

        return PlaybackContext(
            sessionID: dto.id,
            libraryItemID: dto.libraryItemId ?? item.id,
            tracks: tracks,
            chapters: dto.chapters ?? item.media?.chapters ?? [],
            totalDuration: total,
            startTime: dto.currentTime ?? item.userMediaProgress?.currentTime ?? 0,
            title: dto.displayTitle ?? item.media?.metadata?.title ?? "Unknown",
            author: dto.displayAuthor ?? item.media?.metadata?.displayAuthor ?? "",
            coverItemID: item.id
        )
    }

    func syncSession(id: String, currentTime: TimeInterval, timeListened: TimeInterval, duration: TimeInterval) async throws {
        try await client.syncPlaybackSession(id: id, currentTime: currentTime, timeListened: timeListened, duration: duration)
    }

    func closeSession(id: String, currentTime: TimeInterval, timeListened: TimeInterval, duration: TimeInterval) async throws {
        try await client.closePlaybackSession(id: id, currentTime: currentTime, timeListened: timeListened, duration: duration)
    }
}

extension PlaySessionDeviceInfoDTO {
    /// Builds a stable per-process device fingerprint. Call once at app start and reuse.
    @MainActor
    static func makeForCurrentDevice(deviceID: String) -> PlaySessionDeviceInfoDTO {
        #if canImport(UIKit)
        let device = UIDevice.current
        let osName = device.systemName
        let osVersion = device.systemVersion
        let model = device.model
        #else
        let osName = "iOS"
        let osVersion = "0.0"
        let model = "Unknown"
        #endif
        let bundle = Bundle.main
        let clientVersion = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0"
        return PlaySessionDeviceInfoDTO(
            deviceId: deviceID,
            clientName: "Tome",
            clientVersion: clientVersion,
            manufacturer: "Apple",
            model: model,
            osName: osName,
            osVersion: osVersion
        )
    }
}
