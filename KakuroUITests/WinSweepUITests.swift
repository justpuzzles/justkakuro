import XCTest

/// The solving move plays the clue sweep and then the win sheet, without
/// holding the sheet back. `-KakuroNearlySolved` (DEBUG) leaves one cell open
/// and selected; the pad digits are tried in turn until one wins.
@MainActor
final class WinSweepUITests: XCTestCase {
    func testSolvingMoveSweepsThenShowsTheSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState", "-KakuroNearlySolved"]
        app.launch()
        app.buttons["Play"].tap()
        let cell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Row '")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 20))
        sleep(1)
        let done = app.buttons["Done"]
        for digit in 1...9 {
            app.buttons["\(digit)"].firstMatch.tap()
            // The sweep runs ~0.85 s; anything past 2 s means the sheet is late.
            if done.waitForExistence(timeout: 2) { break }
        }
        XCTAssertTrue(done.exists, "the win sheet follows the sweep")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH 'techniques used'"))
            .firstMatch.exists, "the sheet leads with the techniques line")
        sleep(1)
    }
}
