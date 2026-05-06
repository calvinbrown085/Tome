import SwiftUI

/// Tome design tokens — "cozy & moody" palette: midnight + plum + ember on warm cream.
/// Derived from the design handoff (`tome.css` + `screens.jsx`/`player.jsx`).
enum TomePalette {
    // Surfaces
    static let bg0   = Color(hex: 0x0E0B13)  // deepest midnight
    static let bg1   = Color(hex: 0x14111A)  // base
    static let bg2   = Color(hex: 0x1C1825)  // card
    static let bg3   = Color(hex: 0x261F30)  // raised
    static let bg4   = Color(hex: 0x322A3E)  // hover
    static let plum  = Color(hex: 0x2A1E2E)
    static let plum2 = Color(hex: 0x3A2A3F)

    // Ink
    static let ink0 = Color(hex: 0xF4EAD5)   // cream — primary
    static let ink1 = Color(hex: 0xD8CDB6)   // secondary
    static let ink2 = Color(hex: 0xA59C87)   // tertiary
    static let ink3 = Color(hex: 0x6B6353)   // quaternary

    // Accents
    static let ember     = Color(hex: 0xD97757)  // warm primary
    static let emberDeep = Color(hex: 0xA8442A)  // oxblood
    static let gold      = Color(hex: 0xC9A25E)
    static let lavender  = Color(hex: 0x9A8CB0)

    // Effects
    static let hairline  = Color(hex: 0xF4EAD5).opacity(0.08)
    static let hairline2 = Color(hex: 0xF4EAD5).opacity(0.14)
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography

extension Font {
    /// Fraunces-equivalent — system serif (Iowan Old Style) is the next fallback in the design's CSS list.
    static func tomeSerif(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Tracked, uppercased eyebrow label — used above titles and on section dividers.
    static let tomeEyebrow = Font.system(size: 11, weight: .semibold).leading(.tight)
}

// MARK: - Background

/// Plain bg-1 surface — used inside most screens.
struct TomeBackground: View {
    var body: some View {
        TomePalette.bg1.ignoresSafeArea()
    }
}

/// Login / hero gradient — radial plum-to-midnight from the top.
struct TomeMoodyBackground: View {
    var body: some View {
        ZStack {
            RadialGradient(
                colors: [TomePalette.plum, TomePalette.bg1, TomePalette.bg0],
                center: .top,
                startRadius: 0,
                endRadius: 720
            )
            // Top-right ember "lamp" — radial warm glow.
            TomeLampGlow()
                .frame(width: 320, height: 320)
                .offset(x: 120, y: -80)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

/// Soft warm radial glow used on key surfaces (login lamp, library hero).
struct TomeLampGlow: View {
    var intensity: Double = 1.0
    var body: some View {
        RadialGradient(
            stops: [
                .init(color: TomePalette.ember.opacity(0.22 * intensity), location: 0),
                .init(color: TomePalette.ember.opacity(0.12 * intensity), location: 0.30),
                .init(color: TomePalette.ember.opacity(0.04 * intensity), location: 0.55),
                .init(color: .clear, location: 1)
            ],
            center: .center,
            startRadius: 0,
            endRadius: 220
        )
        .blur(radius: 20)
    }
}

// MARK: - Components

/// Eyebrow label — small caps, tracked, ink-2.
struct TomeEyebrow: View {
    let text: String
    var color: Color = TomePalette.ink2
    var body: some View {
        Text(text.uppercased())
            .font(.tomeEyebrow)
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

/// Section header — "Continue listening" + ember "See all".
struct TomeSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.tomeSerif(22, weight: .medium))
                .foregroundStyle(TomePalette.ink0)
                .tracking(-0.2)
            Spacer()
            trailing()
        }
    }
}

/// Field label — uppercase, tracked, used above text fields.
struct TomeFieldLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1)
            .foregroundStyle(TomePalette.ink2)
    }
}

/// Translucent rounded container used on cards and grouped lists.
struct TomeCard<Content: View>: View {
    var padding: CGFloat = 0
    @ViewBuilder var content: () -> Content
    var body: some View {
        content()
            .padding(padding)
            .background(TomePalette.bg2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(TomePalette.hairline, lineWidth: 0.5)
            )
    }
}

/// Filled ember CTA — primary action button (login, "Start listening", etc.).
struct TomeEmberButtonStyle: ButtonStyle {
    var prominent: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(TomePalette.bg0)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(configuration.isPressed ? TomePalette.emberDeep : TomePalette.ember)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    .blendMode(.plusLighter)
                    .mask(
                        LinearGradient(
                            colors: [.white, .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            )
            .shadow(color: TomePalette.ember.opacity(0.35), radius: 16, y: 8)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

/// Small circular "round button" used for back arrows, ellipsis, sleep/cast etc.
struct TomeRoundButtonStyle: ButtonStyle {
    var size: CGFloat = 40
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .foregroundStyle(TomePalette.ink0)
            .background(
                Circle().fill(TomePalette.ink0.opacity(configuration.isPressed ? 0.15 : 0.08))
            )
            .overlay(Circle().strokeBorder(TomePalette.hairline2, lineWidth: 0.5))
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - View modifiers

extension View {
    /// Apply Tome's ambient lamp glow at a specific corner.
    func tomeLampGlow(corner: Alignment = .topLeading, scale: CGFloat = 1) -> some View {
        background(alignment: corner) {
            TomeLampGlow()
                .frame(width: 360 * scale, height: 360 * scale)
                .offset(x: -80, y: -100)
                .allowsHitTesting(false)
        }
    }
}
