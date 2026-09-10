import SwiftUI

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: NotesStore
    @StateObject private var recorder = AudioRecorder()

    @State private var query = ""
    @State private var result = SearchResult(answer: "", matches: [])
    @State private var statusText = "点麦克风直接问，也可以输入文字搜索"
    @State private var isVoiceSearching = false
    @State private var isFinishingVoice = false
    @State private var voiceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        searchField
                            .padding(.bottom, 15)

                        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            examples
                        } else {
                            answerCard
                            resultSections
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                }

                VStack(spacing: 9) {
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(ShengjiTheme.muted)
                        .multilineTextAlignment(.center)

                    Button {
                        Task { await toggleVoiceSearch() }
                    } label: {
                        Label(isVoiceSearching ? "点一下结束" : "问一句", systemImage: isVoiceSearching ? "stop.fill" : "mic.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isFinishingVoice)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle().fill(ShengjiTheme.line.opacity(0.65)).frame(height: 1)
                }
            }
            .background(ShengjiTheme.canvas)
            .navigationTitle("找记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .foregroundStyle(ShengjiTheme.ink)
                }
            }
            .navigationDestination(for: Note.self) { note in
                NoteDetailView(note: note)
            }
        }
        .onChange(of: query) { _ in performSearch() }
        .onDisappear {
            voiceTask?.cancel()
            if recorder.isRecording { recorder.cancel() }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(ShengjiTheme.muted)

            TextField("问一句，例如：最近要买什么？", text: $query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16))

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ShengjiTheme.muted)
                }
            }
        }
        .frame(minHeight: 52)
        .padding(.horizontal, 14)
        .background(ShengjiTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(ShengjiTheme.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var examples: some View {
        VStack(spacing: 12) {
            Text("试着问：")
                .font(.system(size: 12))
                .foregroundStyle(ShengjiTheme.muted)

            ForEach([
                "最近要买什么？",
                "妈妈相关的记录有哪些？",
                "今天记录了什么？"
            ], id: \.self) { example in
                Button(example) {
                    query = example
                }
                .font(.system(size: 12))
                .foregroundStyle(ShengjiTheme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(ShengjiTheme.surface)
                .overlay {
                    Capsule().stroke(ShengjiTheme.line, lineWidth: 1)
                }
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 44)
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                Text(result.matches.isEmpty ? "没有找到" : "找到 \(result.matches.count) 条相关记录")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white.opacity(0.66))

            Text(result.answer)
                .font(.system(size: 14))
                .lineSpacing(6)
                .foregroundStyle(Color.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(ShengjiTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .padding(.bottom, 18)
    }

    private var resultSections: some View {
        let sections = Dictionary(grouping: result.matches, by: \.groupID)
            .map { GroupSection(group: GroupDefinition.definition(for: $0.key), notes: $0.value, latestDate: $0.value.first?.createdAt ?? .distantPast) }
            .sorted { $0.group.order < $1.group.order }

        return VStack(spacing: 16) {
            ForEach(sections) { section in
                VStack(spacing: 0) {
                    HStack {
                        Text(section.group.name)
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text("\(section.notes.count) 条")
                            .font(.system(size: 11))
                            .foregroundStyle(ShengjiTheme.muted)
                    }
                    .frame(minHeight: 36)

                    ForEach(section.notes) { note in
                        NavigationLink(value: note) {
                            NoteRowView(note: note)
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .top) {
                            Rectangle().fill(ShengjiTheme.line).frame(height: 1)
                        }
                    }
                }
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(ShengjiTheme.line).frame(height: 1)
                }
            }
        }
    }

    private func performSearch() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            result = SearchResult(answer: "", matches: [])
            return
        }
        result = SearchEngine.search(query: query, notes: store.notes)
    }

    private func toggleVoiceSearch() async {
        if recorder.isRecording {
            await finishVoiceSearch()
            return
        }

        do {
            try await recorder.start()
            isVoiceSearching = true
            isFinishingVoice = false
            statusText = "正在听，点一下结束；6 秒后会自动结束"

            voiceTask?.cancel()
            voiceTask = Task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard !Task.isCancelled else { return }
                await finishVoiceSearch()
            }
        } catch {
            statusText = error.localizedDescription
        }
    }

    @MainActor
    private func finishVoiceSearch() async {
        guard recorder.isRecording, !isFinishingVoice else { return }
        isFinishingVoice = true
        voiceTask?.cancel()

        do {
            let recording = try recorder.stop()
            isVoiceSearching = false
            statusText = "正在转写你的问题…"

            let text = try await SpeechTranscriber.shared.transcribe(url: recording.url)
            try? FileManager.default.removeItem(at: recording.url)
            query = text
            statusText = "搜索说的话不会保存成新记录"
        } catch {
            statusText = error.localizedDescription
            isVoiceSearching = false
        }

        isFinishingVoice = false
    }
}
