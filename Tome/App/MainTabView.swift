import SwiftUI

private struct OpenFullPlayerKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var openFullPlayer: () -> Void {
        get { self[OpenFullPlayerKey.self] }
        set { self[OpenFullPlayerKey.self] = newValue }
    }
}

struct MainTabView: View {
    let serverURL: URL
    let username: String
    @Environment(AppDependencies.self) private var deps
    @State private var showNowPlaying = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            DownloadsView()
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.to.line")
                }
            SettingsView(serverURL: serverURL, username: username)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(TomePalette.ember)
        .environment(\.openFullPlayer, { showNowPlaying = true })
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerView(onTap: { showNowPlaying = true })
                .animation(.easeInOut(duration: 0.2), value: deps.playerEngine.state)
        }
        .background(TomePalette.bg1.ignoresSafeArea())
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environment(deps)
        }
    }
}
