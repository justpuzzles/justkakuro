import Foundation
import Testing
@testable import Kakuro

@Suite("Win clue sweep")
struct WinSweepTests {
    /// small4x4 (see Fixtures): the wave runs on row + col, and each clue lights
    /// on the step of its run's last cell, when that run reads as complete.
    @Test func stepsFollowTheDiagonalAndRunEnds() {
        let sweep = WinSweep(puzzle: Fixtures.small4x4, span: 0.55, maxStagger: 0.04)
        #expect(sweep.cellStep[GridPosition(row: 1, col: 1)] == 2)
        #expect(sweep.cellStep[GridPosition(row: 3, col: 3)] == 6)
        #expect(sweep.cellStep.count == Fixtures.small4x4.whitePositions.count)
        #expect(sweep.lastStep == 6)
        #expect(sweep.acrossStep[GridPosition(row: 1, col: 0)] == 3)
        #expect(sweep.acrossStep[GridPosition(row: 2, col: 0)] == 5)
        #expect(sweep.acrossStep[GridPosition(row: 3, col: 1)] == 6)
        #expect(sweep.downStep[GridPosition(row: 0, col: 1)] == 3)
        #expect(sweep.downStep[GridPosition(row: 0, col: 2)] == 5)
        #expect(sweep.downStep[GridPosition(row: 1, col: 3)] == 6)
        // A clue heading only one run never lights on the other half.
        #expect(sweep.downStep[GridPosition(row: 1, col: 0)] == nil)
    }

    /// Small boards keep the run sweep's pace rather than crawling.
    @Test func staggerIsCappedOnSmallBoards() {
        let sweep = WinSweep(puzzle: Fixtures.small4x4, span: 0.55, maxStagger: 0.04)
        #expect(sweep.stagger == 0.04)
        #expect(abs(sweep.delay(5) - 0.2) < 1e-9)
    }

    /// Every board size crosses within the span, so the sheet is never held
    /// back longer on a large board.
    @Test func everySizeFitsTheSpan() {
        for size in BoardSize.allCases {
            let generated = KakuroGenerator.generate(.init(size: size, difficulty: .hard, seed: 7))
            let sweep = WinSweep(puzzle: generated.puzzle, span: Motion.winSweepSpan,
                                 maxStagger: Motion.runCompleteStagger)
            #expect(sweep.duration <= Motion.winSweepSpan + 1e-9, "\(size)")
            #expect(sweep.duration > 0, "\(size)")
        }
    }

    @Test func techniquesLineCountsUsedOfAll() {
        let profile: [Technique: Int] = [.magicBlock: 3, .crossReference: 1, .nakedSingle: 0]
        #expect(WinSummary.techniquesLine(profile: profile) == "2 of 8 techniques used")
        #expect(WinSummary.techniquesLine(profile: [:]) == nil)
    }
}
