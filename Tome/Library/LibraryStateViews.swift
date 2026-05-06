import SwiftUI

struct LibraryErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundStyle(TomePalette.ember)
            Text("Something went wrong")
                .font(.tomeSerif(20, weight: .medium))
                .foregroundStyle(TomePalette.ink0)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(TomePalette.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again", action: retry)
                .buttonStyle(TomeEmberButtonStyle())
                .frame(maxWidth: 220)
                .padding(.top, 4)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
}

struct LibraryEmptyView: View {
    let filter: LibraryFilter

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "books.vertical")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(TomePalette.ink2)
            Text(title)
                .font(.tomeSerif(20, weight: .medium))
                .foregroundStyle(TomePalette.ink0)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(TomePalette.ink2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private var title: String {
        switch filter {
        case .all: return "No books in this library"
        case .inProgress: return "No books in progress"
        case .notFinished: return "Nothing unfinished"
        case .finished: return "No finished books yet"
        }
    }

    private var subtitle: String {
        switch filter {
        case .all: return "Add audiobooks to your AudiobookShelf server to see them here."
        case .inProgress: return "Start a book to see it here."
        case .notFinished: return "All caught up — nothing pending."
        case .finished: return "Books you finish will show up here."
        }
    }
}

#if DEBUG
#Preview("Error state") {
    ZStack {
        TomePalette.bg1.ignoresSafeArea()
        LibraryErrorView(message: "Couldn't reach the server.") { }
    }
}

#Preview("Empty — All") {
    ZStack {
        TomePalette.bg1.ignoresSafeArea()
        LibraryEmptyView(filter: .all)
    }
}

#Preview("Empty — In Progress") {
    ZStack {
        TomePalette.bg1.ignoresSafeArea()
        LibraryEmptyView(filter: .inProgress)
    }
}
#endif
