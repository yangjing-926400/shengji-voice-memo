import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: NotesStore
    @State private var collapsedGroups = Set<String>()
    @State private var showingRecorder = false
    @State private var showingSearch = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ShengjiTheme.canvas.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        homeHeader
                            .padding(.bottom, 20)

                        if store.notes.isEmpty {
                            EmptyHomeView()
                        } else {
                            ForEach(store.groupedSections) { section in
                                groupSection(section)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 30)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    captureArea
                }

                if let message = store.lastAddedMessage {
                    ToastView(message: message)
                        .padding(.bottom, 112)
                }
            }
            .navigationDestination(for: Note.self) { note in
                NoteDetailView(note: note)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .fullScreenCover(isPresented: $showingRecorder) {
            RecordingView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showingSearch) {
            SearchView()
                .environmentObject(store)
        }
        .task(id: store.lastAddedMessage) {
            guard store.lastAddedMessage != nil else { return }
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            store.clearLastAddedMessage()
        }
    }

    private var homeHeader: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Date().formatted(.dateTime.month().day().weekday(.wide)))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ShengjiTheme.muted)

                Text("我的记录")
                    .font(.system(size: 32, weight: .semibold))
                    .tracking(-1.1)
                    .foregroundStyle(ShengjiTheme.ink)

                Text(store.notes.isEmpty ? "还没有记录" : "共 \(store.notes.count) 条 · 自动归纳为 \(store.activeGroupCount) 组")
                    .font(.system(size: 12))
                    .foregroundStyle(ShengjiTheme.muted)
            }

            Spacer()

            Button {
                showingSearch = true
            } label: {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(ShengjiTheme.ink)
                    .frame(width: 42, height: 42)
                    .background(ShengjiTheme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(ShengjiTheme.line, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .accessibilityLabel("语音搜索")
        }
    }

    private func groupSection(_ section: GroupSection) -> some View {
        let isCollapsed = collapsedGroups.contains(section.group.id)

        return VStack(spacing: 0) {
            Button {
                if isCollapsed {
                    collapsedGroups.remove(section.group.id)
                } else {
                    collapsedGroups.insert(section.group.id)
                }
            } label: {
                HStack(spacing: 9) {
                    Text(section.group.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(ShengjiTheme.ink)

                    Text("\(section.notes.count) 条")
                        .font(.system(size: 11))
                        .foregroundStyle(ShengjiTheme.muted)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ShengjiTheme.muted)
                        .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                }
                .frame(minHeight: 39)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                ForEach(section.notes) { note in
                    NavigationLink(value: note) {
                        NoteRowView(note: note)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(ShengjiTheme.line)
                            .frame(height: 1)
                    }
                }
            }
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(ShengjiTheme.line)
                .frame(height: 1)
        }
    }

    private var captureArea: some View {
        VStack(spacing: 9) {
            Text("点一下开始，再点一下保存")
                .font(.system(size: 11))
                .foregroundStyle(ShengjiTheme.muted)

            Button {
                showingRecorder = true
            } label: {
                Label("开始说话", systemImage: "mic.fill")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 22)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ShengjiTheme.line.opacity(0.65))
                .frame(height: 1)
        }
    }
}
