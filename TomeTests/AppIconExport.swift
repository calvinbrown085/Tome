#if DEBUG
import Foundation
import SwiftUI
import UIKit
import Testing
@testable import Tome

/// One-shot exporter for the app icon designs. Disabled by default so it
/// doesn't run on every test pass. To regenerate the PNGs: change
/// `.disabled` to enabled, run *only this suite*, then revert.
///
/// PNGs land directly in `Tome/Assets.xcassets/AppIcon.appiconset/`,
/// resolved from `#filePath` so it works regardless of which simulator
/// the test target is running on.
@Suite("App icon export", .disabled("Run manually to regenerate icon PNGs."))
@MainActor
struct AppIconExport {

    @Test("Export light 1024×1024 PNG")
    func exportLight() throws {
        try renderAndWrite(AppIconView(), filename: "Icon-1024.png")
    }

    @Test("Export dark 1024×1024 PNG")
    func exportDark() throws {
        try renderAndWrite(AppIconViewDark(), filename: "Icon-1024-Dark.png")
    }

    @Test("Export tinted 1024×1024 PNG")
    func exportTinted() throws {
        try renderAndWrite(AppIconViewTinted(), filename: "Icon-1024-Tinted.png")
    }

    private func renderAndWrite<V: View>(_ view: V, filename: String) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1024, height: 1024)

        let image = try #require(renderer.uiImage, "ImageRenderer produced no image")
        let data = try #require(image.pngData(), "Failed to encode PNG")

        let url = Self.iconSetDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        print("App icon written to: \(url.path) (\(data.count) bytes, \(image.size))")
    }

    /// Resolves `<repo>/Tome/Assets.xcassets/AppIcon.appiconset/` from the
    /// compile-time path of this source file (TomeTests/AppIconExport.swift
    /// → repo root → asset set).
    private static let iconSetDirectory: URL = {
        let here = URL(fileURLWithPath: #filePath)
        let repoRoot = here.deletingLastPathComponent()  // TomeTests/
                           .deletingLastPathComponent()  // <repo>/
        return repoRoot
            .appendingPathComponent("Tome")
            .appendingPathComponent("Assets.xcassets")
            .appendingPathComponent("AppIcon.appiconset")
    }()
}
#endif
