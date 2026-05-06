import SwiftUI

struct SpeedSheet: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss

    private let presets: [Float] = [0.8, 1.0, 1.25, 1.5, 1.75, 2.0]
    private let minRate: Float = 0.5
    private let maxRate: Float = 3.0

    var body: some View {
        let engine = deps.playerEngine
        let rate = engine.playbackRate
        VStack(spacing: 0) {
            Capsule()
                .fill(TomePalette.ink3)
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Text("Playback speed")
                .font(.tomeSerif(22, weight: .medium))
                .foregroundStyle(TomePalette.ink0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

            HStack(spacing: 20) {
                Spacer()
                stepperButton("−") {
                    let next = max(minRate, ((rate - 0.05) * 100).rounded() / 100)
                    engine.setPlaybackRate(next)
                    Haptics.selection()
                }
                dial(rate: rate)
                stepperButton("+") {
                    let next = min(maxRate, ((rate + 0.05) * 100).rounded() / 100)
                    engine.setPlaybackRate(next)
                    Haptics.selection()
                }
                Spacer()
            }
            .padding(.top, 16)
            .padding(.bottom, 24)

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { p in
                    presetButton(rate: p, current: rate)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(TomePalette.bg2)
    }

    private func dial(rate: Float) -> some View {
        let ratio = CGFloat((rate - minRate) / (maxRate - minRate))
        return ZStack {
            Circle()
                .stroke(TomePalette.ink0.opacity(0.1), lineWidth: 6)
            Circle()
                .trim(from: 0, to: ratio)
                .stroke(TomePalette.ember, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: -2) {
                Text(String(format: "%.2f", rate))
                    .font(.tomeSerif(44, weight: .medium))
                    .italic()
                    .foregroundStyle(TomePalette.ink0)
                    .monospacedDigit()
                    .tracking(-1)
                Text("SPEED")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(TomePalette.ink2)
            }
        }
        .frame(width: 160, height: 160)
    }

    private func stepperButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 22))
                .foregroundStyle(TomePalette.ink0)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.clear))
                .overlay(Circle().strokeBorder(TomePalette.hairline2, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func presetButton(rate: Float, current: Float) -> some View {
        let active = abs(current - rate) < 0.001
        return Button {
            deps.playerEngine.setPlaybackRate(rate)
            Haptics.selection()
        } label: {
            Text(formatted(rate))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(active ? TomePalette.ember : TomePalette.ink1)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(active ? TomePalette.ember.opacity(0.12) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(active ? TomePalette.ember : TomePalette.hairline2,
                                      lineWidth: active ? 1 : 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func formatted(_ r: Float) -> String {
        if r.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(r))×"
        }
        return String(format: "%.2g×", r)
    }
}
