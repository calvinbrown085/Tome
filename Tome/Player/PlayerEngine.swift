import Foundation
import AVFoundation
import Observation
import os
#if canImport(UIKit)
import UIKit
#endif

@MainActor
@Observable
final class PlayerEngine {
    enum State: Equatable, Sendable {
        case idle
        case loading
        case playing
        case paused
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var position: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var nowPlayingTitle: String = ""
    private(set) var nowPlayingAuthor: String = ""
    private(set) var nowPlayingNarrator: String = ""
    private(set) var coverItemID: String?
    private(set) var playbackRate: Float = 1.0
    private(set) var sleepTimerEndsAt: Date?

    private let sessionService: any PlaybackSessionServicing
    private let assetLoader: AuthenticatingAssetLoader
    private let assetLoaderQueue: DispatchQueue

    private var context: PlaybackContext?
    private var player: AVQueuePlayer?
    private var trackItems: [AVPlayerItem] = []
    private var timeObserver: Any?
    private var rateObservation: NSKeyValueObservation?
    private var currentItemObservation: NSKeyValueObservation?
    private var syncTask: Task<Void, Never>?
    private var sleepTask: Task<Void, Never>?
    private var willTerminateObserver: NSObjectProtocol?

    private var timeListenedAccumulator: TimeInterval = 0

    init(sessionService: any PlaybackSessionServicing, assetLoader: AuthenticatingAssetLoader) {
        self.sessionService = sessionService
        self.assetLoader = assetLoader
        self.assetLoaderQueue = assetLoader.queue
        registerLifecycleObservers()
    }

    // MARK: - Public API

    func play(item: LibraryItemDTO) {
        Task { await self.startPlayback(item: item) }
    }

    func togglePlayPause() {
        guard let player else { return }
        if player.rate > 0 {
            player.pause()
            Task { await self.fireSync(reason: .pause) }
        } else {
            player.play()
            player.rate = playbackRate
        }
    }

    func skipBackward(seconds: TimeInterval = 30) {
        guard let player, let item = player.currentItem else { return }
        let target = max(0, item.currentTime().seconds - seconds)
        item.seek(to: CMTime(seconds: target, preferredTimescale: 600), completionHandler: nil)
    }

    func skipForward(seconds: TimeInterval = 30) {
        guard let player, let item = player.currentItem,
              let track = currentTrack() else { return }
        let target = min(track.duration, item.currentTime().seconds + seconds)
        item.seek(to: CMTime(seconds: target, preferredTimescale: 600), completionHandler: nil)
    }

    func seekToNextTrack() {
        guard let context, let idx = currentTrackIndex(),
              idx + 1 < context.tracks.count else { return }
        seek(to: context.tracks[idx + 1].startOffset)
    }

    func seekToPreviousTrack() {
        guard let context, let player, let item = player.currentItem,
              let idx = currentTrackIndex() else { return }
        let local = item.currentTime().seconds
        if local > 3 {
            item.seek(to: .zero, completionHandler: nil)
        } else if idx > 0 {
            seek(to: context.tracks[idx - 1].startOffset)
        } else {
            item.seek(to: .zero, completionHandler: nil)
        }
    }

    private func currentTrackIndex() -> Int? {
        guard let player, let item = player.currentItem else { return nil }
        return trackItems.firstIndex(of: item)
    }

    func setPlaybackRate(_ rate: Float) {
        let clamped = max(0.5, min(3.0, rate))
        playbackRate = clamped
        if let player, player.rate > 0 {
            player.rate = clamped
        }
    }

    func setSleepTimer(minutes: Int?) {
        sleepTask?.cancel()
        sleepTask = nil
        guard let minutes, minutes > 0 else {
            sleepTimerEndsAt = nil
            return
        }
        let interval = TimeInterval(minutes * 60)
        sleepTimerEndsAt = Date().addingTimeInterval(interval)
        sleepTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(interval))
            if Task.isCancelled { return }
            await MainActor.run {
                self?.player?.pause()
                self?.sleepTimerEndsAt = nil
                self?.sleepTask = nil
            }
        }
    }

    var sleepRemainingMinutes: Int? {
        guard let end = sleepTimerEndsAt else { return nil }
        let remaining = end.timeIntervalSinceNow
        guard remaining > 0 else { return nil }
        return max(1, Int((remaining / 60).rounded(.up)))
    }

    var chapters: [ChapterDTO] { context?.chapters ?? [] }

    var currentChapterTitle: String? {
        guard let context else { return nil }
        let pos = position
        return context.chapters.first(where: { pos >= $0.start && pos < $0.end })?.title
    }

    /// Seeks to a global time. Cross-track seeking is not supported in v1 — clamps to the current track.
    func seek(to globalTime: TimeInterval) {
        guard let player,
              let item = player.currentItem,
              let context,
              let track = currentTrack() else { return }
        let local = max(0, min(track.duration, globalTime - track.startOffset))
        item.seek(to: CMTime(seconds: local, preferredTimescale: 600), completionHandler: nil)
        _ = context
    }

    func stop() {
        Task { await self.teardown(closeServer: true) }
    }

    // MARK: - Start

    private func startPlayback(item: LibraryItemDTO) async {
        if context != nil {
            await teardown(closeServer: true)
        }

        state = .loading
        nowPlayingTitle = item.media?.metadata?.title ?? "Unknown"
        nowPlayingAuthor = item.media?.metadata?.displayAuthor ?? ""
        nowPlayingNarrator = item.media?.metadata?.displayNarrator ?? ""
        coverItemID = item.id

        let ctx: PlaybackContext
        do {
            ctx = try await sessionService.openSession(item: item)
        } catch {
            Log.player.error("openSession failed: \(String(describing: error), privacy: .public)")
            state = .error(String(describing: error))
            return
        }

        guard !ctx.tracks.isEmpty else {
            state = .error("No audio tracks")
            return
        }

        AudioSessionConfigurator.activateForPlayback()

        let items: [AVPlayerItem] = ctx.tracks.map { track in
            let assetURL = AuthenticatingAssetLoader.rewriteToCustomScheme(track.url) ?? track.url
            var options: [String: Any] = [:]
            if let mime = track.mimeType {
                options["AVURLAssetOutOfBandMIMETypeKey"] = mime
            }
            let asset = AVURLAsset(url: assetURL, options: options)
            asset.resourceLoader.setDelegate(assetLoader, queue: assetLoaderQueue)
            return AVPlayerItem(asset: asset)
        }
        let queue = AVQueuePlayer(items: items)
        queue.actionAtItemEnd = .advance
        queue.automaticallyWaitsToMinimizeStalling = true

        // Resume to context.startTime: advance queue to the right track and seek within it.
        var startIndex = 0
        for (i, t) in ctx.tracks.enumerated() where ctx.startTime >= t.startOffset && ctx.startTime < t.startOffset + t.duration {
            startIndex = i; break
        }
        for _ in 0..<startIndex { queue.advanceToNextItem() }
        let local = max(0, ctx.startTime - ctx.tracks[startIndex].startOffset)
        if local > 0 {
            queue.currentItem?.seek(to: CMTime(seconds: local, preferredTimescale: 600), completionHandler: nil)
        }

        self.context = ctx
        self.player = queue
        self.trackItems = items
        self.duration = ctx.totalDuration
        self.position = ctx.startTime
        self.timeListenedAccumulator = 0

        installObservers(on: queue)
        startSyncLoop(sessionID: ctx.sessionID)
        queue.play()
        queue.rate = playbackRate
    }

    // MARK: - Observation

    private func installObservers(on queue: AVQueuePlayer) {
        let interval = CMTime(seconds: 1, preferredTimescale: 1)
        timeObserver = queue.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onTick() }
        }
        rateObservation = queue.observe(\.rate, options: [.new]) { [weak self] player, _ in
            let rate = player.rate
            Task { @MainActor in self?.onRateChanged(rate: rate) }
        }
        currentItemObservation = queue.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.onCurrentItemChanged() }
        }
    }

    private func onTick() {
        guard let player, let track = currentTrack() else { return }
        let local = player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0
        position = track.startOffset + local
        if player.rate > 0 {
            timeListenedAccumulator += 1
        }
    }

    private func onRateChanged(rate: Float) {
        if rate > 0 {
            state = .playing
        } else if state != .loading && state != .idle {
            state = .paused
        }
    }

    private func onCurrentItemChanged() {
        // currentItem advanced — global position recomputes naturally on next tick.
        if player?.currentItem == nil {
            // Reached end of queue
            Task { await self.fireSync(reason: .end) }
        }
    }

    private func currentTrack() -> PlaybackContext.Track? {
        guard let context, let player, let item = player.currentItem else { return nil }
        if let idx = trackItems.firstIndex(of: item), idx < context.tracks.count {
            return context.tracks[idx]
        }
        return context.tracks.first
    }

    // MARK: - Sync

    enum SyncReason { case periodic, pause, end }

    private func startSyncLoop(sessionID: String) {
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if Task.isCancelled { return }
                await self?.fireSync(reason: .periodic)
            }
        }
    }

    private func fireSync(reason: SyncReason) async {
        guard let context else { return }
        let pos = position
        let listened = timeListenedAccumulator
        guard listened > 0 || reason != .periodic else { return }
        timeListenedAccumulator = 0
        do {
            try await sessionService.syncSession(
                id: context.sessionID,
                currentTime: pos,
                timeListened: listened,
                duration: context.totalDuration
            )
        } catch {
            Log.player.error("sync failed (\(String(describing: reason), privacy: .public)): \(String(describing: error), privacy: .public)")
            timeListenedAccumulator += listened
        }
    }

    // MARK: - Teardown

    private func teardown(closeServer: Bool) async {
        let pos = position
        let listened = timeListenedAccumulator
        let toClose = context

        syncTask?.cancel()
        syncTask = nil
        sleepTask?.cancel()
        sleepTask = nil
        sleepTimerEndsAt = nil
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        rateObservation?.invalidate(); rateObservation = nil
        currentItemObservation?.invalidate(); currentItemObservation = nil
        player?.pause()
        player = nil
        trackItems = []
        context = nil
        state = .idle
        position = 0
        duration = 0
        nowPlayingTitle = ""
        nowPlayingAuthor = ""
        nowPlayingNarrator = ""
        coverItemID = nil
        timeListenedAccumulator = 0

        if closeServer, let toClose {
            do {
                try await sessionService.closeSession(
                    id: toClose.sessionID,
                    currentTime: pos,
                    timeListened: listened,
                    duration: toClose.totalDuration
                )
            } catch {
                Log.player.error("closeSession failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - Lifecycle

    private func registerLifecycleObservers() {
        #if canImport(UIKit)
        willTerminateObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Best-effort detached close. The app may die before this completes;
            // ABS server-side session timeouts will eventually clean up the session.
            Task { @MainActor in await self?.fireSync(reason: .end) }
        }
        #endif
    }
}
