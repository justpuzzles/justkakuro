import XCTest

/// The 1.2 save model, end to end. Unit tests reach `ProgressStore` but not
/// the view lifecycle that decides when a save happens, and both 1.1
/// persistence bugs survived a green unit suite (docs/ENGINEERING.md).
@MainActor
final class SaveSlotsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState"]
    }

    private var firstCell: XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Row '")).firstMatch
    }

    private var continueCard: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Continue' AND NOT (label BEGINSWITH 'Continue daily')")).firstMatch
    }

    private var continueDailyCard: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Continue daily'")).firstMatch
    }

    private func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5), "back on Home")
    }

    /// A move into a cell: select it, then press digits until its value
    /// changes (a digit can be refused, and tapping the cell again would
    /// deselect it).
    private func enterSomething() {
        XCTAssertTrue(firstCell.waitForExistence(timeout: 30))
        firstCell.tap()
        let before = firstCell.value as? String
        for digit in 1...9 {
            app.buttons["\(digit)"].firstMatch.tap()
            if (firstCell.value as? String) != before { return }
        }
        XCTFail("no digit changed the cell")
    }

    func testFirstRunCardShowsOnceAndDismisses() {
        app.launch()
        XCTAssertTrue(app.buttons["introCard"].waitForExistence(timeout: 5),
                      "a fresh install points at the rules")
        app.buttons["Dismiss"].tap()
        XCTAssertFalse(app.buttons["introCard"].waitForExistence(timeout: 2))
        app.terminate()
        app.launchArguments = []          // relaunch without wiping state
        app.launch()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["introCard"].exists, "dismissed stays dismissed")
    }

    func testPeekingAtTheDailyKeepsTheGameInProgress() {
        app.launch()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        app.buttons["Play"].tap()
        enterSomething()
        goBack()
        XCTAssertTrue(continueCard.waitForExistence(timeout: 5), "the move was saved")
        let saved = continueCard.label

        // Open the Daily and leave without touching it.
        app.buttons["dailyCard"].tap()
        XCTAssertTrue(firstCell.waitForExistence(timeout: 30))
        goBack()
        XCTAssertTrue(continueCard.waitForExistence(timeout: 5),
                      "1.1 saved the untouched daily over this game")
        XCTAssertEqual(continueCard.label, saved)
        XCTAssertFalse(continueDailyCard.exists, "an untouched daily is not saved")

        // A move on the Daily goes to its own slot; today's resumes from the
        // Daily card, so it gets no Continue row of its own.
        app.buttons["dailyCard"].tap()
        enterSomething()
        goBack()
        XCTAssertEqual(continueCard.label, saved, "the standard game is still there")
        XCTAssertFalse(continueDailyCard.exists)

        // Play over a saved game asks first; Cancel changes nothing.
        app.buttons["Play"].tap()
        XCTAssertTrue(app.staticTexts["Start a new game?"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertEqual(continueCard.label, saved)

        // Confirm, look at the new board, leave without a move: the slot is
        // only taken by a move, so the old game is still there.
        app.buttons["Play"].tap()
        XCTAssertTrue(app.buttons["New game"].waitForExistence(timeout: 5))
        app.buttons["New game"].tap()
        XCTAssertTrue(firstCell.waitForExistence(timeout: 30))
        goBack()
        XCTAssertTrue(continueCard.waitForExistence(timeout: 5))
        XCTAssertEqual(continueCard.label, saved, "an untouched new board replaced the save")
    }
}
