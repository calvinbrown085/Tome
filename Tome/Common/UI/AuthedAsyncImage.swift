import SwiftUI
import UIKit
import os

struct AuthedAsyncImage: View {
    let itemID: String
    let placeholderHint: String?
    @Environment(AppDependencies.self) private var deps
    @State private var image: UIImage?
    @State private var failed: Bool = false

    init(itemID: String, placeholderHint: String? = nil) {
        self.itemID = itemID
        self.placeholderHint = placeholderHint
    }

    var body: some View {
        ZStack {
            placeholderTint
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fit)
                    .transition(.opacity)
            } else {
                placeholderGlyph
            }
        }
        .clipped()
        .animation(.easeOut(duration: 0.25), value: image)
        .task(id: itemID) { await load() }
    }

    @ViewBuilder
    private var placeholderGlyph: some View {
        if failed {
            Image(systemName: "book.closed")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.white.opacity(0.55))
        } else if let hint = placeholderHint?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !hint.isEmpty {
            Text(Self.initials(from: hint))
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundStyle(Color.white.opacity(0.45))
        } else {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color.white.opacity(0.45))
        }
    }

    private var placeholderTint: some View {
        let base = Self.tintColor(for: itemID)
        return LinearGradient(
            colors: [base, base.opacity(0.72)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func tintColor(for id: String) -> Color {
        let palette: [Color] = [
            Color(red: 0.34, green: 0.42, blue: 0.55),
            Color(red: 0.45, green: 0.30, blue: 0.50),
            Color(red: 0.25, green: 0.45, blue: 0.55),
            Color(red: 0.45, green: 0.40, blue: 0.30),
            Color(red: 0.35, green: 0.45, blue: 0.40),
            Color(red: 0.50, green: 0.35, blue: 0.40),
            Color(red: 0.30, green: 0.35, blue: 0.50),
            Color(red: 0.40, green: 0.45, blue: 0.30),
            Color(red: 0.45, green: 0.30, blue: 0.35),
            Color(red: 0.30, green: 0.40, blue: 0.45),
            Color(red: 0.40, green: 0.35, blue: 0.50),
            Color(red: 0.35, green: 0.40, blue: 0.45)
        ]
        // Stable additive hash so the color is consistent across launches.
        var h = 0
        for byte in id.utf8 { h = (h &* 31) &+ Int(byte) }
        return palette[abs(h) % palette.count]
    }

    private static func initials(from hint: String) -> String {
        let words = hint.split(separator: " ", omittingEmptySubsequences: true)
        return words.compactMap { $0.first }.prefix(2).map(String.init).joined().uppercased()
    }

    private func load() async {
        if let cached = CoverArtCache.shared.image(for: itemID) {
            image = cached
            return
        }
        image = nil
        failed = false
        do {
            let data = try await deps.client.coverArtData(itemID: itemID)
            if Task.isCancelled { return }
            if let ui = UIImage(data: data) {
                CoverArtCache.shared.store(ui, for: itemID)
                image = ui
            } else {
                failed = true
            }
        } catch is CancellationError {
            return
        } catch {
            failed = true
            Log.ui.error("Cover load failed for \(itemID, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }
}
