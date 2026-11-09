import Foundation
import Observation

/// The two save slots. A standard game and a daily each keep their own, so
/// starting one never overwrites the other (1.1 had a single shared slot).
enum GameSlot: String, Hashable, Sendable, CaseIterable {
    case standard
    case daily
}

/// The result of recording a solve, for the win sheet.
struct SolveResult: Equatable {
    /// False for a daily that was already solved: nothing was recorded.
    var counted: Bool
    var newBestTime: Bool
    /// For a replayed daily, the time of the first solve.
    var firstDailyTime: TimeInterval?
}

@Observable @MainActor
final class ProgressStore {
    private let defaults: UserDefaults

    private enum Key {
        static let bestTimes = "kakuro.bestTimes.v1"
        /// The 1.1 single slot. Kept as the standard slot's key, so a saved
        /// game survives the update and a downgrade still finds it.
        static let saveGame = "kakuro.saveGame.v1"
        static let saveGameDaily = "kakuro.saveGame.daily.v1"
        static let stats = "kakuro.stats.v1"
        static let mastery = "kakuro.mastery.v1"
        static let settings = "kakuro.settings.v1"
        static let lastPlayed = "kakuro.lastPlayed.v1"
        static let daily = "kakuro.daily.v1"
        static let introSeen = "kakuro.introSeen.v1"
    }

    /// The size/difficulty the player last started a game with, so the pickers
    /// come back where they left them and the cache can warm the right key.
    /// Deliberately not `BestTimeKey` — same shape, different meaning.
    struct GameChoice: Codable, Hashable {
        let size: BoardSize
        let difficulty: Difficulty
    }

    struct Settings: Codable, Equatable {
        var autoNotes = false
        var hapticsEnabled = true
        var showErrors = true
    }

    struct Stats: Codable, Equatable {
        var puzzlesSolved = 0
        var totalPlayTime: TimeInterval = 0
        var solvedBySize: [BoardSize: Int] = [:]
        var solvedByDifficulty: [Difficulty: Int] = [:]
    }

    struct BestTimeKey: Hashable, Codable {
        let size: BoardSize
        let difficulty: Difficulty
    }

    private(set) var bestTimes: [BestTimeKey: TimeInterval] = [:]
    private(set) var stats = Stats()
    /// The saved games, one per slot. Observable state rather than re-read on
    /// demand so the Continue card appears the moment a game is saved —
    /// reading UserDefaults inside a view body never invalidates it.
    private let saves: SaveSlots<GameSlot, KakuroGame.Snapshot>
    private(set) var lastPlayed: GameChoice?
    private(set) var daily = DailyRecord()
    /// The first-run "New to Kakuro?" card was opened or dismissed.
    private(set) var introSeen = false
    var settings = Settings() {
        didSet { save(settings, key: Key.settings) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        saves = SaveSlots(defaults: userDefaults,
                          keys: [.standard: Key.saveGame, .daily: Key.saveGameDaily])
        bestTimes = load([BestTimeKey: TimeInterval].self, key: Key.bestTimes) ?? [:]
        stats = load(Stats.self, key: Key.stats) ?? Stats()
        settings = load(Settings.self, key: Key.settings) ?? Settings()
        lastPlayed = load(GameChoice.self, key: Key.lastPlayed)
        daily = load(DailyRecord.self, key: Key.daily) ?? DailyRecord()
        introSeen = defaults.bool(forKey: Key.introSeen)
        // 1.1 kept a daily in the one slot there was. Move it to its own, or
        // it would show as the standard Continue game and be overwritten by
        // the next standard game.
        if saves[.standard]?.dailyKey != nil {
            saves.move(from: .standard, to: .daily)
        }
    }

    /// Show the rules card only to someone who has never played: a 1.1
    /// player updating to 1.2 has solves or a save, and never sees it.
    var showsIntro: Bool {
        !introSeen && stats.puzzlesSolved == 0 && daily.completedTimes.isEmpty
            && GameSlot.allCases.allSatisfy { savedGame($0) == nil }
    }

    func markIntroSeen() {
        introSeen = true
        defaults.set(true, forKey: Key.introSeen)
    }

    /// Records the *requested* size/difficulty for a new game.
    func recordLastPlayed(size: BoardSize, difficulty: Difficulty) {
        let choice = GameChoice(size: size, difficulty: difficulty)
        guard choice != lastPlayed else { return }
        lastPlayed = choice
        save(choice, key: Key.lastPlayed)
    }

    // MARK: - Best times / stats

    func bestTime(size: BoardSize, difficulty: Difficulty) -> TimeInterval? {
        bestTimes[BestTimeKey(size: size, difficulty: difficulty)]
    }

    /// Records a solve; returns true when it's a new best time. Counts
    /// unconditionally: callers that may be replaying a daily go through
    /// `recordWin` instead.
    @discardableResult
    func recordSolve(size: BoardSize, difficulty: Difficulty, time: TimeInterval) -> Bool {
        stats.puzzlesSolved += 1
        stats.totalPlayTime += time
        stats.solvedBySize[size, default: 0] += 1
        stats.solvedByDifficulty[difficulty, default: 0] += 1
        save(stats, key: Key.stats)

        let key = BestTimeKey(size: size, difficulty: difficulty)
        let isRecord = bestTimes[key].map { time < $0 } ?? true
        if isRecord {
            bestTimes[key] = time
            save(bestTimes, key: Key.bestTimes)
        }
        return isRecord
    }

    /// Everything a won game records, in one place: the daily first (so the
    /// win sheet's streak reads the new record on its first frame), then
    /// stats and best times, unless the daily was already solved. A replayed
    /// daily used to count again: a second solve, its time folded into play
    /// time, and a "new best" from a board the player had already seen.
    func recordWin(size: BoardSize, difficulty: Difficulty, time: TimeInterval,
                   daily day: DayKey?) -> SolveResult {
        if let day {
            let outcome = recordDailyCompleted(day: day, time: time)
            if case .replay(let first) = outcome {
                return SolveResult(counted: false, newBestTime: false, firstDailyTime: first)
            }
        }
        let best = recordSolve(size: size, difficulty: difficulty, time: time)
        return SolveResult(counted: true, newBestTime: best, firstDailyTime: nil)
    }

    // MARK: - Daily streak (PuzzleKit's DailyRecord, under the 1.1 key)

    func hasCompletedDaily(_ day: DayKey) -> Bool {
        daily.hasCompleted(day)
    }

    func dailyTime(_ day: DayKey) -> TimeInterval? {
        daily.time(for: day)
    }

    /// True when yesterday's daily kept the streak alive and today's is still
    /// open — the streak ends at midnight unless today is solved.
    func streakIsAtRisk(today: DayKey) -> Bool {
        daily.isAtRisk(today: today)
    }

    /// The streak as of `today`. Computed, never stored: a missed day shows 0
    /// without anything having to run at midnight.
    func displayStreak(today: DayKey) -> Int {
        daily.displayStreak(today: today)
    }

    /// Records a completed daily. Idempotent per day (a replay records
    /// nothing); finishing an older daily late keeps the streak.
    @discardableResult
    func recordDailyCompleted(day: DayKey, time: TimeInterval) -> DailyOutcome {
        let outcome = daily.record(day: day, time: time)
        if !outcome.isReplay {
            save(daily, key: Key.daily)
        }
        return outcome
    }

    // MARK: - Save game

    func savedGame(_ slot: GameSlot) -> KakuroGame.Snapshot? {
        saves[slot]
    }

    /// Saves into the snapshot's own slot. `hasProgress: false` (a board the
    /// player has not touched) keeps whatever that slot already holds.
    func saveGame(_ snapshot: KakuroGame.Snapshot, hasProgress: Bool = true) {
        saves.save(snapshot, in: snapshot.slot, hasProgress: hasProgress)
    }

    func clearSavedGame(_ slot: GameSlot) {
        saves.clear(slot)
    }

    // MARK: - Mastery (used by MasteryTracker)

    func loadMastery<T: Decodable>(_ type: T.Type) -> T? {
        load(type, key: Key.mastery)
    }

    func saveMastery(_ value: some Encodable) {
        save(value, key: Key.mastery)
    }

    // MARK: - Codable plumbing

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save(_ value: some Encodable, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}
