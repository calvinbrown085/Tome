#if DEBUG
import SwiftUI

/// 1024×1024 app icon — Tome's "Listening T" mark on a deep midnight gradient.
/// Drawn full-bleed; iOS applies its own rounded-corner mask to the icon at
/// install time. The export test (`AppIconExport.swift`) renders these views
/// to PNGs that get dropped into the AppIcon asset set.
struct AppIconView: View {
    var body: some View {
        ListeningTLogo(size: 1024, style: .color, glow: true, rounded: false)
            .frame(width: 1024, height: 1024)
    }
}

/// Dark-appearance variant: solid black background, no glow, so the icon
/// sits cleanly against dark home-screen wallpaper.
struct AppIconViewDark: View {
    var body: some View {
        ListeningTLogo(size: 1024, style: .dark, glow: false, rounded: false)
            .frame(width: 1024, height: 1024)
    }
}

/// Tinted-appearance variant: grayscale on black so iOS multiplies the
/// user's chosen tint color against the white luminance of the T and arcs.
struct AppIconViewTinted: View {
    var body: some View {
        ListeningTLogo(size: 1024, style: .tinted, glow: false, rounded: false)
            .frame(width: 1024, height: 1024)
    }
}

#Preview("App Icon — Light 256") {
    AppIconView()
        .scaleEffect(0.25)
        .frame(width: 256, height: 256)
        .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
}

#Preview("App Icon — Dark 256") {
    AppIconViewDark()
        .scaleEffect(0.25)
        .frame(width: 256, height: 256)
        .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
}

#Preview("App Icon — Tinted 256") {
    AppIconViewTinted()
        .scaleEffect(0.25)
        .frame(width: 256, height: 256)
        .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
}

#Preview("App Icon — Spotlight 60") {
    AppIconView()
        .scaleEffect(60.0 / 1024.0)
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
}
#endif
