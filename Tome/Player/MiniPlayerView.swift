import SwiftUI

struct MiniPlayerView: View {
    @Environment(AppDependencies.self) private var deps
    var onTap: () -> Void = {}

    var body: some View {
        let engine = deps.playerEngine
        if engine.state != .idle {
            content(engine: engine)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private func content(engine: PlayerEngine) -> some View {
        HStack(spacing: 12) {
            Button {
                onTap()
                Haptics.tap()
            } label: {
                HStack(spacing: 12) {
                    cover(engine: engine)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(engine.nowPlayingTitle)
                            .font(.tomeSerif(14, weight: .medium))
                            .foregroundStyle(TomePalette.ink0)
                            .lineLimit(1)
                        if !engine.nowPlayingAuthor.isEmpty {
                            Text(engine.nowPlayingAuthor)
                                .font(.system(size: 11))
                                .foregroundStyle(TomePalette.ink2)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Now Playing")

            Button {
                engine.skipBackward(seconds: 30)
            } label: {
                Image(systemName: "gobackward.30")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(TomePalette.ink1)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Skip back 30 seconds")

            Button {
                engine.togglePlayPause()
            } label: {
                Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TomePalette.ember)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.state == .playing ? "Pause" : "Play")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(TomePalette.bg2.opacity(0.92))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(TomePalette.hairline2, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 18, y: 10)
    }

    @ViewBuilder
    private func cover(engine: PlayerEngine) -> some View {
        if let id = engine.coverItemID {
            AuthedAsyncImage(itemID: id, placeholderHint: engine.nowPlayingTitle)
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(TomePalette.ink2.opacity(0.15))
        }
    }
}
