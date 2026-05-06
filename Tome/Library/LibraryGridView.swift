import SwiftUI

struct LibraryGridView: View {
    @Bindable var vm: LibraryListViewModel
    @Environment(AppDependencies.self) private var deps

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.items.isEmpty {
            skeletonGrid
        } else if let err = vm.errorMessage, vm.items.isEmpty {
            LibraryErrorView(message: err) {
                Task { await vm.refresh() }
            }
        } else if vm.items.isEmpty, case .loaded = vm.state {
            LibraryEmptyView(filter: vm.filter)
        } else {
            switch deps.libraryDensity.density {
            case .compact, .regular:
                grid(minimum: deps.libraryDensity.density.gridMinimum)
            case .list:
                listLayout
            }
            if vm.isLoadingMore {
                ProgressView()
                    .controlSize(.small)
                    .padding(.vertical, 24)
            }
        }
    }

    private func grid(minimum: CGFloat) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minimum, maximum: 140), spacing: 28)],
            spacing: 28
        ) {
            ForEach(vm.items) { item in
                NavigationLink(value: LibraryRoute.book(itemID: item.id)) {
                    BookCardView(item: item)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                .task { await vm.loadNextIfNeeded(after: item) }
            }
        }
    }

    private var listLayout: some View {
        LazyVStack(spacing: 0) {
            ForEach(vm.items) { item in
                NavigationLink(value: LibraryRoute.book(itemID: item.id)) {
                    BookListRowView(item: item)
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                .task { await vm.loadNextIfNeeded(after: item) }
                Divider().padding(.leading, 90)
            }
        }
        .padding(.horizontal, -16)
    }

    private var skeletonGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 28)],
            spacing: 28
        ) {
            ForEach(0..<9, id: \.self) { _ in
                SkeletonCardView()
            }
        }
    }
}

#if DEBUG
#Preview("Grid — populated") {
    LibraryGridView(vm: PreviewSupport.listViewModel())
        .environment(PreviewSupport.dependencies())
}

#Preview("Grid — empty (in progress)") {
    let vm = PreviewSupport.listViewModel(items: [])
    vm.filter = .inProgress
    return LibraryGridView(vm: vm)
        .environment(PreviewSupport.dependencies())
}
#endif