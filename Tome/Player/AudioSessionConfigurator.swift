import Foundation
import AVFAudio
import os

@MainActor
enum AudioSessionConfigurator {
    private static var didActivate = false

    /// Configures the shared `AVAudioSession` for non-mixing background audio playback.
    /// Idempotent — safe to call on every play.
    static func activateForPlayback() {
        guard !didActivate else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true, options: [])
            didActivate = true
        } catch {
            Log.player.error("AudioSession activation failed: \(String(describing: error), privacy: .public)")
        }
    }
}
