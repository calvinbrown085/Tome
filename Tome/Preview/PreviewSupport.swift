#if DEBUG
import Foundation
import UIKit

enum PreviewSupport {

    // MARK: - Sample data

    static let libraries: [LibraryDTO] = [
        LibraryDTO(
            id: "lib_books", name: "Audiobooks", mediaType: "book",
            icon: "audiobookshelf", displayOrder: 1, folders: nil, provider: "audible"
        ),
        LibraryDTO(
            id: "lib_kids", name: "Kids' Books", mediaType: "book",
            icon: "audiobookshelf", displayOrder: 2, folders: nil, provider: nil
        )
    ]

    static let items: [LibraryItemDTO] = sampleTitles.enumerated().map { idx, t in
        LibraryItemDTO(
            id: "li_\(idx)",
            libraryId: "lib_books",
            folderId: "fol_1",
            mediaType: "book",
            isInvalid: false,
            isMissing: false,
            numFiles: 5,
            size: 200_000_000,
            addedAt: 1_700_000_000_000 + Int64(idx) * 1_000_000,
            updatedAt: 1_700_000_000_000,
            media: MediaDTO(
                libraryItemId: "li_\(idx)",
                metadata: BookMetadataDTO(
                    title: t.title,
                    titleIgnorePrefix: nil,
                    subtitle: nil,
                    authors: nil,
                    authorName: t.author,
                    authorNameLF: nil,
                    narrators: nil,
                    narratorName: t.narrator,
                    series: nil,
                    genres: ["Sci-Fi"],
                    publishedYear: "2021",
                    publishedDate: nil,
                    publisher: "Audible",
                    description: "A sample book.",
                    isbn: nil,
                    asin: nil,
                    language: "english",
                    explicit: false
                ),
                coverPath: nil,
                tags: nil,
                audioFiles: nil,
                chapters: nil,
                duration: 36000.0,
                size: 200_000_000,
                numTracks: 5,
                numAudioFiles: 5,
                numChapters: 12
            ),
            userMediaProgress: t.progress
        )
    }

    static let detailedItem: LibraryItemDTO = {
        let chapters: [ChapterDTO] = (0..<10).map { i in
            ChapterDTO(id: i, start: Double(i) * 1800.0, end: Double(i + 1) * 1800.0, title: "Chapter \(i + 1)")
        }
        return LibraryItemDTO(
            id: "li_detail",
            libraryId: "lib_books",
            folderId: "fol_1",
            mediaType: "book",
            isInvalid: false,
            isMissing: false,
            numFiles: 5,
            size: 350_000_000,
            addedAt: 1_700_000_000_000,
            updatedAt: 1_700_000_000_000,
            media: MediaDTO(
                libraryItemId: "li_detail",
                metadata: BookMetadataDTO(
                    title: "Project Hail Mary",
                    titleIgnorePrefix: nil,
                    subtitle: "A Lone Astronaut, an Impossible Mission",
                    authors: [AuthorMinimalDTO(id: "aut_weir", name: "Andy Weir")],
                    authorName: "Andy Weir",
                    authorNameLF: nil,
                    narrators: ["Ray Porter"],
                    narratorName: "Ray Porter",
                    series: [SeriesSequenceDTO(id: "ser_hail", name: "Hail Mary", sequence: "1")],
                    genres: ["Sci-Fi"],
                    publishedYear: "2021",
                    publishedDate: nil,
                    publisher: "Audible Studios",
                    description: "Ryland Grace is the sole survivor on a desperate, last-chance mission—and if he fails, humanity and the Earth itself will perish.\n\nA lone astronaut. An impossible mission. An ally he never imagined he'd have.",
                    isbn: nil,
                    asin: "B08G9PRS1K",
                    language: "english",
                    explicit: false
                ),
                coverPath: nil,
                tags: ["favorites"],
                audioFiles: nil,
                chapters: chapters,
                duration: 18000.0,
                size: 350_000_000,
                numTracks: 5,
                numAudioFiles: 5,
                numChapters: chapters.count
            ),
            userMediaProgress: progress(0.45)
        )
    }()

    static let sampleAuthor: AuthorDTO = AuthorDTO(
        id: "aut_weir",
        libraryId: "lib_books",
        name: "Andy Weir",
        description: "American novelist, best known for The Martian, Artemis, and Project Hail Mary. His work blends hard science with humor.",
        imagePath: nil,
        addedAt: 1_700_000_000_000,
        updatedAt: 1_700_000_000_000,
        numBooks: 3,
        libraryItems: Array(items.prefix(3))
    )

    private static let sampleTitles: [(title: String, author: String, narrator: String, progress: MediaProgressDTO?)] = [
        ("Project Hail Mary", "Andy Weir", "Ray Porter", progress(0.45)),
        ("The Three-Body Problem", "Liu Cixin", "Luke Daniels", progress(0.0)),
        ("Children of Time", "Adrian Tchaikovsky", "Mel Hudson", finished()),
        ("Recursion", "Blake Crouch", "Jon Lindstrom", progress(0.12)),
        ("The Martian", "Andy Weir", "R. C. Bray", finished()),
        ("Snow Crash", "Neal Stephenson", "Jonathan Davis", progress(0.0)),
        ("Hyperion", "Dan Simmons", "Marc Vietor", progress(0.78)),
        ("Anathem", "Neal Stephenson", "Oliver Wyman", progress(0.0)),
        ("Leviathan Wakes", "James S.A. Corey", "Jefferson Mays", progress(0.33)),
        ("Old Man's War", "John Scalzi", "William Dufris", finished()),
        ("Permutation City", "Greg Egan", "Adam Epstein", progress(0.0)),
        ("Diaspora", "Greg Egan", "Adam Epstein", progress(0.0))
    ]

    private static func progress(_ p: Double) -> MediaProgressDTO {
        MediaProgressDTO(
            id: nil, libraryItemId: nil, episodeId: nil,
            duration: 36000.0, progress: p, currentTime: 36000.0 * p,
            isFinished: false, hideFromContinueListening: nil,
            lastUpdate: nil, startedAt: nil, finishedAt: nil
        )
    }

    private static func finished() -> MediaProgressDTO {
        MediaProgressDTO(
            id: nil, libraryItemId: nil, episodeId: nil,
            duration: 36000.0, progress: 1.0, currentTime: 36000.0,
            isFinished: true, hideFromContinueListening: nil,
            lastUpdate: nil, startedAt: nil, finishedAt: nil
        )
    }

    // MARK: - Factories

    @MainActor
    static func dependencies() -> AppDependencies {
        let deps = AppDependencies()
        deps.librarySelection.populateForPreview(libraries: libraries, selected: "lib_books")
        seedColoredCovers(for: items)
        return deps
    }

    @MainActor
    static func emptyDependencies() -> AppDependencies {
        let deps = AppDependencies()
        deps.librarySelection.populateForPreview(libraries: libraries, selected: "lib_books")
        return deps
    }

    @MainActor
    static func listViewModel(items: [LibraryItemDTO] = PreviewSupport.items) -> LibraryListViewModel {
        let keychain = KeychainStore(service: "BrownGames.Tome.Preview")
        let tokenStore = TokenStore(keychain: keychain)
        let client = ABSClient(tokenStore: tokenStore)
        return LibraryListViewModel(previewClient: client, libraryID: "lib_books", items: items)
    }

    @MainActor
    static func homeViewModel(
        inProgress: [LibraryItemDTO]? = nil,
        recentlyAdded: [LibraryItemDTO]? = nil
    ) -> LibraryHomeViewModel {
        let keychain = KeychainStore(service: "BrownGames.Tome.Preview")
        let tokenStore = TokenStore(keychain: keychain)
        let client = ABSClient(tokenStore: tokenStore)
        let inProg = inProgress ?? items.filter { ($0.userMediaProgress?.progress ?? 0) > 0 && ($0.userMediaProgress?.isFinished ?? false) == false }
        let recent = recentlyAdded ?? Array(items.prefix(8))
        return LibraryHomeViewModel(
            previewClient: client,
            libraryID: "lib_books",
            inProgress: inProg,
            recentlyAdded: recent
        )
    }

    /// Pre-populates the cover-art cache with synthetic colored placeholders so previews
    /// don't show the spinning network state. A few entries use non-2:3 shapes so the
    /// ambient-backdrop layout in `AuthedAsyncImage` is exercised in canvas previews.
    static func seedColoredCovers(for items: [LibraryItemDTO]) {
        let palette: [UIColor] = [
            .systemIndigo, .systemTeal, .systemPurple, .systemBlue,
            .systemPink, .systemOrange, .systemGreen, .systemBrown,
            .systemRed, .systemMint, .systemCyan, .systemYellow
        ]
        for (idx, item) in items.enumerated() {
            let color = palette[idx % palette.count]
            let label = String((item.media?.metadata?.title ?? "?").prefix(1))
            let size: CGSize
            let drawExclusiveStripe: Bool
            switch idx {
            case 0:
                // Square cover with a fake "EXCLUSIVE" sleeve — the Audible case.
                size = CGSize(width: 360, height: 360)
                drawExclusiveStripe = true
            case 1:
                // Wide / landscape — older catalog edge case.
                size = CGSize(width: 360, height: 270)
                drawExclusiveStripe = false
            default:
                size = CGSize(width: 240, height: 360)
                drawExclusiveStripe = false
            }
            let image = render(color: color, label: label, size: size, exclusiveStripe: drawExclusiveStripe)
            CoverArtCache.shared.store(image, for: item.id)
        }
    }

    private static func render(color: UIColor, label: String, size: CGSize, exclusiveStripe: Bool) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: min(size.width, size.height) * 0.5, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            let str = NSAttributedString(string: label.uppercased(), attributes: titleAttrs)
            let bounds = str.boundingRect(with: size, options: .usesLineFragmentOrigin, context: nil)
            let origin = CGPoint(x: (size.width - bounds.width) / 2, y: (size.height - bounds.height) / 2)
            str.draw(at: origin)

            if exclusiveStripe {
                let stripeWidth: CGFloat = 36
                let stripeRect = CGRect(x: size.width - stripeWidth, y: 0, width: stripeWidth, height: size.height)
                UIColor(red: 0.95, green: 0.55, blue: 0.10, alpha: 1.0).setFill()
                ctx.fill(stripeRect)

                ctx.cgContext.saveGState()
                ctx.cgContext.translateBy(x: size.width - stripeWidth / 2, y: size.height / 2)
                ctx.cgContext.rotate(by: -.pi / 2)
                let stripeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .heavy),
                    .foregroundColor: UIColor.white,
                    .kern: 3
                ]
                let stripe = NSAttributedString(string: "EXCLUSIVE", attributes: stripeAttrs)
                let stripeBounds = stripe.boundingRect(with: size, options: .usesLineFragmentOrigin, context: nil)
                stripe.draw(at: CGPoint(x: -stripeBounds.width / 2, y: -stripeBounds.height / 2))
                ctx.cgContext.restoreGState()
            }
        }
    }
}
#endif
