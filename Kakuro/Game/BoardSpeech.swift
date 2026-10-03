import SwiftUI

/// Everything VoiceOver says about the board. The board is drawn, so speech
/// has to carry what sight gets from the grid: where a cell is, which runs it
/// belongs to, and what a hint is pointing at.
enum BoardSpeech {

    /// 1-based, the way people count.
    static func position(_ pos: GridPosition) -> String {
        "row \(pos.row + 1), column \(pos.col + 1)"
    }

    /// "across 16 in 3"
    static func run(_ run: Run) -> String {
        "\(run.orientation == .across ? "across" : "down") \(run.sum) in \(run.length)"
    }

    /// "across 16 in 3, row 2, columns 3 to 5"
    static func runSpan(_ run: Run) -> String {
        guard let first = run.cells.first, let last = run.cells.last else { return self.run(run) }
        switch run.orientation {
        case .across:
            return "\(self.run(run)), row \(first.row + 1), columns \(first.col + 1) to \(last.col + 1)"
        case .down:
            return "\(self.run(run)), column \(first.col + 1), rows \(first.row + 1) to \(last.row + 1)"
        }
    }

    /// The cell's content, then its runs: "7, across 16 in 3, down 7 in 2".
    static func cellValue(_ game: KakuroGame, at pos: GridPosition) -> String {
        var parts: [String] = []
        if let entry = game.board.entry(at: pos) {
            parts.append("\(entry)")
        } else {
            let notes = game.board.notes(at: pos).sorted()
            parts.append(notes.isEmpty ? "empty" : "notes \(notes.map(String.init).joined(separator: " "))")
        }
        parts += game.puzzle.runs(containing: pos).map(run)
        if let digit = game.highlightedDigit, game.isImpossible(digit: digit, at: pos) {
            parts.append("\(digit) can't go here")
        }
        return parts.joined(separator: ", ")
    }

    static func clueLabel(across: Int?, down: Int?, runs: [Run]) -> String {
        let spoken = runs.map(run)
        return spoken.isEmpty ? "block" : "Clue, " + spoken.joined(separator: ", ")
    }

    /// What changed on the board, for a player who can't see it change.
    static func entriesChanged(old: [GridPosition: Int], new: [GridPosition: Int],
                               completed: [Run], puzzle: KakuroPuzzle) -> String? {
        var parts: [String] = []
        let placed = new.filter { old[$0.key] != $0.value }.sorted { $0.key < $1.key }
        let cleared = old.keys.filter { new[$0] == nil }.sorted()
        if placed.count <= 3 {
            parts += placed.map { "\($0.value) at \(position($0.key))" }
        } else {
            parts.append("\(placed.count) digits placed")
        }
        if cleared.count == 1, let pos = cleared.first {
            parts.append("\(position(pos)) cleared")
        } else if cleared.count > 1 {
            parts.append("\(cleared.count) cells cleared")
        }
        parts += completed.map { "\(run($0)) complete" }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }

    /// The hint as shown, plus where it points. Hint text says "the
    /// highlighted run"; this names it.
    static func spokenHint(_ hint: Hint, puzzle: KakuroPuzzle) -> String {
        var parts = [hint.text]
        if !hint.highlightCells.isEmpty {
            let runs = hint.application.involvedRuns.compactMap { id in puzzle.runs.first { $0.id == id } }
            if !runs.isEmpty, hint.level < .resolution {
                parts.append("Highlighted: " + runs.map(runSpan).joined(separator: "; ") + ".")
            } else if hint.highlightCells.count <= 4 {
                parts.append("Highlighted: " + hint.highlightCells.sorted().map(position).joined(separator: "; ") + ".")
            }
        }
        if hint.level == .resolution, !hint.isErrorHint {
            let placements = hint.application.placements.map { "\($0.digit) at \(position($0.position))" }
            if !placements.isEmpty { parts.append("Place " + placements.joined(separator: ", ") + ".") }
        }
        return parts.joined(separator: " ")
    }

    static func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }
}
