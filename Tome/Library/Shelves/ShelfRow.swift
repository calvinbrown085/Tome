import SwiftUI

struct ShelfRow: View {
    let title: String
    let items: [LibraryItemDTO]
    let seeAllRoute: LibraryRoute?

    private static let cardWidth: CGFloat = 130

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(items) { item in
                        NavigationLink(value: LibraryRoute.book(itemID: item.id)) {
                            BookCardView(item: item)
                                .frame(width: Self.cardWidth)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 4)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.tomeSerif(22, weight: .medium))
                .foregroundStyle(TomePalette.ink0)
                .tracking(-0.2)
            Spacer()
            if let seeAllRoute {
                NavigationLink(value: seeAllRoute) {
                    HStack(spacing: 2) {
                        Text("See all")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(TomePalette.ember)
                }
            }
        }
        .padding(.horizontal, 24)
    }
}

#if DEBUG
#Preview("Shelf row") {
    NavigationStack {
        ShelfRow(
            title: "Continue listening",
            items: Array(PreviewSupport.items.prefix(8)),
            seeAllRoute: .browse(libraryID: "lib_books")
        )
        .libraryNavigationDestinations()
    }
    .environment(PreviewSupport.dependencies())
    .background(TomePalette.bg1)
}
#endif
