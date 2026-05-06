import SwiftUI

struct SettingsView: View {
    @Environment(AppDependencies.self) private var deps
    let serverURL: URL
    let username: String

    var body: some View {
        NavigationStack {
            ZStack {
                TomePalette.bg1.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        accountCard
                        signOutButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(TomePalette.bg1, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(TomePalette.ember)
    }

    private var accountCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [TomePalette.ember, TomePalette.emberDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Text(initial)
                    .font(.tomeSerif(22, weight: .medium))
                    .italic()
                    .foregroundStyle(TomePalette.bg0)
            }
            .frame(width: 50, height: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(username)
                    .font(.tomeSerif(18, weight: .medium))
                    .foregroundStyle(TomePalette.ink0)
                Text(serverURL.host() ?? serverURL.absoluteString)
                    .font(.system(size: 11))
                    .foregroundStyle(TomePalette.ink2)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text("SYNCED")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(TomePalette.gold)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(TomePalette.gold.opacity(0.12))
                )
        }
        .padding(18)
        .background(TomePalette.bg2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(TomePalette.hairline, lineWidth: 0.5)
        )
    }

    private var signOutButton: some View {
        Button {
            Task { await deps.auth.logout() }
        } label: {
            Text("Sign out")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(TomePalette.ember)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(TomePalette.ember.opacity(0.3), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    private var initial: String {
        username.first.map { String($0).uppercased() } ?? "T"
    }
}

#if DEBUG
#Preview("Settings") {
    SettingsView(
        serverURL: URL(string: "https://abs.example.com")!,
        username: "Emily"
    )
    .environment(PreviewSupport.dependencies())
}
#endif
