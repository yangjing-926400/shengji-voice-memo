import Foundation

struct ClassificationResult {
    let groupID: String
    let confidence: Double
    let reason: String
}

enum NoteClassifier {
    private static let normalizationCharacters = CharacterSet.whitespacesAndNewlines
        .union(.punctuationCharacters)
        .union(.symbols)

    static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: normalizationCharacters)
            .joined()
    }

    static func createTitle(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["嗯", "那个", "就是", "我想说", "我说一下", "记一下", "帮我记一下"]
        for prefix in prefixes where cleaned.hasPrefix(prefix) {
            cleaned.removeFirst(prefix.count)
            cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "，, \n"))
            break
        }

        guard !cleaned.isEmpty else { return "新语音记录" }
        let firstSentence = cleaned
            .components(separatedBy: CharacterSet(charactersIn: "。！？!?；;\n"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? cleaned

        if firstSentence.count <= 20 { return firstSentence }
        return String(firstSentence.prefix(19)) + "…"
    }

    static func classify(
        text: String,
        notes: [Note],
        groups: [GroupDefinition] = GroupDefinition.defaults
    ) -> ClassificationResult {
        let normalized = normalize(text)
        guard normalized.count >= 2 else {
            return ClassificationResult(groupID: "other", confidence: 0.2, reason: "内容过短")
        }

        let scored = groups
            .filter { $0.id != "other" }
            .map { group in
                (group: group, score: keywordScore(normalized, keywords: group.keywords))
            }
            .sorted { $0.score > $1.score }

        let top = scored.first
        let second = scored.dropFirst().first
        let bestSimilar = notes
            .map { note in
                (note: note, score: similarity(normalized, normalize(note.transcript.isEmpty ? note.title : note.transcript)))
            }
            .max { $0.score < $1.score }

        if let bestSimilar, bestSimilar.score >= 0.34, bestSimilar.note.groupID != "other" {
            return ClassificationResult(
                groupID: bestSimilar.note.groupID,
                confidence: min(0.95, 0.55 + bestSimilar.score),
                reason: "和已有记录相似"
            )
        }

        if let top, top.score >= 2, second == nil || top.score - second!.score >= 0.5 {
            return ClassificationResult(
                groupID: top.group.id,
                confidence: min(0.96, 0.58 + top.score * 0.06),
                reason: "关键词匹配"
            )
        }

        if let bestSimilar, bestSimilar.score >= 0.24, bestSimilar.note.groupID != "other" {
            return ClassificationResult(
                groupID: bestSimilar.note.groupID,
                confidence: min(0.88, 0.48 + bestSimilar.score),
                reason: "可能和已有记录相似"
            )
        }

        return ClassificationResult(groupID: "other", confidence: 0.35, reason: "暂未确定类型")
    }

    static func groupMatchScore(group: GroupDefinition, text: String) -> Double {
        keywordScore(normalize(text), keywords: group.keywords)
    }

    static func similarity(_ left: String, _ right: String) -> Double {
        let first = bigrams(left)
        let second = bigrams(right)
        guard !first.isEmpty, !second.isEmpty else { return 0 }
        let intersection = first.intersection(second).count
        return Double(intersection * 2) / Double(first.count + second.count)
    }

    private static func keywordScore(_ text: String, keywords: [String]) -> Double {
        keywords.reduce(0) { partial, keyword in
            guard text.contains(normalize(keyword)) else { return partial }
            return partial + Double(max(1, min(3, keyword.count)))
        }
    }

    private static func bigrams(_ value: String) -> Set<String> {
        let text = normalize(value)
        guard text.count >= 2 else { return text.isEmpty ? [] : [text] }
        var result = Set<String>()
        let characters = Array(text)
        for index in 0..<(characters.count - 1) {
            result.insert(String(characters[index...index + 1]))
        }
        return result
    }
}

private extension String {
    subscript(range: ClosedRange<Int>) -> Substring {
        let lower = index(startIndex, offsetBy: range.lowerBound)
        let upper = index(startIndex, offsetBy: range.upperBound)
        return self[lower...upper]
    }
}
