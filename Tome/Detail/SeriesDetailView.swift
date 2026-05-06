import SwiftUI

struct SeriesDetailView: View {
    let seriesID: String
    let libraryID: String
    let name: String
    @Environment(AppDependencies.self) private var deps
    @State private var vm: SeriesDetailViewModel?

    private static let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 130, maximum: 180), spacing: 16)
    ]

    init(seriesID: String, libraryID: String, name: String) {
        self.seriesID = seriesID
        self.libraryID = libraryID
        self.name = name
    }

#if DEBUG
    init(previewVM: SeriesDetailViewModel) {
        self.seriesID = previewVM.seriesID
        self.libraryID = previewVM.libraryID
        self.name = previewVM.name
        self._vm = State(initialValue: previewVM)
    }
#endif

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await ensureVM() }
    }

    @ViewBuilder
    private func content(vm: SeriesDetailViewModel) -> some View {
        if vm.isLoading && vm.items.isEmpty {
            ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.errorMessage, vm.items.isEmpty {
            LibraryErrorView(message: err) { Task { await vm.load() } }
        } else if vm.items.isEmpty {
            ContentUnavailableView("No books in this series", systemImage: "books.vertical")
        } else {
            ScrollView {
                LazyVGrid(columns: Self.columns, spacing: 20) {
                    ForEach(vm.items) { item in
                        NavigationLink(value: LibraryRoute.book(itemID: item.id)) {
                            BookCardView(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
    }

    private func ensureVM() async {
        if vm == nil {
            let m = SeriesDetailViewModel(client: deps.client, seriesID: seriesID, libraryID: libraryID, name: name)
            vm = m
            await m.load()
        }
    }
}

#if DEBUG
#Preview("Series detail") {
    NavigationStack {
        SeriesDetailView(previewVM: SeriesDetailViewModel(
            previewClient: ABSClient(tokenStore: TokenStore(keychain: KeychainStore(service: "preview"))),
            seriesID: "ser_1",
            libraryID: "lib_books",
            name: "The Expanse",
            items: Array(PreviewSupport.items.prefix(4))
        ))
        .libraryNavigationDestinations()
    }
    .environment(PreviewSupport.dependencies())
}
#endif
