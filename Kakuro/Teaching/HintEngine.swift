import Foundation

enum HintLevel: Int, Comparable, Sendable {
    case nudge, technique, highlight, resolution

    static func < (lhs: HintLevel, rhs: HintLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct Hint: Sendable, Equatable {
    let level: HintLevel
    let application: TechniqueApplication
    let text: String
    let highlightCells: [GridPosition]
    /// True when the hint is pointing at a player mistake, not teaching.
    let isErrorHint: Bool
    /// True when the teaching hint was withheld behind the unlock. The banner
    /// offers to unlock instead of escalating.
    var isLocked: Bool = false
    /// False when "Tell me more" would do nothing: a free player's error hint
    /// stops at the region (escalating to the exact cell is the paid ladder).
    /// 1.1 showed the button anyway, and tapping it changed nothing.
    var canEscalate: Bool = true

    /// The cells the board actually draws. An error hint shows its region
    /// from the first rung, since its text says "highlighted"; a teaching
    /// hint only from `.highlight`, so the nudge stays a nudge.
    var visibleCells: Set<GridPosition> {
        isErrorHint || level >= .highlight ? Set(highlightCells) : []
    }
}

/// How much the hint engine is allowed to give away.
///
/// `.errorsOnly` is the free tier: it still catches contradictions ("something
/// here is wrong"), but never names a technique or walks the escalation ladder.
nonisolated enum HintPolicy: Sendable {
    case errorsOnly
    case full
}

/// Escalating, context-aware hints. Errors first; then the next teachable step
/// from the logical solver, revealed a level at a time:
/// nudge (region) → technique (name + rule) → highlight (cells) → resolution.
@MainActor
struct HintEngine {

    /// `showErrors` mirrors the setting: when off, hints teach the next step and
    /// never point out contradictions.
    func hint(for game: KakuroGame, mastery: MasteryTracker, showErrors: Bool = true,
              policy: HintPolicy = .full) -> Hint {
        if showErrors, var errorHint = errorHint(for: game, level: .nudge) {
            errorHint.canEscalate = policy == .full
            return errorHint
        }
        guard let step = LogicalSolver.nextStep(puzzle: game.puzzle, board: game.board) else {
            return Hint(level: .nudge,
                        application: TechniqueApplication(technique: .duplicateInRun),
                        text: "Everything on the board checks out. Keep going.",
                        highlightCells: [], isErrorHint: false)
        }
        guard policy == .full else {
            // Withheld, so deliberately *without* recordHint: penalising mastery
            // for a hint the player never saw would silently damage their
            // progress path the moment they later pay.
            return Hint(level: .nudge,
                        application: step,
                        text: "There's a move available here. Teaching hints name the technique and show you why. They're part of the full game.",
                        highlightCells: [], isErrorHint: false, isLocked: true)
        }
        mastery.recordHint(technique: step.technique, level: .nudge)
        return Hint(level: .nudge,
                    application: step,
                    text: TechniqueContent.nudge(for: step, puzzle: game.puzzle),
                    highlightCells: [], isErrorHint: false)
    }

    func escalate(_ hint: Hint, for game: KakuroGame, mastery: MasteryTracker,
                  policy: HintPolicy = .full) -> Hint {
        // A locked hint never climbs the ladder; the banner offers the unlock.
        guard policy == .full, !hint.isLocked else { return hint }
        guard hint.level < .resolution else { return hint }
        let next = HintLevel(rawValue: hint.level.rawValue + 1) ?? .resolution
        if hint.isErrorHint {
            // Straight to the cells: an error's `.technique` rung had the same
            // text as its nudge, so the first "Tell me more" looked dead.
            return errorHint(for: game, level: hint.level == .nudge ? .highlight : next) ?? hint
        }
        let step = hint.application
        mastery.recordHint(technique: step.technique, level: next)
        let cells = next >= .highlight ? step.focusCells : []
        let text: String
        switch next {
        case .nudge:
            text = hint.text
        case .technique:
            text = TechniqueContent.rule(for: step.technique)
        case .highlight:
            text = TechniqueContent.detail(for: step, puzzle: game.puzzle)
        case .resolution:
            text = TechniqueContent.resolution(for: step, puzzle: game.puzzle)
        }
        return Hint(level: next, application: step, text: text,
                    highlightCells: cells, isErrorHint: false)
    }

    /// Wrong entries take priority over teaching: region first, exact cell later.
    private func errorHint(for game: KakuroGame, level: HintLevel) -> Hint? {
        let wrong = game.puzzle.whitePositions.filter { pos in
            if let entry = game.board.entry(at: pos) {
                return entry != game.puzzle.solution(at: pos)
            }
            return false
        }
        guard let first = wrong.min() else { return nil }
        let runs = game.puzzle.runs(containing: first)
        let region = runs.flatMap(\.cells)
        let application = TechniqueApplication(
            technique: .duplicateInRun,
            focusCells: level >= .resolution ? [first] : region,
            involvedRuns: runs.map(\.id)
        )
        let text: String
        switch level {
        case .nudge, .technique:
            text = "Something doesn't add up in one of the highlighted runs. Check the sums before going further."
        case .highlight:
            text = "One of these cells doesn't match its clues. Re-check each run's sum."
        case .resolution:
            text = "This cell is wrong. Clear it and rework the run from its combinations."
        }
        return Hint(level: level,
                    application: application,
                    text: text,
                    highlightCells: application.focusCells,
                    isErrorHint: true)
    }
}
