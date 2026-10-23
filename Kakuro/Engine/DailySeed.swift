import Foundation

/// A local-calendar day, the key for daily puzzles and streaks.
nonisolated struct DayKey: Hashable, Codable, Sendable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Gregorian in the device's time zone. The daily still turns over at the
    /// player's midnight, but year, month and day are always Gregorian, so a
    /// phone set to the Japanese or Buddhist calendar gets the same board and
    /// weekday as everyone else.
    static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    init(date: Date, calendar: Calendar = DayKey.localCalendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 2000
        month = parts.month ?? 1
        day = parts.day ?? 1
    }

    var isoString: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    func date(calendar: Calendar = DayKey.localCalendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    func previous(calendar: Calendar = DayKey.localCalendar) -> DayKey {
        let d = date(calendar: calendar)
        let prev = calendar.date(byAdding: .day, value: -1, to: d) ?? d
        return DayKey(date: prev, calendar: calendar)
    }

    static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// Deterministic daily puzzle: every player gets the same board.
/// **Never change the seed string or the schedule once shipped** — doing so
/// changes every future (and past) daily for everyone.
nonisolated enum DailySeed {
    /// FNV-1a over "kakuro.daily.v1.YYYY-MM-DD".
    static func seed(for day: DayKey) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in "kakuro.daily.v1.\(day.isoString)".utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    /// Fixed weekly rhythm, gentle start of week, big weekend boards.
    /// Weekday from the day key's own date (Gregorian, any timezone-local
    /// calendar gives the same weekday for a given Y-M-D).
    ///
    /// Both weekend days are large/hard, unlike Hashi's large/medium Saturday:
    /// on Kakuro large/medium measured p90 3.6 s native -O over 18 dailies and
    /// missed its band 3 times, large/hard p90 1.8 s. Large/easy (the slowest
    /// key, docs/ENGINEERING.md) is never scheduled.
    static func spec(for day: DayKey) -> (size: BoardSize, difficulty: Difficulty) {
        switch weekday(of: day) {
        case 2, 3: (.small, .easy)        // Mon Tue
        case 4, 5: (.medium, .medium)     // Wed Thu
        case 6: (.medium, .hard)          // Fri
        default: (.large, .hard)          // Sat Sun
        }
    }

    /// 1 = Sunday … 7 = Saturday (Zeller, independent of Calendar/timezone).
    static func weekday(of day: DayKey) -> Int {
        var y = day.year
        var m = day.month
        if m < 3 {
            m += 12
            y -= 1
        }
        let k = y % 100
        let j = y / 100
        let h = (day.day + (13 * (m + 1)) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
        // Zeller: 0 = Saturday … 6 = Friday → convert to 1 = Sunday … 7 = Saturday.
        return ((h + 6) % 7) + 1
    }
}
