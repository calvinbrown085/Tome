import SwiftUI

/// Hero "Continue listening" card on the Home tab — matches FeatureCard from screens.jsx.
struct BigPlayCardView: View {
    let item: LibraryItemDTO
    var onTapBody: () -> Void
    var onTapPlay: () -> Void

    var body: some View {
        Button(action: onTapBody) {
            HStack(alignment: .center, spacing: 18) {
                cover
                textColumn
                playButton
            }
            .padding(20)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(TomePalette.hairline, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 25, y: 14)
        }
        .buttonStyle(.plain)
    }

    private var cover: some View {
        AuthedAsyncImage(itemID: item.id, placeholderHint: title)
            .aspectRatio(1, contentMode: .fill)
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.5), radius: 10, y: 5)
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 4) {
            TomeEyebrow(text: "Continue", color: TomePalette.ember)
            Text(title)
                .font(.tomeSerif(22, weight: .medium))
                .foregroundStyle(TomePalette.ink0)
                .lineLimit(1)
                .tracking(-0.2)
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(TomePalette.ink2)
                .lineLimit(1)
                .padding(.top, 1)
            progressBar
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(TomePalette.ink0.opacity(0.12))
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(TomePalette.ember)
                    .frame(width: max(0, geo.size.width * CGFloat(progress)))
            }
        }
        .frame(height: 3)
    }

    private var playButton: some View {
        Button {
            onTapPlay()
            Haptics.tap()
        } label: {
            Image(systemName: "play.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TomePalette.bg0)
                .frame(width: 50, height: 50)
                .background(Circle().fill(TomePalette.ember))
                .shadow(color: TomePalette.ember.opacity(0.4), radius: 14, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume \(title)")
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [TomePalette.plum, TomePalette.bg2],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            TomePalette.bg0.opacity(0.55)
        }
    }

    // MARK: - Data

    private var title: String { item.media?.metadata?.title ?? "Untitled" }
    private var displayAuthor: String { item.media?.metadata?.displayAuthor ?? "" }
    private var progress: Double {
        let p = item.userMediaProgress?.progress ?? 0
        return max(0, min(1, p))
    }
    private var totalDuration: Double {
        item.userMediaProgress?.duration ?? item.media?.duration ?? 0
    }
    private var currentTime: Double {
        item.userMediaProgress?.currentTime ?? 0
    }
    private var subtitle: String {
        let left = max(0, totalDuration - currentTime)
        let formatted = Self.formatTimeLeft(left)
        if displayAuthor.isEmpty { return "\(formatted) left" }
        return "\(displayAuthor) · \(formatted) left"
    }

    static func formatTimeLeft(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

#if DEBUG
#Preview("Big play card") {
    let deps = PreviewSupport.dependencies()
    return BigPlayCardView(
        item: PreviewSupport.items[0],
        onTapBody: {},
        onTapPlay: {}
    )
    .padding()
    .background(TomePalette.bg1)
    .environment(deps)
}
#endif
