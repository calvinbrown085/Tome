import SwiftUI

struct NowPlayingView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss

    @State private var scrubbing = false
    @State private var scrubPosition: TimeInterval = 0
    @State private var showSpeed = false
    @State private var showSleep = false
    @State private var showChapters = false

    var body: some View {
        let engine = deps.playerEngine
        ZStack {
            background
            VStack(spacing: 0) {
                header(engine: engine)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                cover(engine: engine)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
                titleBlock(engine: engine)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 14)
                scrubber(engine: engine)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                controls(engine: engine)
                    .padding(.horizontal, 32)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                Spacer(minLength: 0)
                bottomActions(engine: engine)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSpeed) {
            SpeedSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(TomePalette.bg2)
        }
        .sheet(isPresented: $showSleep) {
            SleepSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationBackground(TomePalette.bg2)
        }
        .sheet(isPresented: $showChapters) {
            ChaptersSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(TomePalette.bg2)
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            TomePalette.bg0
            RadialGradient(
                stops: [
                    .init(color: TomePalette.plum, location: 0),
                    .init(color: TomePalette.plum.opacity(0.85), location: 0.25),
                    .init(color: TomePalette.bg0, location: 0.7)
                ],
                center: UnitPoint(x: 0.5, y: 0.3),
                startRadius: 0,
                endRadius: 480
            )
            LinearGradient(
                stops: [
                    .init(color: TomePalette.bg0.opacity(0.4), location: 0),
                    .init(color: TomePalette.bg0.opacity(0.1), location: 0.35),
                    .init(color: TomePalette.bg0.opacity(0.7), location: 0.75),
                    .init(color: TomePalette.bg0.opacity(0.95), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Header

    private func header(engine: PlayerEngine) -> some View {
        HStack {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(TomeRoundButtonStyle())
            .accessibilityLabel("Close")

            Spacer()

            VStack(spacing: 1) {
                Text("NOW PLAYING")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(TomePalette.ink2)
                Text(engine.nowPlayingAuthor)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TomePalette.ink0)
                    .lineLimit(1)
            }

            Spacer()

            Button {} label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(TomeRoundButtonStyle())
            .accessibilityLabel("More")
        }
    }

    // MARK: - Cover

    private func cover(engine: PlayerEngine) -> some View {
        Group {
            if let id = engine.coverItemID {
                AuthedAsyncImage(itemID: id, placeholderHint: engine.nowPlayingTitle)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(TomePalette.ink2.opacity(0.15))
            }
        }
        .frame(width: 240, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.6), radius: 30, y: 20)
        .scaleEffect(engine.state == .playing ? 1.0 : 0.92)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: engine.state)
    }

    // MARK: - Title block

    private func titleBlock(engine: PlayerEngine) -> some View {
        VStack(spacing: 6) {
            if let chapter = engine.currentChapterTitle, !chapter.isEmpty {
                Text(chapter.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(TomePalette.gold)
                    .lineLimit(1)
            }
            Text(engine.nowPlayingTitle)
                .font(.tomeSerif(26, weight: .medium))
                .foregroundStyle(TomePalette.ink0)
                .lineLimit(1)
                .tracking(-0.2)
            if !engine.nowPlayingNarrator.isEmpty {
                Text(engine.nowPlayingNarrator)
                    .font(.system(size: 13))
                    .foregroundStyle(TomePalette.ink2)
                    .lineLimit(1)
                    .padding(.top, 1)
            }
        }
    }

    // MARK: - Scrubber

    private func scrubber(engine: PlayerEngine) -> some View {
        let displayPosition = scrubbing ? scrubPosition : engine.position
        let total = max(engine.duration, 0.001)
        let progress = max(0, min(1, displayPosition / total))
        let remaining = max(0, total - displayPosition)

        return VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(TomePalette.ink0.opacity(0.12))
                        .frame(height: 3)
                    Capsule()
                        .fill(TomePalette.ember)
                        .frame(width: width * progress, height: 3)
                        .shadow(color: TomePalette.ember.opacity(0.5), radius: 6)
                    Circle()
                        .fill(TomePalette.ember)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                        .offset(x: max(0, min(width, width * progress)) - 7)
                }
                .frame(height: 24)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !scrubbing {
                                scrubbing = true
                                scrubPosition = engine.position
                            }
                            let ratio = max(0, min(1, value.location.x / width))
                            scrubPosition = total * Double(ratio)
                        }
                        .onEnded { _ in
                            engine.seek(to: scrubPosition)
                            scrubbing = false
                            Haptics.selection()
                        }
                )
            }
            .frame(height: 24)

            HStack {
                Text(formatTime(displayPosition))
                Spacer()
                Text("−" + formatTime(remaining))
            }
            .font(.system(size: 11))
            .foregroundStyle(TomePalette.ink2)
            .monospacedDigit()
        }
    }

    // MARK: - Controls

    private func controls(engine: PlayerEngine) -> some View {
        HStack(spacing: 0) {
            controlButton(size: 44, action: { engine.seekToPreviousTrack(); Haptics.tap() }) {
                Image(systemName: "backward.end.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(TomePalette.ink0)
            }
            .accessibilityLabel("Previous track")

            Spacer()

            controlButton(size: 56, action: { engine.skipBackward(seconds: 10); Haptics.tap() }) {
                ZStack {
                    Image(systemName: "gobackward")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(TomePalette.ink0)
                    Text("10")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TomePalette.ink0)
                        .offset(y: 1)
                }
            }
            .accessibilityLabel("Skip back 10 seconds")

            Spacer()

            Button {
                engine.togglePlayPause()
                Haptics.tap()
            } label: {
                Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(TomePalette.bg0)
                    .frame(width: 80, height: 80)
                    .background(Circle().fill(TomePalette.ink0))
                    .shadow(color: TomePalette.ink0.opacity(0.25), radius: 18, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(engine.state == .playing ? "Pause" : "Play")

            Spacer()

            controlButton(size: 56, action: { engine.skipForward(seconds: 30); Haptics.tap() }) {
                ZStack {
                    Image(systemName: "goforward")
                        .font(.system(size: 30, weight: .light))
                        .foregroundStyle(TomePalette.ink0)
                    Text("30")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TomePalette.ink0)
                        .offset(y: 1)
                }
            }
            .accessibilityLabel("Skip forward 30 seconds")

            Spacer()

            controlButton(size: 44, action: { engine.seekToNextTrack(); Haptics.tap() }) {
                Image(systemName: "forward.end.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(TomePalette.ink0)
            }
            .accessibilityLabel("Next track")
        }
    }

    private func controlButton<L: View>(size: CGFloat, action: @escaping () -> Void, @ViewBuilder label: () -> L) -> some View {
        Button(action: action) {
            label()
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom action bar

    private func bottomActions(engine: PlayerEngine) -> some View {
        HStack {
            bottomAction(active: engine.playbackRate != 1.0, action: { showSpeed = true }) {
                Text(String(format: "%.1f×", engine.playbackRate))
                    .font(.tomeSerif(16, weight: .medium))
                    .italic()
            }
            .accessibilityLabel("Playback speed")
            Spacer()
            bottomAction(active: engine.sleepRemainingMinutes != nil, action: { showSleep = true }) {
                if let mins = engine.sleepRemainingMinutes {
                    Text("\(mins)m")
                        .font(.system(size: 12, weight: .semibold))
                } else {
                    Image(systemName: "moon")
                        .font(.system(size: 18, weight: .regular))
                }
            }
            .accessibilityLabel("Sleep timer")
            Spacer()
            bottomAction(active: false, action: { showChapters = true }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .regular))
            }
            .accessibilityLabel("Chapters")
            Spacer()
            bottomAction(active: false, action: {}) {
                Image(systemName: "bookmark")
                    .font(.system(size: 18, weight: .regular))
            }
            .accessibilityLabel("Bookmark")
            Spacer()
            bottomAction(active: false, action: {}) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 18, weight: .regular))
            }
            .accessibilityLabel("AirPlay")
        }
    }

    private func bottomAction<L: View>(active: Bool, action: @escaping () -> Void, @ViewBuilder label: () -> L) -> some View {
        Button(action: action) {
            label()
                .foregroundStyle(active ? TomePalette.ember : TomePalette.ink1)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(active ? TomePalette.ember.opacity(0.18) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Utility

    private func formatTime(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
