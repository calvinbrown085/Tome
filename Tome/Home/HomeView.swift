import SwiftUI

struct HomeView: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(\.openFullPlayer) private var openFullPlayer
    @State private var homeVM: LibraryHomeViewModel?
    @State private var showingPicker = false
    @State private var navigation = NavigationPath()

    init() {}

#if DEBUG
    init(previewHomeVM: LibraryHomeViewModel) {
        self._homeVM = State(initialValue: previewHomeVM)
    }
#endif

    var body: some View {
        NavigationStack(path: $navigation) {
            ZStack {
                TomePalette.bg1.ignoresSafeArea()
                content
            }
            .navigationTitle("Tome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TomePalette.bg1, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
            .sheet(isPresented: $showingPicker) {
                LibraryPickerSheet()
            }
            .task { await bootstrapIfNeeded() }
            .task(id: deps.librarySelection.selectedLibraryID) {
                await rebuildVMIfNeeded()
            }
            .refreshable {
                await homeVM?.load()
                Haptics.success()
            }
            .libraryNavigationDestinations()
        }
        .tint(TomePalette.ember)
    }

    @ViewBuilder
    private var content: some View {
        switch deps.librarySelection.loadState {
        case .idle:
            ProgressView()
                .tint(TomePalette.ember)
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading where homeVM == nil:
            ProgressView()
                .tint(TomePalette.ember)
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let msg):
            LibraryErrorView(message: msg) {
                Task { await deps.librarySelection.load(using: deps.client, force: true) }
            }
        case .loaded, .loading:
            if let homeVM {
                shelvedHome(vm: homeVM)
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

    // MARK: - Shelves

    private func shelvedHome(vm: LibraryHomeViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                greetingHero
                bigPlayCardSection(vm: vm)
                shelf(
                    title: "Continue listening",
                    state: vm.inProgressState,
                    items: vm.inProgressItems,
                    seeAllRoute: .browse(libraryID: vm.libraryID)
                )
                shelf(
                    title: "Recently added",
                    state: vm.recentlyAddedState,
                    items: vm.recentlyAddedItems,
                    seeAllRoute: .browse(libraryID: vm.libraryID)
                )
                browseAllLink(libraryID: vm.libraryID)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(
            TomeLampGlow()
                .frame(width: 480, height: 480)
                .opacity(0.5)
                .offset(x: -160, y: -200)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private func bigPlayCardSection(vm: LibraryHomeViewModel) -> some View {
        if let item = vm.inProgressItems.first {
            BigPlayCardView(
                item: item,
                onTapBody: {
                    navigation.append(LibraryRoute.book(itemID: item.id))
                },
                onTapPlay: {
                    deps.playerEngine.play(item: item)
                    openFullPlayer()
                }
            )
            .padding(.horizontal, 20)
        }
    }

    private var greetingHero: some View {
        VStack(alignment: .leading, spacing: 4) {
            TomeEyebrow(text: weekdayString)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(timeOfDayGreeting), ")
                    .font(.tomeSerif(32, weight: .medium))
                    .foregroundStyle(TomePalette.ink0)
                Text(displayName)
                    .font(.tomeSerif(32, weight: .medium))
                    .italic()
                    .foregroundStyle(TomePalette.ember)
            }
            .tracking(-0.3)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }

    private var weekdayString: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: Date())
    }

    private var timeOfDayGreeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Good night"
        }
    }

    private var displayName: String {
        switch deps.auth.state {
        case .loggedIn(_, let username):
            return username
        default:
            return ""
        }
    }

    @ViewBuilder
    private func shelf(
        title: String,
        state: LibraryHomeViewModel.ShelfState,
        items: [LibraryItemDTO],
        seeAllRoute: LibraryRoute
    ) -> some View {
        switch state {
        case .empty:
            EmptyView()
        case .failed(let msg):
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.tomeSerif(22, weight: .medium))
                    .foregroundStyle(TomePalette.ink0)
                    .padding(.horizontal, 24)
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(TomePalette.ink2)
                    .padding(.horizontal, 24)
            }
        case .loading where items.isEmpty, .idle:
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.tomeSerif(22, weight: .medium))
                    .foregroundStyle(TomePalette.ink0)
                    .padding(.horizontal, 24)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(0..<6, id: \.self) { _ in
                            SkeletonCardView().frame(width: 130, height: 130 * 1.5 + 40)
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
        default:
            ShelfRow(title: title, items: items, seeAllRoute: seeAllRoute)
        }
    }

    private func browseAllLink(libraryID: String) -> some View {
        NavigationLink(value: LibraryRoute.browse(libraryID: libraryID)) {
            HStack {
                Text("Browse all")
                    .font(.tomeSerif(17, weight: .medium))
                    .foregroundStyle(TomePalette.ink0)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TomePalette.ember)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(TomePalette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(TomePalette.hairline, lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
    }

    // MARK: - Bootstrap

    private func bootstrapIfNeeded() async {
        switch deps.librarySelection.loadState {
        case .idle, .failed:
            await deps.librarySelection.load(using: deps.client)
        default:
            break
        }
    }

    private func rebuildVMIfNeeded() async {
        guard let id = deps.librarySelection.selectedLibraryID else {
            homeVM = nil
            return
        }
        if homeVM?.libraryID != id {
            let vm = LibraryHomeViewModel(client: deps.client, libraryID: id)
            homeVM = vm
            await vm.load()
        }
    }
}

#if DEBUG
#Preview("Home — populated") {
    HomeView(previewHomeVM: PreviewSupport.homeViewModel())
        .environment(PreviewSupport.dependencies())
}

#Preview("Home — only recents (empty in-progress)") {
    HomeView(previewHomeVM: PreviewSupport.homeViewModel(inProgress: []))
        .environment(PreviewSupport.dependencies())
}
#endif
