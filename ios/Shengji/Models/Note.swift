import Foundation

struct Note: Identifiable, Codable, Hashable {
    let id: UUID
    var createdAt: Date
    var title: String
    var transcript: String
    var groupID: String
    var duration: TimeInterval
    var audioFileName: String?
    var status: NoteStatus
    var transcriptionEngine: String

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        title: String,
        transcript: String,
        groupID: String,
        duration: TimeInterval,
        audioFileName: String? = nil,
        status: NoteStatus = .ready,
        transcriptionEngine: String = "apple-speech"
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.transcript = transcript
        self.groupID = groupID
        self.duration = duration
        self.audioFileName = audioFileName
        self.status = status
        self.transcriptionEngine = transcriptionEngine
    }
}

enum NoteStatus: String, Codable {
    case ready
    case needsReview
}

struct GroupDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let order: Int
    let keywords: [String]

    static let defaults: [GroupDefinition] = [
        GroupDefinition(
            id: "shopping",
            name: "日常采购",
            order: 1,
            keywords: ["买", "采购", "超市", "购物", "牛奶", "鸡蛋", "牙膏", "洗衣液", "厨房纸", "菜", "水果", "药"]
        ),
        GroupDefinition(
            id: "home",
            name: "家里的事",
            order: 2,
            keywords: ["快递", "门锁", "修", "打扫", "洗", "充电", "水电", "家具", "物业", "搬", "收拾", "换"]
        ),
        GroupDefinition(
            id: "remember",
            name: "要记得",
            order: 3,
            keywords: ["记得", "提醒", "预约", "电话", "妈妈", "爸爸", "家人", "医生", "缴费", "交费", "别忘了", "要"]
        ),
        GroupDefinition(
            id: "ideas",
            name: "想法",
            order: 4,
            keywords: ["想法", "想到", "计划", "觉得", "点子", "以后", "可以", "如果", "灵感"]
        ),
        GroupDefinition(id: "other", name: "其他", order: 99, keywords: [])
    ]

    static func definition(for id: String) -> GroupDefinition {
        defaults.first(where: { $0.id == id }) ?? defaults[defaults.count - 1]
    }
}

struct NotesFile: Codable {
    var version: Int
    var notes: [Note]

    static let empty = NotesFile(version: 1, notes: [])
}
