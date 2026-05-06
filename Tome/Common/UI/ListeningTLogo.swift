import SwiftUI

/// Tome's "Listening T" mark — serif T as both letterform and tuning fork,
/// with three ember sound arcs radiating to the right. Designed in a
/// 180×180 reference space and scaled to any size.
struct ListeningTLogo: View {
    /// Color treatment. `.color` is the everyday brand mark; `.dark` and
    /// `.tinted` exist for the iOS 18 app-icon dark/tinted appearance slots.
    enum Style {
        case color   // cream T + ember arcs on midnight gradient
        case dark    // cream T + ember arcs on solid black, no glow
        case tinted  // white T + white arcs on black — iOS multiplies the user's tint
    }

    var size: CGFloat = 180
    var style: Style = .color
    /// When true, draws a soft ember glow behind the arcs (used at larger sizes).
    /// Ignored for `.dark` and `.tinted` styles, which never glow.
    var glow: Bool = true
    /// When true, applies the iOS-style rounded-rect mask. Disable for the
    /// 1024 app-icon export — iOS provides its own corner mask.
    var rounded: Bool = true

    var body: some View {
        let s = size / 180

        ZStack {
            background
            if glow && style == .color { embers }
            letterT(scale: s)
            arcs(scale: s)
        }
        .frame(width: size, height: size)
        .clipShape(rounded
                   ? AnyShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                   : AnyShape(Rectangle()))
    }

    // MARK: - Layers

    @ViewBuilder
    private var background: some View {
        switch style {
        case .color:
            LinearGradient(
                colors: [Self.bgTop, Self.bgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .dark, .tinted:
            Color.black
        }
    }

    private var embers: some View {
        Circle()
            .fill(Self.ember.opacity(0.12))
            .frame(width: size * (100.0 / 180), height: size * (100.0 / 180))
            .position(x: size * (120.0 / 180), y: size * (90.0 / 180))
            .blur(radius: size * (10.0 / 180))
    }

    private func letterT(scale s: CGFloat) -> some View {
        Text("T")
            .font(.system(size: 135 * s, weight: .medium, design: .serif))
            .foregroundStyle(letterColor)
            // The SVG anchors at x=90, baseline y=125. SwiftUI's .position
            // targets the Text frame's center; with system serif metrics
            // (≈73% ascender / 19% descender) the frame center sits roughly
            // 36% of the font size above the baseline, so y ≈ 89.
            .position(x: 90 * s, y: 89 * s)
    }

    private func arcs(scale s: CGFloat) -> some View {
        let c = arcColor
        return ZStack {
            arcPath(from: CGPoint(x: 130, y: 75),
                    to: CGPoint(x: 130, y: 105),
                    control: CGPoint(x: 145, y: 90),
                    scale: s)
                .stroke(c,
                        style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))

            arcPath(from: CGPoint(x: 140, y: 65),
                    to: CGPoint(x: 140, y: 115),
                    control: CGPoint(x: 160, y: 90),
                    scale: s)
                .stroke(c.opacity(0.7),
                        style: StrokeStyle(lineWidth: 3 * s, lineCap: .round))

            arcPath(from: CGPoint(x: 150, y: 55),
                    to: CGPoint(x: 150, y: 125),
                    control: CGPoint(x: 175, y: 90),
                    scale: s)
                .stroke(c.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2.5 * s, lineCap: .round))
        }
    }

    private func arcPath(from a: CGPoint, to b: CGPoint, control c: CGPoint, scale s: CGFloat) -> Path {
        Path { p in
            p.move(to: CGPoint(x: a.x * s, y: a.y * s))
            p.addQuadCurve(to: CGPoint(x: b.x * s, y: b.y * s),
                           control: CGPoint(x: c.x * s, y: c.y * s))
        }
    }

    // MARK: - Style → palette

    private var letterColor: Color {
        switch style {
        case .color, .dark: return Self.cream
        case .tinted:       return .white
        }
    }

    private var arcColor: Color {
        switch style {
        case .color, .dark: return Self.ember
        case .tinted:       return .white
        }
    }

    // MARK: - Palette (Tome cozy/moody tokens)

    private static let bgTop    = Color(red: 0x1c / 255.0, green: 0x18 / 255.0, blue: 0x25 / 255.0)
    private static let bgBottom = Color(red: 0x0e / 255.0, green: 0x0b / 255.0, blue: 0x13 / 255.0)
    private static let cream    = Color(red: 0xf4 / 255.0, green: 0xea / 255.0, blue: 0xd5 / 255.0)
    private static let ember    = Color(red: 0xd9 / 255.0, green: 0x77 / 255.0, blue: 0x57 / 255.0)
}

#if DEBUG
#Preview("Listening T — 180") {
    ListeningTLogo(size: 180)
        .padding()
        .background(Color.black)
}

#Preview("Listening T — 110 / 60") {
    HStack(spacing: 24) {
        ListeningTLogo(size: 110)
        ListeningTLogo(size: 60, glow: false)
    }
    .padding()
    .background(Color.black)
}
#endif
