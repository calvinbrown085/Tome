import SwiftUI

struct SearchView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var vm: SearchViewModel?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Search")
                .searchable(text: queryBinding, placement: .navigationBarDrawer(displayMode: .always), prompt: searchPrompt)
                .libraryNavigationDestinations()
                .task { ensureVM() }
                .task(id: queryDebounceID) { await debouncedSearch() }
        }
    }

    private var queryDebounceID: String {
        (vm?.query ?? "") + "|" + (deps.librarySelection.selectedLibraryID ?? "")
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { vm?.query ?? "" },
            set: { vm?.query = $0 }
        )
    }

    private var searchPrompt: String {
        if let name = deps.librarySelection.selectedLibrary?.name {
            return "Search \(name)"
        }
        return "Search"
    }

    @ViewBuilder
    private var content: some View {
        if let vm {
            if vm.trimmedQuery.isEmpty {
                idlePrompt
            } else if vm.isLoading && !vm.hasResults {
                ProgressView().controlSize(.large).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = vm.errorMessage, !vm.hasResults {
                LibraryErrorView(message: err) {
                    Task { await runSearchNow() }
                }
            } else if let results = vm.results, vm.hasResults {
                SearchResultsList(results: results, libraryID: deps.librarySelection.selectedLibraryID)
            } else {
                ContentUnavailableView.search(text: vm.trimmedQuery)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var idlePrompt: some View {
        ContentUnavailableView(
            "Search Your Library",
            systemImage: "magnifyingglass",
            description: Text("Find books by title, author, narrator, or series.")
        )
    }

    private func ensureVM() {
        if vm == nil {
            vm = SearchViewModel(client: deps.client)
        }
    }

    private func debouncedSearch() async {
        guard let vm, let libraryID = deps.librarySelection.selectedLibraryID else { return }
        if vm.trimmedQuery.isEmpty {
            await vm.runSearch(libraryID: libraryID)
            return
        }
        try? await Task.sleep(for: .milliseconds(300))
        if Task.isCancelled { return }
        await vm.runSearch(libraryID: libraryID)
    }

    private func runSearchNow() async {
        guard let vm, let libraryID = deps.librarySelection.selectedLibraryID else { return }
        await vm.runSearch(libraryID: libraryID)
    }
}

private struct SearchResultsList: View {
    let results: SearchResultDTO
    let libraryID: String?

    var body: some View {
        List {
            if let books = results.book, !books.isEmpty {
                Section("Books") {
                    ForEach(books, id: \.libraryItem.id) { hit in
                        NavigationLink(value: LibraryRoute.book(itemID: hit.libraryItem.id)) {
                            BookSearchRow(item: hit.libraryItem)
                        }
                    }
                }
            }
            if let authors = results.authors, !authors.isEmpty {
                Section("Authors") {
                    ForEach(authors) { author in
                        NavigationLink(value: LibraryRoute.author(authorID: author.id, libraryID: libraryID)) {
                            AuthorSearchRow(author: author)
                        }
                    }
                }
            }
            if let series = results.series, !series.isEmpty, let libraryID {
                Section("Series") {
                    ForEach(series, id: \.series.id) { hit in
                        NavigationLink(value: LibraryRoute.series(seriesID: hit.series.id, libraryID: libraryID, name: hit.series.name)) {
                            SeriesSearchRow(hit: hit)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

private struct BookSearchRow: View {
    let item: LibraryItemDTO

    var body: some View {
        HStack(spacing: 12) {
            AuthedAsyncImage(itemID: item.id)
                .aspectRatio(2.0/3.0, contentMode: .fill)
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.media?.metadata?.title ?? "Untitled")
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                let author = item.media?.metadata?.displayAuthor ?? ""
                if !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct AuthorSearchRow: View {
    let author: AuthorDTO

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(
                    colors: [.indigo.opacity(0.7), .purple.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                Text(initials(of: author.name))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(author.name).font(.callout.weight(.medium))
                if let n = author.numBooks {
                    Text("\(n) book\(n == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func initials(of name: String) -> String {
        name.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined()
    }
}

private struct SeriesSearchRow: View {
    let hit: SearchSeriesHitDTO

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .foregroundStyle(.tint)
                .font(.title3)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(hit.series.name).font(.callout.weight(.medium))
                if let books = hit.books, !books.isEmpty {
                    Text("\(books.count) book\(books.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("Search — idle") {
    SearchView()
        .environment(PreviewSupport.dependencies())
}

#Preview("Search row — book") {
    BookSearchRow(item: PreviewSupport.items[0])
        .padding()
        .environment(PreviewSupport.dependencies())
}
#endif
