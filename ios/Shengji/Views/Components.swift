import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(ShengjiTheme.ink)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(ShengjiTheme.green)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ShengjiTheme.greenSoft)
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(Color(red: 203 / 255, green: 217 / 255, blue: 202 / 255), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .padding(.horizontal, 22)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

struct WaveformView: View {
    let active: Bool
    @State private var animated = false

    private let heights: [CGFloat] = [24, 46, 74, 38, 92, 54, 31, 82, 105, 61, 36, 87, 51, 29]

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
                Capsule()
                    .fill(ShengjiTheme.ink)
                    .frame(width: 5, height: height)
                    .scaleEffect(y: active && animated ? (index.isMultiple(of: 3) ? 0.42 : 1) : 0.34)
                    .opacity(active ? 0.92 : 0.35)
                    .animation(
                        .easeInOut(duration: 1.65)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.045),
                        value: animated
                    )
            }
        }
        .frame(height: 112)
        .onAppear { animated = true }
        .onChange(of: active) { newValue in animated = newValue }
    }
}

struct NoteRowView: View {
    let note: Note

    var body: some View {
        HStack(spacing: 12) {
            Text(note.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ShengjiTheme.ink)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(note.createdAt.relativeMemoTime)
                .font(.system(size: 11))
                .foregroundStyle(ShengjiTheme.muted)
        }
        .frame(minHeight: 53)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
    }
}

struct EmptyHomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(ShengjiTheme.ink)
                .frame(width: 72, height: 72)
                .background(ShengjiTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(ShengjiTheme.line, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            Text("想到什么，点一下说")
                .font(.system(size: 20, weight: .semibold))

            Text("记完就自动保存，同类的事情会放在一起。没有网络也能先录音。")
                .font(.system(size: 13))
                .foregroundStyle(ShengjiTheme.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
    }
}
