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
                LoggedInPlaceholderView(serverURL: url, username: username)
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
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.tint)
                ProgressView().controlSize(.small)
            }
        }
    }
}

struct LoggedInPlaceholderView: View {
    let serverURL: URL
    let username: String
    @Environment(AppDependencies.self) private var deps

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
                Text("Signed in")
                    .font(.title.weight(.semibold))
                if !username.isEmpty {
                    Text(username).foregroundStyle(.secondary)
                }
                Text(serverURL.absoluteString)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 12)
                Button("Log out") {
                    Task { await deps.auth.logout() }
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
            }
            .padding()
            .navigationTitle("Tome")
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

#Preview("Signed in") {
    LoggedInPlaceholderView(
        serverURL: URL(string: "https://abs.example.com")!,
        username: "calvin"
    )
    .environment(AppDependencies())
}
