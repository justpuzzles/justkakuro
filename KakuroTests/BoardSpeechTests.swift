import Foundation
import Testing
@testable import Kakuro

/// What VoiceOver hears about the board (docs/ACCESSIBILITY.md).
@MainActor
@Suite struct BoardSpeechTests {

    private func makeGame() -> KakuroGame {
        let puzzle = Fixtures.tiny2x2Unique
        let logical = LogicalSolver.solve(puzzle)
        return KakuroGame(puzzle: GeneratedPuzzle(
            puzzle: puzzle, difficulty: .easy, techniqueProfile: logical.histogram))
    }

    @Test func positionsAreOneBased() {
        #expect(BoardSpeech.position(GridPosition(row: 0, col: 2)) == "row 1, column 3")
    }

    @Test func cellValueNamesContentAndBothRuns() throws {
        let game = makeGame()
        let pos = try #require(game.puzzle.whitePositions.min())
        let runs = game.puzzle.runs(containing: pos)
        #expect(runs.count == 2)
        let empty = BoardSpeech.cellValue(game, at: pos)
        #expect(empty.hasPrefix("empty, "))
        for run in runs { #expect(empty.contains(BoardSpeech.run(run))) }

        game.toggleNote(3, at: pos)
        game.toggleNote(1, at: pos)
        #expect(BoardSpeech.cellValue(game, at: pos).hasPrefix("notes 1 3, "))

        game.place(2, at: pos)
        #expect(BoardSpeech.cellValue(game, at: pos).hasPrefix("2, "))
    }

    @Test func runSpanSaysWhereTheRunIs() throws {
        let game = makeGame()
        let across = try #require(game.puzzle.runs.first { $0.orientation == .across })
        let first = try #require(across.cells.first)
        let span = BoardSpeech.runSpan(across)
        #expect(span.hasPrefix("across \(across.sum) in \(across.length), row \(first.row + 1)"))
    }

    @Test func entriesChangedSpeaksPlacementsClearsAndCompletedRuns() throws {
        let game = makeGame()
        let pos = try #require(game.puzzle.whitePositions.min())
        let run = try #require(game.puzzle.runs(containing: pos).first)
        let placed = BoardSpeech.entriesChanged(old: [:], new: [pos: 4], completed: [run],
                                                puzzle: game.puzzle)
        #expect(placed == "4 at row \(pos.row + 1), column \(pos.col + 1). \(BoardSpeech.run(run)) complete")
        let cleared = BoardSpeech.entriesChanged(old: [pos: 4], new: [:], completed: [],
                                                 puzzle: game.puzzle)
        #expect(cleared == "row \(pos.row + 1), column \(pos.col + 1) cleared")
        #expect(BoardSpeech.entriesChanged(old: [:], new: [:], completed: [], puzzle: game.puzzle) == nil)
    }

    @Test func spokenHintAddsWhereItPoints() {
        let game = makeGame()
        let engine = HintEngine()
        let mastery = MasteryTracker()
        var hint = engine.hint(for: game, mastery: mastery)
        #expect(BoardSpeech.spokenHint(hint, puzzle: game.puzzle) == hint.text)
        while hint.level < .resolution {
            hint = engine.escalate(hint, for: game, mastery: mastery)
        }
        let spoken = BoardSpeech.spokenHint(hint, puzzle: game.puzzle)
        #expect(spoken.hasPrefix(hint.text))
        if !hint.application.placements.isEmpty {
            #expect(spoken.contains("Place "))
        }
        #expect(spoken.contains("row "))
    }
}
