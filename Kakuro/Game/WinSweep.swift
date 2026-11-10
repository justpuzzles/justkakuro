import Foundation

/// The clue sweep played on the solving move: a diagonal wave from the top-left
/// corner, each white cell flashing the solved tint at `row + col`, and each
/// clue's sum lighting at the moment the wave reaches the last cell of its run,
/// which is the moment that run reads as complete.
///
/// Pure timing, no SwiftUI, so the schedule is testable and the views only look
/// numbers up. Steps are integers; `stagger` turns them into seconds.
nonisolated struct WinSweep: Equatable, Sendable {
    /// Wave step at which each white cell flashes.
    let cellStep: [GridPosition: Int]
    /// Wave step at which each clue cell's across sum lights.
    let acrossStep: [GridPosition: Int]
    /// Wave step at which each clue cell's down sum lights.
    let downStep: [GridPosition: Int]
    /// Highest step on the board; the wave's last cell.
    let lastStep: Int
    /// Seconds between steps. Fitted to the board so a large board takes no
    /// longer than a small one, capped at the per-run sweep so a small board
    /// does not crawl.
    let stagger: TimeInterval

    init(puzzle: KakuroPuzzle, span: TimeInterval, maxStagger: TimeInterval) {
        var cells: [GridPosition: Int] = [:]
        for pos in puzzle.whitePositions {
            cells[pos] = pos.row + pos.col
        }
        var across: [GridPosition: Int] = [:]
        var down: [GridPosition: Int] = [:]
        for run in puzzle.runs {
            let step = run.cells.map { $0.row + $0.col }.max() ?? 0
            switch run.orientation {
            case .across: across[run.clueCell] = step
            case .down: down[run.clueCell] = step
            }
        }
        cellStep = cells
        acrossStep = across
        downStep = down
        lastStep = cells.values.max() ?? 0
        stagger = lastStep > 0 ? min(maxStagger, span / Double(lastStep)) : 0
    }

    /// Seconds after the solving move at which `step` is reached.
    func delay(_ step: Int?) -> TimeInterval {
        Double(step ?? 0) * stagger
    }

    /// When the wave's last cell starts its flash.
    var duration: TimeInterval { Double(lastStep) * stagger }
}

/// The win sheet's lead line: how much of the curriculum this board exercised.
nonisolated enum WinSummary {
    static func techniquesLine(profile: [Technique: Int]) -> String? {
        let used = profile.values.filter { $0 > 0 }.count
        guard used > 0 else { return nil }
        return "\(used) of \(Technique.allCases.count) techniques used"
    }
}
