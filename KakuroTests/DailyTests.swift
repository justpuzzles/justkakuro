import Foundation
import Testing
@testable import Kakuro

@Suite("Daily seed")
struct DailySeedTests {
    @Test func sameDaySameSeed() {
        let day = DayKey(year: 2026, month: 8, day: 7)
        #expect(DailySeed.seed(for: day) == DailySeed.seed(for: day))
        #expect(DailySeed.seed(for: day) != DailySeed.seed(for: DayKey(year: 2026, month: 8, day: 8)))
    }

    /// The seed string is shipped API: Hashi's prefix would hand both apps the
    /// same seeds, and any change rewrites every player's dailies.
    @Test func seedIsPinned() {
        #expect(DailySeed.seed(for: DayKey(year: 2026, month: 1, day: 1)) == 3203574398170741420)
    }

    /// The daily is a pure function of the date, so this board is effectively
    /// shipped API. If this fails, every player's daily changed — the seed,
    /// the schedule or the generator's RNG order moved. Do not update the
    /// expectation; fix the regression. ('#' block, '\' clue, digits white.)
    @Test func goldenBoardForNewYear2026() {
        let day = DayKey(year: 2026, month: 1, day: 1)
        let generated = KakuroGenerator.generate(PuzzleCache.CacheKey.daily(day).options)
        let rendered = generated.puzzle.cells.map { row in
            row.map { cell -> String in
                switch cell {
                case .block: "#"
                case .clue: "\\"
                case .white(let digit): String(digit)
                }
            }.joined()
        }
        #expect(rendered == [
            "#########",
            "###\\\\\\\\##",
            "##\\5817##",
            "#\\64978\\\\",
            "\\13\\#\\984",
            "\\629\\\\\\98",
            "##\\17463#",
            "##\\3512##",
            "#########",
        ])
    }

    @Test func weekdayMatchesFoundationCalendar() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        for offset in 0..<400 {
            let date = Date(timeIntervalSince1970: 1_750_000_000 + Double(offset) * 86_400)
            let day = DayKey(date: date, calendar: calendar)
            #expect(DailySeed.weekday(of: day) == calendar.component(.weekday, from: date),
                    "\(day.isoString)")
        }
    }

    /// The whole week, pinned. Never schedules large/easy, the slowest key.
    @Test func scheduleCoversTheWeek() {
        // Monday 2026-08-03 … Sunday 2026-08-09.
        let week: [(BoardSize, Difficulty)] = [
            (.small, .easy), (.small, .easy),
            (.medium, .medium), (.medium, .medium),
            (.medium, .hard),
            (.large, .hard), (.large, .hard),
        ]
        for (offset, expected) in week.enumerated() {
            let spec = DailySeed.spec(for: DayKey(year: 2026, month: 8, day: 3 + offset))
            #expect(spec == expected, "day \(3 + offset)")
        }
    }

    @Test func dayKeyComparisonAndPrevious() {
        let today = DayKey(year: 2026, month: 8, day: 7)
        let yesterday = DayKey(year: 2026, month: 8, day: 6)
        #expect(yesterday < today)
        #expect(today.previous() == yesterday)
        #expect(DayKey(year: 2026, month: 8, day: 1).previous() == DayKey(year: 2026, month: 7, day: 31))
        #expect(DayKey(year: 2027, month: 1, day: 1).previous() == DayKey(year: 2026, month: 12, day: 31))
    }
}

@Suite("Daily streaks")
@MainActor
struct DailyStreakTests {
    private func freshStore(_ name: String = "kakuro-daily-\(UUID().uuidString)") -> ProgressStore {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return ProgressStore(userDefaults: defaults)
    }

    private func day(_ month: Int, _ day: Int) -> DayKey {
        DayKey(year: 2026, month: month, day: day)
    }

    @Test func consecutiveDaysGrowTheStreak() {
        let store = freshStore()
        store.recordDailyCompleted(day: day(8, 5), time: 100)
        #expect(store.daily.currentStreak == 1)
        store.recordDailyCompleted(day: day(8, 6), time: 100)
        store.recordDailyCompleted(day: day(8, 7), time: 100)
        #expect(store.daily.currentStreak == 3)
        #expect(store.daily.bestStreak == 3)
    }

    @Test func gapResetsToOne() {
        let store = freshStore()
        store.recordDailyCompleted(day: day(8, 1), time: 100)
        store.recordDailyCompleted(day: day(8, 2), time: 100)
        store.recordDailyCompleted(day: day(8, 5), time: 100)
        #expect(store.daily.currentStreak == 1)
        #expect(store.daily.bestStreak == 2)
    }

    @Test func repeatCompletionIsIdempotent() {
        let store = freshStore()
        store.recordDailyCompleted(day: day(8, 7), time: 100)
        store.recordDailyCompleted(day: day(8, 7), time: 50)
        #expect(store.daily.currentStreak == 1)
        #expect(store.dailyTime(day(8, 7)) == 100)
    }

    @Test func monthBoundaryCounts() {
        let store = freshStore()
        store.recordDailyCompleted(day: day(7, 31), time: 100)
        store.recordDailyCompleted(day: day(8, 1), time: 100)
        #expect(store.daily.currentStreak == 2)
    }

    @Test func displayStreakGoesStaleAfterMissedDay() {
        let store = freshStore()
        store.recordDailyCompleted(day: day(8, 1), time: 100)
        store.recordDailyCompleted(day: day(8, 2), time: 100)
        #expect(store.displayStreak(today: day(8, 4)) == 0)
        #expect(store.displayStreak(today: day(8, 3)) == 2)
        #expect(store.streakIsAtRisk(today: day(8, 3)))
        #expect(!store.streakIsAtRisk(today: day(8, 2)))
    }

    /// Hashi resets the counter to 1 here while leaving `lastCompleted` on the
    /// newer day, which breaks a live streak. A saved older daily finished late
    /// must record its time and touch nothing else.
    @Test func finishingAnOlderDailyLateKeepsTheStreak() {
        let store = freshStore()
        store.recordDailyCompleted(day: day(8, 6), time: 100)
        store.recordDailyCompleted(day: day(8, 7), time: 100)
        store.recordDailyCompleted(day: day(8, 1), time: 90)
        #expect(store.daily.lastCompleted == day(8, 7))
        #expect(store.daily.currentStreak == 2)
        #expect(store.dailyTime(day(8, 1)) == 90)
        #expect(store.displayStreak(today: day(8, 8)) == 2)
    }

    @Test func recordSurvivesRelaunch() {
        let name = "kakuro-daily-\(UUID().uuidString)"
        let store = freshStore(name)
        store.recordDailyCompleted(day: day(8, 6), time: 100)
        store.recordDailyCompleted(day: day(8, 7), time: 80)
        let relaunched = ProgressStore(userDefaults: UserDefaults(suiteName: name)!)
        #expect(relaunched.daily == store.daily)
        #expect(relaunched.daily.currentStreak == 2)
    }
}

@Suite("Daily game")
@MainActor
struct DailyGameTests {
    private func generated() -> GeneratedPuzzle {
        GeneratedPuzzle(puzzle: Fixtures.tiny2x2Unique, difficulty: .easy, techniqueProfile: [:])
    }

    @Test func snapshotCarriesTheDay() throws {
        let day = DayKey(year: 2026, month: 10, day: 10)
        let game = KakuroGame(puzzle: generated(), requestedDifficulty: .hard, dailyKey: day)
        let data = try JSONEncoder().encode(game.snapshot)
        let restored = KakuroGame(snapshot: try JSONDecoder().decode(KakuroGame.Snapshot.self, from: data))
        #expect(restored.dailyKey == day)
    }

    /// Saves written by 1.0 have no `dailyKey`. They must still load, as an
    /// ordinary game, or the update throws away every player's board in progress.
    @Test func saveFromBeforeDailiesStillDecodes() throws {
        let game = KakuroGame(puzzle: generated(), requestedDifficulty: .easy)
        var json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(game.snapshot)) as! [String: Any]
        json.removeValue(forKey: "dailyKey")
        let data = try JSONSerialization.data(withJSONObject: json)
        let snapshot = try JSONDecoder().decode(KakuroGame.Snapshot.self, from: data)
        #expect(snapshot.dailyKey == nil)
        #expect(KakuroGame(snapshot: snapshot).dailyKey == nil)
    }
}

@Suite("Daily gate")
struct DailyGateTests {
    @Test func dailyIsFreeOnEveryScheduledDay() {
        for offset in 0..<7 {
            let day = DayKey(year: 2026, month: 8, day: 3 + offset)
            #expect(FeatureGate.isDailyAvailable(day, unlocked: false))
        }
    }

    @Test func upsellOnlyAfterAFreeLargeDaily() {
        #expect(FeatureGate.shouldOfferUnlock(afterSolving: .large, wasDaily: true, unlocked: false))
        #expect(!FeatureGate.shouldOfferUnlock(afterSolving: .large, wasDaily: true, unlocked: true))
        #expect(!FeatureGate.shouldOfferUnlock(afterSolving: .medium, wasDaily: true, unlocked: false))
        #expect(!FeatureGate.shouldOfferUnlock(afterSolving: .large, wasDaily: false, unlocked: false))
    }
}

@Suite("Day key calendar")
struct DayKeyCalendarTests {
    /// The daily is keyed on Gregorian Y-M-D whatever calendar the phone uses;
    /// a Japanese-calendar year (Reiwa 8) would otherwise seed a different board.
    @Test func defaultCalendarIsGregorianLocalTime() {
        #expect(DayKey.localCalendar.identifier == .gregorian)
        #expect(DayKey.localCalendar.timeZone == TimeZone.current)
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        let parts = DayKey.localCalendar.dateComponents([.year, .month, .day], from: date)
        #expect(DayKey(date: date) == DayKey(year: parts.year!, month: parts.month!, day: parts.day!))
    }

    @Test func otherCalendarsGiveOtherYears() {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = .current
        let date = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(DayKey(date: date, calendar: japanese) != DayKey(date: date))
    }
}
