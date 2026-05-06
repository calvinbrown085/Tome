import SwiftUI

struct BookCardView: View {
    let item: LibraryItemDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            cover
            VStack(alignment: .leading, spacing: 2) {
                Text(item.media?.metadata?.title ?? "Untitled")
                    .font(.tomeSerif(14, weight: .medium))
                    .lineLimit(2, reservesSpace: true)
                    .foregroundStyle(TomePalette.ink0)
                Text(displayAuthor.isEmpty ? " " : displayAuthor)
                    .font(.system(size: 11))
                    .foregroundStyle(TomePalette.ink2)
                    .lineLimit(1, reservesSpace: true)
            }
        }
    }

    private var cover: some View {
        AuthedAsyncImage(itemID: item.id, placeholderHint: item.media?.metadata?.title)
            .aspectRatio(2.0/3.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.40), radius: 10, y: 6)
            .overlay(alignment: .bottom) { progressOverlay }
            .overlay(alignment: .topTrailing) { finishedBadge }
    }

    @ViewBuilder
    private var progressOverlay: some View {
        if let p = item.userMediaProgress?.progress, p > 0, p < 1 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(TomePalette.ink0.opacity(0.18)).frame(height: 2)
                    Rectangle().fill(TomePalette.ember).frame(width: geo.size.width * CGFloat(p), height: 2)
                }
            }
            .frame(height: 2)
            .padding(.horizontal, 0)
            .padding(.bottom, 0)
        }
    }

    @ViewBuilder
    private var finishedBadge: some View {
        if item.userMediaProgress?.isFinished == true {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TomePalette.bg0, TomePalette.ember)
                .padding(6)
        }
    }

    private var displayAuthor: String {
        item.media?.metadata?.displayAuthor ?? ""
    }
}

#if DEBUG
#Preview("Book card") {
    let deps = PreviewSupport.dependencies()
    return BookCardView(item: PreviewSupport.items[0])
        .frame(width: 130)
        .padding()
        .background(TomePalette.bg1)
        .environment(deps)
}
#endif
