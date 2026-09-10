import Foundation

@MainActor
final class NotesStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var lastAddedMessage: String?

    private let fileManager = FileManager.default
    private let baseDirectory: URL
    private let audioDirectory: URL
    private let notesFileURL: URL

    init() {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        baseDirectory = applicationSupport.appendingPathComponent("Shengji", isDirectory: true)
        audioDirectory = baseDirectory.appendingPathComponent("Audio", isDirectory: true)
        notesFileURL = baseDirectory.appendingPathComponent("notes.json")

        do {
            try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
            try load()
        } catch {
            notes = []
        }
    }

    var groupedSections: [GroupSection] {
        GroupDefinition.defaults
            .map { group in
                let matching = notes
                    .filter { $0.groupID == group.id }
                    .sorted { $0.createdAt > $1.createdAt }
                return GroupSection(
                    group: group,
                    notes: matching,
                    latestDate: matching.first?.createdAt ?? .distantPast
                )
            }
            .filter { !$0.notes.isEmpty }
            .sorted {
                if $0.group.id == "other" { return false }
                if $1.group.id == "other" { return true }
                if $0.latestDate != $1.latestDate { return $0.latestDate > $1.latestDate }
                return $0.group.order < $1.group.order
            }
    }

    var activeGroupCount: Int {
        groupedSections.count
    }

    func addNote(transcript: String, duration: TimeInterval, temporaryAudioURL: URL) throws -> Note {
        let id = UUID()
        let noteID = id.uuidString
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasTranscript = !cleanTranscript.isEmpty
        let classification = hasTranscript
            ? NoteClassifier.classify(text: cleanTranscript, notes: notes)
            : ClassificationResult(groupID: "other", confidence: 0.2, reason: "等待转写")

        let audioFileName = "\(noteID).m4a"
        let destination = audioDirectory.appendingPathComponent(audioFileName)

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporaryAudioURL, to: destination)

        let note = Note(
            id: id,
            title: hasTranscript ? NoteClassifier.createTitle(from: cleanTranscript) : "新语音记录",
            transcript: hasTranscript ? cleanTranscript : "音频已保存，自动转写没有成功。",
            groupID: classification.groupID,
            duration: duration,
            audioFileName: audioFileName,
            status: hasTranscript ? .ready : .needsReview,
            transcriptionEngine: hasTranscript ? "apple-speech" : "unavailable"
        )

        notes.insert(note, at: 0)
        try save()
        lastAddedMessage = "已保存，并归入“\(GroupDefinition.definition(for: note.groupID).name)”"
        return note
    }

    func clearLastAddedMessage() {
        lastAddedMessage = nil
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        if let fileName = note.audioFileName {
            try? fileManager.removeItem(at: audioDirectory.appendingPathComponent(fileName))
        }
        try? save()
    }

    func audioURL(for note: Note) -> URL? {
        guard let fileName = note.audioFileName else { return nil }
        let url = audioDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    private func load() throws {
        guard fileManager.fileExists(atPath: notesFileURL.path) else {
            notes = []
            return
        }
        let data = try Data(contentsOf: notesFileURL)
        let file = try JSONDecoder().decode(NotesFile.self, from: data)
        notes = file.notes.sorted { $0.createdAt > $1.createdAt }
    }

    private func save() throws {
        let file = NotesFile(version: 1, notes: notes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(file)
        try data.write(to: notesFileURL, options: .atomic)
    }
}

struct GroupSection: Identifiable {
    let group: GroupDefinition
    let notes: [Note]
    let latestDate: Date

    var id: String { group.id }
}
