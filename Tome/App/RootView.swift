import SwiftUI

struct RootView: View {
    @Environment(AppDependencies.self) private var deps

    var body: some View {
        ZStack {
            switch deps.auth.state {
            case .unknown:
                LaunchSplashView()
            case .loggedOut:
                LoginView()
            case .loggedIn(let url, let username):
                MainTabView(serverURL: url, username: username)
            }
        }
        .animation(.smooth(duration: 0.35), value: deps.auth.state)
        .task {
            await deps.bootstrap()
        }
    }
}

struct LaunchSplashView: View {
    var body: some View {
        ZStack {
            TomeMoodyBackground()
            VStack(spacing: 22) {
                ListeningTLogo(size: 96)
                    .shadow(color: TomePalette.ember.opacity(0.35), radius: 24, y: 12)
                ProgressView()
                    .controlSize(.small)
                    .tint(TomePalette.ember)
            }
        }
    }
}

#Preview("Splash") {
    LaunchSplashView()
}

#Preview("Login → bootstrap") {
    RootView()
        .environment(AppDependencies())
}
