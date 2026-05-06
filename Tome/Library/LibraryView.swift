import SwiftUI

struct LibraryView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var showingPicker = false

    init() {}

    var body: some View {
        NavigationStack {
            ZStack {
                TomePalette.bg1.ignoresSafeArea()
                content
            }
            .navigationTitle(deps.librarySelection.selectedLibrary?.name ?? "Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TomePalette.bg1, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingPicker) {
                LibraryPickerSheet()
            }
            .task { await bootstrapIfNeeded() }
            .libraryNavigationDestinations()
        }
        .tint(TomePalette.ember)
    }

    @ViewBuilder
    private var content: some View {
        switch deps.librarySelection.loadState {
        case .idle, .loading:
            ProgressView()
                .tint(TomePalette.ember)
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let msg):
            LibraryErrorView(message: msg) {
                Task { await deps.librarySelection.load(using: deps.client, force: true) }
            }
        case .loaded:
            if let libraryID = deps.librarySelection.selectedLibraryID {
                BrowseView(libraryID: libraryID)
            } else if deps.librarySelection.libraries.isEmpty {
                LibraryEmptyView(filter: .all)
            } else {
                ProgressView()
                    .tint(TomePalette.ember)
                    .controlSize(.large)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if deps.librarySelection.libraries.count > 1 {
                Button {
                    showingPicker = true
                } label: {
                    Image(systemName: "books.vertical")
                        .foregroundStyle(TomePalette.ink0)
                }
                .accessibilityLabel("Switch library")
            }
        }
    }

    private func bootstrapIfNeeded() async {
        switch deps.librarySelection.loadState {
        case .idle, .failed:
            await deps.librarySelection.load(using: deps.client)
        default:
            break
        }
    }
}

#if DEBUG
#Preview("Library — browse") {
    LibraryView()
        .environment(PreviewSupport.dependencies())
}
#endif
