import Foundation
#if canImport(PuzzleKit)
// Absent under a bare `swiftc` bench, which compiles PuzzleKit's sources into
// the same module instead (docs/ENGINEERING.md).
import PuzzleKit
#endif

/// Deterministic daily puzzle: every player gets the same board.
/// `DayKey` itself lives in PuzzleKit since 1.2; the seed prefix and the
/// weekly schedule are Kakuro's.
/// **Never change the seed string or the schedule once shipped** — doing so
/// changes every future (and past) daily for everyone.
nonisolated enum DailySeed {
    /// FNV-1a over "kakuro.daily.v1.YYYY-MM-DD".
    static func seed(for day: DayKey) -> UInt64 {
        DaySeed.seed(prefix: "kakuro.daily.v1.", day: day)
    }

    /// Fixed weekly rhythm, gentle start of week, big weekend boards.
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

    /// 1 = Sunday … 7 = Saturday, from the date itself (never a `Calendar`).
    /// PuzzleKit's Julian-day weekday; its tests pin it equal to the Zeller
    /// formula 1.1 shipped with, on every day from 1900 to 2300.
    static func weekday(of day: DayKey) -> Int {
        day.weekday
    }
}
