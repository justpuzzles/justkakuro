# Accessibility audit — Just Kakuro

This audit and its fixes are on branch `a11y-audit`, 2026-10-03. Tag
`pre-a11y-audit` marks `main` before the work (the live 1.1). Nothing here
has been uploaded. The method is the one in
`../shikaku/docs/ACCESSIBILITY.md`:
- common tasks
- `performAccessibilityAudit` per screen
- WCAG ratios computed from `Design/Theme.swift`
- Dynamic Type at AX5
- a code review for motion, targets and announcements

Kakuro ships on iPhone, iPad, Mac, Apple TV and Vision Pro. The automated
audit runs on iPhone; every change was built for all five platforms.

## Findings

🔴 blocks a common task · 🟠 puts a feature claim at risk · 🟡 friction · 🟢 polish

| # | Sev | Finding | Status |
|---|---|---|---|
| 1 | 🔴 | It no longer built with Xcode 27: the `DiagonalLine` `Shape` conformance failed Swift 6.4's isolation check. | **Fixed.** `nonisolated`. |
| 2 | 🔴 | A VoiceOver user could play, but slowly and largely blind. Rows and columns were spoken from 0. A cell never named its runs, so the user had to hunt for the clue cells. Every digit needed a trip across the whole board to the pad and back, and nothing confirmed an entry. | **Fixed.** A cell reads "Row 2, column 3" with the value "7, across 16 in 3, down 7 in 2". Custom actions "Enter 1–9" (or "Note 1–9" in notes mode) and "Clear" work on the cell itself. Every board change is spoken ("4 at row 2, column 3. across 16 in 3 complete"). Clue cells are buttons with the hint "Shows the digit sets that still fit". `Game/BoardSpeech.swift`, `BoardView.swift`, `GameView.assistiveEdit`. |
| 3 | 🟠 | Nothing was announced anywhere: hints, "Tell me more", run completion, the win. | **Fixed.** Hints are announced on every rung, the win with its time and record. |
| 4 | 🟠 | Hint text points at drawn highlights ("the highlighted run") without positions. | **Fixed.** `BoardSpeech.spokenHint` adds the highlighted runs with their rows and columns, and the placements of a resolution. |
| 5 | 🟠 | Pad state not spoken: Notes had no on/off value, the highlighted digit no selected trait, keys read "digit 5". | **Fixed.** Notes reads "On"/"Off" (on the tutorial pad too). The highlighted key is `.isSelected`. Keys read "5", with a hint when nothing is selected. |
| 6 | 🟠 | Contrast below 4.5:1: `inkSoft` 3.3–3.9 (notes, secondary text); dark `indigo` on surface 3.8; dark `error` on surface 3.6; `complete` 4.3–4.5. | **Fixed.** `inkSoft` alpha 0.70 light / 0.75 dark (4.6–7.7, notes on the selected wash included). Dark indigo 4.8, dark error 4.5, complete 4.6–5.2. |
| 7 | 🟠 | Dark mode: a playable cell against a block is 1.8:1, below the 3:1 for UI. | **Fixed.** A dark-only `cellEdge` around white cells (about 4:1 against a block). Light mode is unchanged (13:1). |
| 8 | 🟠 | Targets under 44 pt: the hint ✕ (about 20), the sheet close (about 33), Undo/Erase (40), "Tell me more", "Unlock hints" and Apply. | **Fixed.** All 44 pt or more; visuals unchanged. |
| 9 | 🟠 | Fixed font sizes on real content: combination digits, the win time, Stats counters, Home icons. | **Fixed.** `scaledFont`/`scaledDigitFont` (`Design/ScaledType.swift`, `@ScaledMetric`). The win time is also spoken as words. |
| 10 | 🟡 | At AX5, the Continue card kept its arrow beside the text. | **Fixed.** `CardRow` stacks it. |
| 11 | 🟡 | Reduce Motion: the hint banner slid in; the digit pop and the tutorial's wrong-tap wiggle ran regardless. | **Fixed.** The banner fades in, and the pop and wiggle are skipped. |
| 12 | 🟡 | State shown only visually: cells dimmed by the digit highlight; locked Home tiles (lock glyph only). | **Fixed.** Dimmed cells say "5 can't go here". Locked tiles have the value "Locked, part of the full game". |
| 13 | 🟠 | The audit found Learn rows failing contrast: locked and paywalled rows were faded to 60% on top of `inkSoft`, and paywalled rows stay tappable. Summaries were cut at two lines. | **Fixed.** No fade; the lock glyph and softer title mark them. Summaries wrap. |
| 14 | 🟢 | Home tile symbols and the Continue arrow were read as image names. | **Fixed.** Hidden from VoiceOver. |

### Accepted, with reasons

- **Board, clue and pad digits** are sized to their cells and keys. They are
  filtered in the audit by label. VoiceOver reads every cell in full.
- **Contrast reports on clue numbers on the Daily's medium board** (1.1,
  `testDaily`). Measured in a screenshot, a clue reads 10.0:1 against its
  block, (226,228,224) on (43,50,64). The audit flags them only at the
  medium board's clue size, about 12 pt; the small board passes in
  `testBoard`. Filtered on that screen only, and only for numeric labels.
  Since 1.2 also on the hint screen (`testHint`), whose board is random: one
  run in four drew a clue the audit flagged the same way.
- **Mac: the Daily card must keep its Button's own element** (1.1). Wrapping
  it in `.accessibilityElement(children: .ignore)` dropped the press action
  on macOS, so AXPress (and VoiceOver) could not open the Daily while iOS,
  which taps the centre, worked. The label now goes on the Button.
- **Unattributed Dynamic Type reports with the hint banner up.** The same
  board passes in `testBoard`, where the audit can attribute the digits.
  These are filtered on the hint screen only, and only when no element is
  named.
- **Board cells under 44 pt** on large boards. The board already fills the
  space, and every cell action is also on the pad and the keyboard.
- **System List screens** (Learn, Stats, Settings): Dynamic Type and clipping
  reports on standard rows are filtered on those screens only.

### Strengths (kept)

- Selection is shown three ways: ring, wash and the `.isSelected` trait.
- A hardware keyboard covers every move (`KeyboardInput.swift`).
- Learn rows already had state values, with their badges hidden.
- Errors reach the player through hints, not colour alone.

## Tests

- `KakuroTests/BoardSpeechTests.swift`: positions, cell values, run spans,
  change announcements, spoken hints.
- `KakuroUITests/AccessibilityAuditTests.swift`: one audit per screen
  (Home, board, hint, Learn, Stats, Settings, Home at AX5), launched with
  `-uiTestResetState -KakuroScreenshotUnlock`. Both flags are DEBUG only.
  The target was added with the `xcodeproj` gem plus a patched-in synchronized
  group, the same way as in Shikaku.

## Result

`xcodebuild test` (iPhone 16 Pro, iOS 18.5), 2026-10-03: 149 unit tests and
7 audit screens pass with the filters above. The app also builds for macOS,
tvOS and visionOS.

## Accessibility Nutrition Labels

These become claimable once this branch ships:
- VoiceOver
- Voice Control (cell actions under "Show actions")
- Larger Text (with the digit exception above)
- Sufficient Contrast
- Dark Interface
- Differentiate Without Color Alone
- Reduced Motion

Captions and Audio Descriptions do not apply.
