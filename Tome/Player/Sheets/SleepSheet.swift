import SwiftUI

struct SleepSheet: View {
    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss

    private let options: [(value: Int, label: String)] = [
        (5, "5 minutes"),
        (10, "10 minutes"),
        (15, "15 minutes"),
        (30, "30 minutes"),
        (45, "45 minutes"),
        (60, "1 hour")
    ]

    var body: some View {
        let engine = deps.playerEngine
        let activeMinutes = engine.sleepRemainingMinutes
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(TomePalette.ink3)
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Text("Sleep timer")
                .font(.tomeSerif(22, weight: .medium))
                .foregroundStyle(TomePalette.ink0)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.value) { idx, opt in
                    let active = activeMinutes == opt.value
                    Button {
                        engine.setSleepTimer(minutes: opt.value)
                        Haptics.selection()
                        dismiss()
                    } label: {
                        HStack {
                            Text(opt.label)
                                .font(.system(size: 16, weight: active ? .semibold : .regular))
                                .foregroundStyle(active ? TomePalette.ember : TomePalette.ink0)
                            Spacer()
                            if active {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(TomePalette.ember)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < options.count - 1 {
                        Rectangle()
                            .fill(TomePalette.hairline)
                            .frame(height: 0.5)
                            .padding(.leading, 24)
                    }
                }
            }

            if activeMinutes != nil {
                Button {
                    engine.setSleepTimer(minutes: nil)
                    Haptics.tap()
                    dismiss()
                } label: {
                    Text("Turn off sleep timer")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(TomePalette.ember)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(TomePalette.hairline2, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }

            Spacer(minLength: 24)
        }
        .background(TomePalette.bg2)
    }
}
