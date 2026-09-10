import SwiftUI

enum ShengjiTheme {
    static let canvas = Color(red: 247 / 255, green: 246 / 255, blue: 243 / 255)
    static let surface = Color.white
    static let surfaceSoft = Color(red: 239 / 255, green: 238 / 255, blue: 233 / 255)
    static let ink = Color(red: 23 / 255, green: 24 / 255, blue: 22 / 255)
    static let muted = Color(red: 125 / 255, green: 126 / 255, blue: 120 / 255)
    static let line = Color(red: 229 / 255, green: 227 / 255, blue: 221 / 255)
    static let green = Color(red: 63 / 255, green: 104 / 255, blue: 67 / 255)
    static let greenSoft = Color(red: 233 / 255, green: 241 / 255, blue: 232 / 255)
    static let red = Color(red: 153 / 255, green: 77 / 255, blue: 72 / 255)
    static let blue = Color(red: 56 / 255, green: 97 / 255, blue: 116 / 255)
    static let blueSoft = Color(red: 229 / 255, green: 239 / 255, blue: 244 / 255)
    static let yellow = Color(red: 118 / 255, green: 93 / 255, blue: 36 / 255)
    static let yellowSoft = Color(red: 244 / 255, green: 236 / 255, blue: 216 / 255)
}

extension Date {
    var relativeMemoTime: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(self) {
            return "昨天"
        }
        if calendar.component(.year, from: self) == calendar.component(.year, from: Date()) {
            return formatted(.dateTime.month().day())
        }
        return formatted(.dateTime.year().month().day())
    }

    var detailMemoTime: String {
        formatted(.dateTime.month().day().hour().minute())
    }
}

extension TimeInterval {
    var clockText: String {
        let total = max(0, Int(self.rounded(.down)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var readableDuration: String {
        let total = max(1, Int(self.rounded()))
        if total < 60 { return "\(total) 秒" }
        let minutes = total / 60
        let seconds = total % 60
        return seconds == 0 ? "\(minutes)分钟" : "\(minutes)分\(seconds)秒"
    }
}
