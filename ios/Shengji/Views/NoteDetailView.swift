import SwiftUI

struct NoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NotesStore
    @StateObject private var player = AudioPlayerController()

    let note: Note
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(GroupDefinition.definition(for: note.groupID).name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ShengjiTheme.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(ShengjiTheme.greenSoft)
                        .clipShape(Capsule())

                    Spacer()

                    Text(note.createdAt.detailMemoTime)
                        .font(.system(size: 11))
                        .foregroundStyle(ShengjiTheme.muted)
                }
                .padding(.bottom, 18)

                Text(note.title)
                    .font(.system(size: 30, weight: .semibold))
                    .tracking(-1.1)
                    .padding(.bottom, 9)

                Text("时长 \(note.duration.readableDuration)")
                    .font(.system(size: 12))
                    .foregroundStyle(ShengjiTheme.muted)
                    .padding(.bottom, 22)

                if player.duration > 0 {
                    Button {
                        player.toggle()
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(width: 42, height: 42)
                                .background(ShengjiTheme.ink)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 7) {
                                Text(player.isPlaying ? "正在播放" : "播放录音")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(ShengjiTheme.ink)

                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(ShengjiTheme.line)
                                        Capsule()
                                            .fill(ShengjiTheme.ink)
                                            .frame(width: geometry.size.width * player.progress)
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                        .padding(15)
                        .background(ShengjiTheme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(ShengjiTheme.line, lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                }

                Text("原始文字")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ShengjiTheme.muted)
                    .padding(.bottom, 10)

                Text(note.transcript)
                    .font(.system(size: 17))
                    .foregroundStyle(ShengjiTheme.ink)
                    .lineSpacing(8)
                    .textSelection(.enabled)

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Text("删除这条记录")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ShengjiTheme.red)
                .background(ShengjiTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(ShengjiTheme.line, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 36)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
        }
        .background(ShengjiTheme.canvas)
        .navigationTitle("记录")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("完成") { dismiss() }
                    .foregroundStyle(ShengjiTheme.ink)
            }
        }
        .task {
            player.load(url: store.audioURL(for: note))
        }
        .onDisappear {
            player.stop()
        }
        .confirmationDialog("删除这条记录？", isPresented: $showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                store.delete(note)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("原始录音和文字都会被删除。")
        }
    }
}
