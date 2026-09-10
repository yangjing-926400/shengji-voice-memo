import SwiftUI

struct RecordingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NotesStore
    @StateObject private var recorder = AudioRecorder()

    @State private var didStart = false
    @State private var isProcessing = false
    @State private var statusText = "正在录音，停止后会自动保存和归纳。"
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ShengjiTheme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                recordHeader

                Spacer(minLength: 18)

                VStack(spacing: 0) {
                    Text(recorder.elapsed.clockText)
                        .font(.system(size: 54, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .tracking(-2)
                        .padding(.bottom, 30)

                    WaveformView(active: recorder.isRecording)
                        .padding(.bottom, 30)

                    Text(isProcessing ? "正在整理" : "你说吧")
                        .font(.system(size: 25, weight: .semibold))
                        .tracking(-0.8)

                    Text(statusText)
                        .font(.system(size: 13))
                        .foregroundStyle(ShengjiTheme.muted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: 290)
                        .padding(.top, 9)
                }

                Spacer(minLength: 24)

                Button {
                    Task { await finishRecording() }
                } label: {
                    if isProcessing {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("正在转成文字")
                        }
                    } else {
                        Label("停止并保存", systemImage: "stop.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isProcessing)

                Text("音频先保存在手机上，语音搜索记录不会成为新记录")
                    .font(.system(size: 11))
                    .foregroundStyle(ShengjiTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            Task { await startRecording() }
        }
        .onDisappear {
            if recorder.isRecording { recorder.cancel() }
        }
        .alert("无法录音", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("知道了") {
                errorMessage = nil
                dismiss()
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var recordHeader: some View {
        HStack {
            Button("取消") {
                recorder.cancel()
                dismiss()
            }
            .font(.system(size: 14))
            .foregroundStyle(ShengjiTheme.muted)

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(ShengjiTheme.red)
                    .frame(width: 7, height: 7)
                Text(isProcessing ? "正在处理" : "正在听")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ShengjiTheme.red)
            }

            Spacer()

            Text(" ")
                .font(.system(size: 14))
                .frame(width: 38)
        }
        .frame(minHeight: 50)
    }

    private func startRecording() async {
        do {
            try await recorder.start()
            statusText = "正在录音，停止后会自动保存和归纳。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finishRecording() async {
        guard recorder.isRecording, !isProcessing else { return }
        isProcessing = true

        do {
            let result = try recorder.stop()
            statusText = "正在把录音转成文字…"

            let transcript: String
            do {
                transcript = try await SpeechTranscriber.shared.transcribe(url: result.url)
            } catch {
                transcript = ""
            }

            statusText = "正在保存并整理…"
            _ = try store.addNote(
                transcript: transcript,
                duration: result.duration,
                temporaryAudioURL: result.url
            )
            dismiss()
        } catch {
            isProcessing = false
            errorMessage = error.localizedDescription
        }
    }
}
