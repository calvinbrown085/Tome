import SwiftUI

struct BookListRowView: View {
    let item: LibraryItemDTO

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AuthedAsyncImage(itemID: item.id, placeholderHint: item.media?.metadata?.title)
                .aspectRatio(2.0/3.0, contentMode: .fill)
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .shadow(color: .black.opacity(0.15), radius: 3, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.media?.metadata?.title ?? "Untitled")
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                let author = item.media?.metadata?.displayAuthor ?? ""
                if !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let p = item.userMediaProgress?.progress, p > 0, p < 1 {
                    progressBar(value: p)
                } else if item.userMediaProgress?.isFinished == true {
                    Label("Finished", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func progressBar(value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.secondary.opacity(0.25)).frame(height: 3)
                Capsule().fill(.tint).frame(width: geo.size.width * CGFloat(value), height: 3)
            }
        }
        .frame(height: 3)
        .padding(.top, 4)
    }
}

#if DEBUG
#Preview("Book list row") {
    VStack(spacing: 0) {
        BookListRowView(item: PreviewSupport.items[0])
        Divider().padding(.leading, 76)
        BookListRowView(item: PreviewSupport.items[2])
        Divider().padding(.leading, 76)
        BookListRowView(item: PreviewSupport.items[4])
    }
    .environment(PreviewSupport.dependencies())
}
#endif
