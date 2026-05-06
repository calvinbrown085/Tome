import SwiftUI

struct ChaptersSheet: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let engine = deps.playerEngine
        let chapters = engine.chapters
        let pos = engine.position
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(TomePalette.ink3)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Text("Chapters")
                .font(.tomeSerif(22, weight: .medium))
                .foregroundStyle(TomePalette.ink0)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

            Rectangle()
                .fill(TomePalette.hairline)
                .frame(height: 0.5)

            if chapters.isEmpty {
                VStack(spacing: 8) {
                    Text("No chapter list")
                        .font(.tomeSerif(17, weight: .medium))
                        .foregroundStyle(TomePalette.ink1)
                    Text("This book doesn't expose chapter markers.")
                        .font(.system(size: 13))
                        .foregroundStyle(TomePalette.ink2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(chapters.enumerated()), id: \.element.id) { idx, chapter in
                            chapterRow(chapter: chapter, position: pos, isLast: idx == chapters.count - 1)
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(TomePalette.bg2)
    }

    private func chapterRow(chapter: ChapterDTO, position pos: TimeInterval, isLast: Bool) -> some View {
        let isCurrent = pos >= chapter.start && pos < chapter.end
        let isPast = pos >= chapter.end
        return VStack(spacing: 0) {
            Button {
                deps.playerEngine.seek(to: chapter.start)
                Haptics.selection()
                dismiss()
            } label: {
                HStack(spacing: 16) {
                    chapterIndicator(chapter: chapter, isCurrent: isCurrent, isPast: isPast)
                        .frame(width: 22)
                    Text(chapter.title ?? "Chapter \(chapter.id)")
                        .font(.tomeSerif(16, weight: isCurrent ? .semibold : .regular))
                        .foregroundStyle(isCurrent ? TomePalette.ember : (isPast ? TomePalette.ink2 : TomePalette.ink0))
                        .strikethrough(isPast, color: TomePalette.ink3)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Text(formatTime(chapter.end - chapter.start))
                        .font(.system(size: 12))
                        .foregroundStyle(TomePalette.ink2)
                        .monospacedDigit()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(isCurrent ? TomePalette.ember.opacity(0.08) : Color.clear)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if !isLast {
                Rectangle()
                    .fill(TomePalette.hairline)
                    .frame(height: 0.5)
                    .padding(.leading, 24)
            }
        }
    }

    @ViewBuilder
    private func chapterIndicator(chapter: ChapterDTO, isCurrent: Bool, isPast: Bool) -> some View {
        if isCurrent {
            EQBars()
        } else {
            Text("\(chapter.id)")
                .font(.tomeSerif(15))
                .italic()
                .foregroundStyle(isPast ? TomePalette.ink3 : TomePalette.ink2)
                .monospacedDigit()
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}

private struct EQBars: View {
    @State private var animating = false
    var body: some View {
        HStack(alignment: .bottom, spacing: 1.5) {
            bar(baseHeight: 6, delay: 0)
            bar(baseHeight: 9, delay: 0.1)
            bar(baseHeight: 12, delay: 0.2)
        }
        .frame(height: 14)
        .onAppear { animating = true }
    }

    private func bar(baseHeight: CGFloat, delay: Double) -> some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(TomePalette.ember)
            .frame(width: 2, height: baseHeight)
            .scaleEffect(y: animating ? 1.0 : 0.4, anchor: .bottom)
            .animation(
                .easeInOut(duration: 0.45)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animating
            )
    }
}
