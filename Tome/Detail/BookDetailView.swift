import SwiftUI

struct BookDetailView: View {
    let itemID: String
    @Environment(AppDependencies.self) private var deps
    @State private var vm: BookDetailViewModel?

    init(itemID: String) {
        self.itemID = itemID
    }

#if DEBUG
    init(previewVM: BookDetailViewModel) {
        self.itemID = previewVM.itemID
        self._vm = State(initialValue: previewVM)
    }
#endif

    var body: some View {
        ZStack {
            TomePalette.bg1.ignoresSafeArea()
            Group {
                if let vm {
                    content(vm: vm)
                } else {
                    ProgressView()
                        .tint(TomePalette.ember)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(TomePalette.bg1.opacity(0.001), for: .navigationBar)
        .task { await ensureVM() }
    }

    @ViewBuilder
    private func content(vm: BookDetailViewModel) -> some View {
        if vm.isLoading && vm.item == nil {
            ProgressView()
                .tint(TomePalette.ember)
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.errorMessage, vm.item == nil {
            LibraryErrorView(message: err) { Task { await vm.load() } }
        } else if let item = vm.item {
            ScrollView {
                VStack(spacing: 0) {
                    heroBackdrop(item: item)
                    VStack(alignment: .leading, spacing: 24) {
                        titleBlock(item: item)
                        playRow(item: item)
                        progressStrip(item: item)
                        if let desc = item.media?.metadata?.description, !desc.isEmpty {
                            descriptionSection(text: desc)
                        }
                        if let chapters = item.media?.chapters, !chapters.isEmpty {
                            chaptersSection(chapters: chapters)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func ensureVM() async {
        if vm == nil {
            let m = BookDetailViewModel(client: deps.client, itemID: itemID)
            vm = m
            await m.load()
        }
    }

    // MARK: - Hero

    private func heroBackdrop(item: LibraryItemDTO) -> some View {
        let tint = AuthedAsyncImage.tintColor(for: item.id)
        return ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    tint.opacity(0.85),
                    tint.opacity(0.35),
                    TomePalette.bg1
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 380)
            VStack(spacing: 0) {
                Spacer().frame(height: 24)
                AuthedAsyncImage(itemID: item.id, placeholderHint: item.media?.metadata?.title)
                    .aspectRatio(2.0/3.0, contentMode: .fit)
                    .frame(width: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: .black.opacity(0.55), radius: 28, y: 18)
                Spacer().frame(height: 8)
            }
        }
    }

    private func titleBlock(item: LibraryItemDTO) -> some View {
        let m = item.media?.metadata
        return VStack(alignment: .center, spacing: 6) {
            Text(m?.title ?? "Untitled")
                .font(.tomeSerif(28, weight: .medium))
                .tracking(-0.3)
                .foregroundStyle(TomePalette.ink0)
                .multilineTextAlignment(.center)
            if let series = m?.series?.first {
                Text(series.name + (series.sequence.map { " · #\($0)" } ?? ""))
                    .font(.tomeSerif(13, weight: .regular))
                    .italic()
                    .foregroundStyle(TomePalette.gold)
            }
            authorRow(item: item)
            metaLine(item: item)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func authorRow(item: LibraryItemDTO) -> some View {
        if let authors = item.media?.metadata?.authors, !authors.isEmpty {
            HStack(spacing: 6) {
                ForEach(Array(authors.enumerated()), id: \.offset) { idx, author in
                    if idx > 0 {
                        Text("·").foregroundStyle(TomePalette.ink3)
                    }
                    NavigationLink(value: LibraryRoute.author(authorID: author.id, libraryID: item.libraryId)) {
                        Text(author.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(TomePalette.ink1)
                    }
                }
            }
        } else if let name = item.media?.metadata?.authorName, !name.isEmpty {
            Text(name)
                .font(.system(size: 14))
                .foregroundStyle(TomePalette.ink1)
        }
    }

    @ViewBuilder
    private func metaLine(item: LibraryItemDTO) -> some View {
        let m = item.media?.metadata
        let narrator = m?.displayNarrator ?? ""
        let duration = item.media?.duration ?? 0
        let chapters = item.media?.chapters?.count ?? 0
        let parts: [String] = [
            narrator.isEmpty ? "" : "Read by \(narrator)",
            duration > 0 ? formatDuration(duration) : "",
            chapters > 0 ? "\(chapters) chapters" : ""
        ].filter { !$0.isEmpty }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.system(size: 12))
                .foregroundStyle(TomePalette.ink2)
                .padding(.top, 6)
        }
    }

    private func playRow(item: LibraryItemDTO) -> some View {
        HStack(spacing: 12) {
            Button {
                deps.playerEngine.play(item: item)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text(playLabel(item: item))
                }
            }
            .buttonStyle(TomeEmberButtonStyle())
            .disabled(deps.playerEngine.state == .loading)

            Button {} label: {
                Image(systemName: "arrow.down.to.line")
            }
            .buttonStyle(TomeRoundButtonStyle(size: 52))
            .accessibilityLabel("Download")

            Button {} label: {
                Image(systemName: "bookmark")
            }
            .buttonStyle(TomeRoundButtonStyle(size: 52))
            .accessibilityLabel("Bookmark")
        }
    }

    private func playLabel(item: LibraryItemDTO) -> String {
        if item.userMediaProgress?.isFinished == true { return "Listen again" }
        if let p = item.userMediaProgress?.progress, p > 0 { return "Continue" }
        return "Start listening"
    }

    @ViewBuilder
    private func progressStrip(item: LibraryItemDTO) -> some View {
        if let p = item.userMediaProgress?.progress, p > 0, p < 1 {
            let remaining = max(0, (item.media?.duration ?? 0) * (1 - p))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(Int(p * 100))%")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(TomePalette.ink2)
                    Spacer()
                    Text("\(formatDuration(remaining)) left")
                        .font(.system(size: 11))
                        .foregroundStyle(TomePalette.ink2)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(TomePalette.ink0.opacity(0.10)).frame(height: 4)
                        Capsule().fill(TomePalette.ember).frame(width: geo.size.width * CGFloat(p), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private func descriptionSection(text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TomeEyebrow(text: "Description")
            Text(text)
                .font(.tomeSerif(16))
                .foregroundStyle(TomePalette.ink1)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func chaptersSection(chapters: [ChapterDTO]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TomeEyebrow(text: "Chapters")
                Spacer()
                Text("See all \(chapters.count) →")
                    .font(.system(size: 12))
                    .foregroundStyle(TomePalette.ember)
            }
            VStack(spacing: 0) {
                ForEach(Array(chapters.prefix(3).enumerated()), id: \.offset) { index, chapter in
                    HStack(spacing: 14) {
                        Text("\(index + 1)")
                            .font(.tomeSerif(13, weight: .regular))
                            .monospacedDigit()
                            .foregroundStyle(TomePalette.ink3)
                            .frame(width: 18)
                        Text(chapter.title ?? "Chapter \(index + 1)")
                            .font(.system(size: 14))
                            .foregroundStyle(TomePalette.ink0)
                            .lineLimit(1)
                        Spacer()
                        Text(formatDuration(chapter.end - chapter.start))
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(TomePalette.ink2)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    if index < min(2, chapters.count - 1) {
                        Rectangle().fill(TomePalette.hairline).frame(height: 0.5)
                    }
                }
            }
            .background(TomePalette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(TomePalette.hairline, lineWidth: 0.5)
            )
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%dh %02dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, sec) }
        return String(format: "%ds", sec)
    }
}

#if DEBUG
#Preview("Book detail") {
    NavigationStack {
        BookDetailView(previewVM: BookDetailViewModel(
            previewClient: ABSClient(tokenStore: TokenStore(keychain: KeychainStore(service: "preview"))),
            item: PreviewSupport.detailedItem
        ))
        .libraryNavigationDestinations()
    }
    .environment(PreviewSupport.dependencies())
}
#endif
