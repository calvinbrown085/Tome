import SwiftUI

struct DownloadsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                TomePalette.bg1.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 38, weight: .light))
                        .foregroundStyle(TomePalette.ember.opacity(0.7))
                        .padding(.bottom, 6)
                    Text("Nothing saved yet")
                        .font(.tomeSerif(22, weight: .medium))
                        .foregroundStyle(TomePalette.ink0)
                    Text("Download a book from its detail page to listen offline.")
                        .font(.system(size: 14))
                        .foregroundStyle(TomePalette.ink2)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Downloads")
            .toolbarBackground(TomePalette.bg1, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(TomePalette.ember)
    }
}

#if DEBUG
#Preview {
    DownloadsView()
}
#endif
