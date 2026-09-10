import Foundation

struct SearchResult {
    let answer: String
    let matches: [Note]
}

enum SearchEngine {
    private static let stopWords = [
        "最近", "上周", "这周", "本周", "今天", "昨天", "关于", "相关", "记录", "哪些", "什么",
        "说了", "说过", "有没有", "我", "的", "了", "吗", "呀", "请", "找一下", "帮我", "查一下"
    ]

    static func search(
        query: String,
        notes: [Note],
        groups: [GroupDefinition] = GroupDefinition.defaults
    ) -> SearchResult {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanQuery.isEmpty else { return SearchResult(answer: "", matches: []) }

        let dateRange = dateRange(for: cleanQuery)
        let requestedGroup = groups
            .filter { $0.id != "other" }
            .map { (group: $0, score: NoteClassifier.groupMatchScore(group: $0, text: cleanQuery)) }
            .max { $0.score < $1.score }

        let queryText = removeStopWords(cleanQuery)
        let scored = notes.compactMap { note -> (note: Note, score: Double)? in
            var score = 0.0
            let noteTime = note.createdAt.timeIntervalSince1970

            if let dateRange, !(noteTime >= dateRange.from && noteTime < dateRange.to) {
                return nil
            }

            if let requestedGroup, requestedGroup.score > 0, note.groupID == requestedGroup.group.id {
                score += 8
            }

            let noteText = NoteClassifier.normalize("\(note.title) \(note.transcript)")
            if queryText.count >= 2, noteText.contains(queryText) { score += 7 }
            if queryText.count >= 2 { score += NoteClassifier.similarity(queryText, noteText) * 5 }
            if dateRange != nil { score += 1.5 }

            return score > 0 ? (note, score) : nil
        }
        .sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.note.createdAt > $1.note.createdAt
        }
        .map(\.note)

        let hasRequestedGroup = (requestedGroup?.score ?? 0) > 0
        let matches: [Note]
        if scored.isEmpty, hasRequestedGroup, let groupID = requestedGroup?.group.id {
            matches = notes.filter { $0.groupID == groupID }.sorted { $0.createdAt > $1.createdAt }
        } else {
            matches = scored
        }

        return SearchResult(
            answer: answerText(query: cleanQuery, matches: matches, requestedGroup: requestedGroup, groups: groups),
            matches: matches
        )
    }

    private static func answerText(
        query: String,
        matches: [Note],
        requestedGroup: (group: GroupDefinition, score: Double)?,
        groups: [GroupDefinition]
    ) -> String {
        guard !matches.isEmpty else {
            return "没有找到相关记录。可以换一种问法，或者先记录一条。"
        }

        let titles = matches.prefix(4).map(\.title).joined(separator: "、")

        if let requestedGroup, requestedGroup.score > 0, matches.first?.groupID == requestedGroup.group.id {
            return "\(requestedGroup.group.name)里有 \(matches.count) 条：\(titles)。"
        }
        if query.contains("今天") { return "今天记录了：\(titles)。" }
        if query.contains("昨天") { return "昨天记录了：\(titles)。" }
        if query.contains("上周") { return "上周共找到 \(matches.count) 条相关记录：\(titles)。" }
        return "和你问的内容比较接近的是：\(titles)。"
    }

    private static func removeStopWords(_ value: String) -> String {
        var output = NoteClassifier.normalize(value)
        for word in stopWords {
            output = output.replacingOccurrences(of: NoteClassifier.normalize(word), with: "")
        }
        return output
    }

    private static func dateRange(for query: String) -> (from: TimeInterval, to: TimeInterval)? {
        let calendar = Calendar.current
        let now = Date()
        guard let startOfToday = calendar.dateInterval(of: .day, for: now)?.start else { return nil }

        if query.contains("今天") {
            return (startOfToday.timeIntervalSince1970, startOfToday.addingTimeInterval(86_400).timeIntervalSince1970)
        }
        if query.contains("昨天") {
            return (startOfToday.addingTimeInterval(-86_400).timeIntervalSince1970, startOfToday.timeIntervalSince1970)
        }
        if query.contains("上周"), let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) {
            return (
                thisWeek.start.addingTimeInterval(-7 * 86_400).timeIntervalSince1970,
                thisWeek.start.timeIntervalSince1970
            )
        }
        if query.contains("这周") || query.contains("本周"), let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now) {
            return (
                thisWeek.start.timeIntervalSince1970,
                thisWeek.end.timeIntervalSince1970
            )
        }
        return nil
    }
}
