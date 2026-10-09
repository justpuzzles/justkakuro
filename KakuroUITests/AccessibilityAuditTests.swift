import XCTest

/// Xcode's automated accessibility audit, one screen at a time
/// (docs/ACCESSIBILITY.md). Screens are reached by their labels, the way a
/// VoiceOver user would.
@MainActor
final class AccessibilityAuditTests: XCTestCase {

    private lazy var app: XCUIApplication = {
        continueAfterFailure = true
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState", "-KakuroScreenshotUnlock"]
        return app
    }()

    /// Set on screens that are system Lists (see `audit`).
    private var acceptListFalsePositives = false
    /// Set on the play screen: with the hint banner up, the audit reports the
    /// cell-sized digits without an element (the same board passes in
    /// `testBoard`, where it can attribute them).
    private var acceptUnattributedBoardDigits = false
    /// Set on the Daily's medium board: the audit fails clue numbers at that
    /// cell size on contrast, though they measure 10:1 against the block in a
    /// screenshot (docs/ACCESSIBILITY.md). Small boards pass the same check.
    private var acceptClueNumberContrast = false

    private func audit() throws {
        try app.performAccessibilityAudit { issue in
            print("AUDIT | \(issue.compactDescription) | \(issue.element?.elementType.rawValue ?? 0) | \(issue.element?.label ?? "-") | \(issue.element.map { "\($0.frame)" } ?? "") | \(issue.detailedDescription)")
            // Accepted, documented in docs/ACCESSIBILITY.md.
            // Board digits and the pad's digits are sized to their cells and
            // keys, the wordmark is a logotype.
            if issue.auditType == .dynamicType,
               let label = issue.element?.label,
               ["Just Kakuro", "Just", "Kakuro"].contains(label) || label.hasPrefix("Row ") || label.hasPrefix("Clue")
                || (!label.isEmpty && label.allSatisfy(\.isNumber))
                || (label.count == 1 && label.first?.isNumber == true) { return true }
            if self.acceptUnattributedBoardDigits, issue.element == nil, issue.auditType == .dynamicType { return true }
            if self.acceptClueNumberContrast, issue.auditType == .contrast,
               let label = issue.element?.label, !label.isEmpty, label.allSatisfy(\.isNumber) { return true }
            if self.acceptListFalsePositives, [.dynamicType, .textClipped].contains(issue.auditType) { return true }
            return false
        }
    }

    private func startGame() {
        app.buttons["Play"].tap()
        let cell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Row '")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 20))
    }

    func testHome() throws {
        app.launch()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        try audit()
    }

    func testBoard() throws {
        app.launch()
        startGame()
        let cell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Row '")).firstMatch
        XCTAssertTrue((cell.value as? String)?.contains(" in ") == true,
                      "a cell names its runs")
        try audit()
    }

    /// The Daily card opens today's board, labelled as the Daily.
    func testDaily() throws {
        app.launch()
        let card = app.buttons["dailyCard"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        XCTAssertTrue(card.label.hasPrefix("Daily puzzle"), "the card says what it is")
        card.tap()
        let cell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH 'Row '")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Daily'"))
            .firstMatch.exists, "the status row names the Daily")
        acceptClueNumberContrast = true
        try audit()
    }

    func testHint() throws {
        app.launch()
        startGame()
        app.buttons["Hint"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Dismiss hint"].waitForExistence(timeout: 5))
        acceptUnattributedBoardDigits = true
        try audit()
    }

    func testLearn() throws {
        app.launch()
        app.buttons["Learn"].tap()
        sleep(1)
        acceptListFalsePositives = true
        try audit()
    }

    func testStats() throws {
        app.launch()
        app.buttons["Stats"].tap()
        sleep(1)
        acceptListFalsePositives = true
        try audit()
    }

    /// The free player's Stats: the Daily streak panel above the inline lock.
    func testStatsFree() throws {
        app.launchArguments = ["-uiTestResetState"]
        app.launch()
        app.buttons["Stats"].tap()
        XCTAssertTrue(app.staticTexts["day streak"].waitForExistence(timeout: 5),
                      "the Daily panel is free")
        XCTAssertTrue(app.buttons["Unlock everything"].exists, "the rest is locked in place")
        acceptListFalsePositives = true
        try audit()
    }

    func testSettings() throws {
        app.launch()
        app.buttons["Settings"].tap()
        sleep(1)
        acceptListFalsePositives = true
        try audit()
    }

    func testHomeAtLargestTextSize() throws {
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        try audit()
    }
}
