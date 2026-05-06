import SwiftUI

struct BrowseView: View {
    let libraryID: String
    @Environment(AppDependencies.self) private var deps
    @State private var listVM: LibraryListViewModel?
    @State private var sort: LibrarySort = .recentlyAdded
    @State private var filter: LibraryFilter = .all

    init(libraryID: String) {
        self.libraryID = libraryID
    }

#if DEBUG
    init(previewListVM: LibraryListViewModel) {
        self.libraryID = previewListVM.libraryID
        self._listVM = State(initialValue: previewListVM)
        self._sort = State(initialValue: previewListVM.sort)
        self._filter = State(initialValue: previewListVM.filter)
    }
#endif

    var body: some View {
        VStack(spacing: 0) {
            FilterPillRow(filter: $filter)
                .padding(.vertical, 10)
            Group {
                if let listVM {
                    LibraryGridView(vm: listVM)
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { await ensureVM() }
        .refreshable {
            await listVM?.refresh()
            Haptics.success()
        }
        .onChange(of: filter) { _, _ in applyFilter() }
        .onChange(of: sort) { _, _ in applySort() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                deps.libraryDensity.density = deps.libraryDensity.density.next
                Haptics.selection()
            } label: {
                Image(systemName: deps.libraryDensity.density.systemImage)
            }
            .accessibilityLabel("Toggle density (\(deps.libraryDensity.density.displayName))")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(LibrarySort.allCases) { Text($0.displayName).tag($0) }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .accessibilityLabel("Sort")
        }
    }

    private func ensureVM() async {
        if listVM == nil {
            let vm = LibraryListViewModel(client: deps.client, libraryID: libraryID)
            vm.sort = sort
            vm.filter = filter
            listVM = vm
            await vm.refresh()
        }
    }

    private func applyFilter() {
        Haptics.selection()
        guard let listVM else { return }
        Task { await listVM.apply(sort: sort, filter: filter) }
    }

    private func applySort() {
        Haptics.selection()
        guard let listVM else { return }
        Task { await listVM.apply(sort: sort, filter: filter) }
    }
}

private struct FilterPillRow: View {
    @Binding var filter: LibraryFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryFilter.allCases) { option in
                    Button {
                        filter = option
                    } label: {
                        Text(option.displayName)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(option == filter ? Color.accentColor : Color.secondary.opacity(0.18))
                            )
                            .foregroundStyle(option == filter ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

#if DEBUG
#Preview("Browse — populated") {
    NavigationStack {
        BrowseView(previewListVM: PreviewSupport.listViewModel())
            .libraryNavigationDestinations()
    }
    .environment(PreviewSupport.dependencies())
}

#Preview("Filter pill row") {
    StatefulPreviewWrapper(LibraryFilter.all) { binding in
        FilterPillRow(filter: binding)
            .padding()
    }
}

private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    let content: (Binding<Value>) -> Content
    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        self._value = State(initialValue: initial)
        self.content = content
    }
    var body: some View { content($value) }
}
#endif
