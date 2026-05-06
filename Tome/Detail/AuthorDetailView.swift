import SwiftUI

struct AuthorDetailView: View {
    let authorID: String
    let libraryID: String?
    @Environment(AppDependencies.self) private var deps
    @State private var vm: AuthorDetailViewModel?

    private static let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 130, maximum: 180), spacing: 16)
    ]

    init(authorID: String, libraryID: String?) {
        self.authorID = authorID
        self.libraryID = libraryID
    }

#if DEBUG
    init(previewVM: AuthorDetailViewModel) {
        self.authorID = previewVM.authorID
        self.libraryID = previewVM.libraryID
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
        .navigationTitle(vm?.author?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task { await ensureVM() }
    }

    @ViewBuilder
    private func content(vm: AuthorDetailViewModel) -> some View {
        if vm.isLoading && vm.author == nil {
            ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.errorMessage, vm.author == nil {
            LibraryErrorView(message: err) { Task { await vm.load() } }
        } else if let author = vm.author {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(author: author)
                    if let bio = author.description, !bio.isEmpty {
                        Text(bio)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let items = author.libraryItems, !items.isEmpty {
                        booksGrid(items: items)
                    }
                }
                .padding(20)
            }
        }
    }

    private func ensureVM() async {
        if vm == nil {
            let m = AuthorDetailViewModel(client: deps.client, authorID: authorID, libraryID: libraryID)
            vm = m
            await m.load()
        }
    }

    private func header(author: AuthorDTO) -> some View {
        HStack(alignment: .center, spacing: 16) {
            initialsAvatar(name: author.name)
                .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 4) {
                Text(author.name)
                    .font(.title2.weight(.semibold))
                if let count = author.numBooks {
                    Text("\(count) book\(count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func initialsAvatar(name: String) -> some View {
        let initials = name.split(separator: " ").compactMap { $0.first }.prefix(2)
        return ZStack {
            Circle().fill(LinearGradient(
                colors: [.indigo.opacity(0.7), .purple.opacity(0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
            Text(initials.map(String.init).joined())
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
        }
    }

    private func booksGrid(items: [LibraryItemDTO]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Books").font(.headline)
            LazyVGrid(columns: Self.columns, spacing: 20) {
                ForEach(items) { item in
                    NavigationLink(value: LibraryRoute.book(itemID: item.id)) {
                        BookCardView(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#if DEBUG
#Preview("Author detail") {
    NavigationStack {
        AuthorDetailView(previewVM: AuthorDetailViewModel(
            previewClient: ABSClient(tokenStore: TokenStore(keychain: KeychainStore(service: "preview"))),
            author: PreviewSupport.sampleAuthor
        ))
        .libraryNavigationDestinations()
    }
    .environment(PreviewSupport.dependencies())
}
#endif
