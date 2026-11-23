import Foundation

/// API의 날짜(YYYYMMDD)는 한국 시간 기준으로 다룬다.
enum SyncDates {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    static func string(from date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year!, c.month!, c.day!)
    }

    static func date(from s: String) -> Date? {
        guard s.count == 8, let y = Int(s.prefix(4)), let m = Int(s.dropFirst(4).prefix(2)),
              let d = Int(s.suffix(2)) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d))
    }

    static func adding(days: Int, to s: String) -> String? {
        guard let d = date(from: s), let r = calendar.date(byAdding: .day, value: days, to: d) else { return nil }
        return string(from: r)
    }

    /// start...end 양끝 포함. start > end 이면 빈 배열.
    static func days(from start: String, to end: String) -> [String] {
        guard start <= end, var cur = date(from: start), let last = date(from: end) else { return [] }
        var out: [String] = []
        while cur <= last {
            out.append(string(from: cur))
            guard let n = calendar.date(byAdding: .day, value: 1, to: cur) else { break }
            cur = n
        }
        return out
    }
}
