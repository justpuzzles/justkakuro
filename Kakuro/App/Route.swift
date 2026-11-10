import Foundation

enum Route: Hashable {
    case game(size: BoardSize, difficulty: Difficulty)
    case daily(DayKey)
    /// The saved game in that slot (standard and daily are kept apart).
    case resume(GameSlot)
    case tutorial(Technique?)
    case practice(Technique)
    case learn
    case practiceMenu
    case stats
    case settings
}
