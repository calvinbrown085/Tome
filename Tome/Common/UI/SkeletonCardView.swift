import SwiftUI

/// Animated shimmer placeholder shaped like a book card. Used while shelves load.
struct SkeletonCardView: View {
    @State private var animate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            cover
            VStack(alignment: .leading, spacing: 4) {
                bar(width: 0.85, height: 12)
                bar(width: 0.55, height: 10)
            }
        }
        .onAppear { animate = true }
    }

    private var cover: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.secondary.opacity(0.18))
            .aspectRatio(2.0/3.0, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .overlay(shimmer.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous)))
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geo in
            Capsule()
                .fill(Color.secondary.opacity(0.20))
                .frame(width: geo.size.width * width, height: height)
                .overlay(shimmer.mask(Capsule()))
        }
        .frame(height: height)
    }

    private var shimmer: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0.0),
                .init(color: .white.opacity(0.35), location: 0.45),
                .init(color: .clear, location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .scaleEffect(x: 0.5, y: 1, anchor: .leading)
        .offset(x: animate ? 220 : -220)
        .animation(
            .linear(duration: 1.4).repeatForever(autoreverses: false),
            value: animate
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Skeleton card") {
    SkeletonCardView()
        .frame(width: 130)
        .padding()
}
#endif
