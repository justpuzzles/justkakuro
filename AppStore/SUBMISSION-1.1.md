# Just Kakuro 1.1 "Daily": submission runbook

State on 2026-10-09: **ready to submit on all four platforms, not
submitted.** Each 1.1 version has build 8 attached and sits in its own draft
review submission, so App Store Connect has already run its completeness
check: version and submission are both `READY_FOR_REVIEW`. The only step left
is pressing Submit (§1).

## App record facts

- ASC App ID **6796701026** · bundle `de.kaikunze.kakuro` · en-US · team `8H42EZRCCP`
- 1.0 is live on iOS, macOS, tvOS and visionOS. The IAP *Just Kakuro Full*
  (`de.kaikunze.kakuro.full`) is **APPROVED**, so unlike 1.0 it does not need
  to ride along in the submission.
- Release type: `AFTER_APPROVAL`, as for 1.0. Switch to manual on the web if
  the four platforms should go live together.

| Platform | 1.1 version id | Build 8 id (= delivery id) | Draft review submission |
|---|---|---|---|
| iOS | `f7c1752b-d547-481d-a37a-be43e11fa708` | `9345994a-5e82-47c1-8e56-eeaeababf153` | `90ec9159-aeff-4c49-a3be-ca4b877ca59a` |
| macOS | `765085cc-498c-4c57-aa85-99b7828265cc` | `b981d667-7366-453d-8e59-76ac59113e62` | `4781dea1-fee0-4f80-b09a-0d3b06aa327f` |
| tvOS | `ee359e7d-e1f8-4066-86e0-a56fda59c520` | `57c7877d-f8b5-4034-8edc-3ca42c246c1a` | `c6fde483-283b-45ac-b7cd-1b54f5c20637` |
| visionOS | `cd9f962c-68e8-4abf-b3d9-8b78a01dd543` | `0ca741d3-d8c8-4ab9-bb73-21326e5de245` | `1f479baf-bead-4bb0-96d4-5660c8587595` |

Build 7 was uploaded first (all four platforms, `VALID`) and is **not**
attached: it predates the tvOS badge-size fix. Ignore it.

## 1. What is left

Kai, per platform:
- [ ] **Submit.** On the web: App Store Connect → Just Kakuro → the platform's
  1.1 page shows the draft submission ("Ready for Review") → Submit for
  Review. Or by API, which is the same action:
  `asc.py PATCH reviewSubmissions/<id> '{"data":{"type":"reviewSubmissions","id":"<id>","attributes":{"submitted":true}}}'`
  with the ids from the table above.
- [ ] Optional: Accessibility Nutrition Labels from `docs/ACCESSIBILITY.md`
  (iOS claims are tested; the Mac Daily card was checked by AXPress; tvOS
  VoiceOver is untested, so claim nothing there).
- [ ] Optional: mention the Daily on `AppStore/index.html` and republish the
  site at kaikunze.de/justkakuro/.

Done by API on 2026-10-09, all read back:
- [x] 1.1 versions created (copyright 2026 Kai Kunze, `AFTER_APPROVAL`)
- [x] What's New per platform from `metadata/whatsnew-1.1*.txt`: no edge-swipe
  line off iOS, and no VoiceOver claim on tvOS
- [x] Descriptions from `metadata/description*.txt`: the Daily paragraph, and
  the FREE/UNLOCK lists say the Daily and the streak are free
- [x] Review notes on all four start with a "New in 1.1" paragraph: a free
  player reaching a large board through the weekend Daily is intended, and
  Stats now opens with only the Daily panel free
- [x] Screenshots swapped in place, every asset `COMPLETE`: `01-home` and
  `05-stats` on iPhone 6.9" and iPad 13"; `1-home` on Apple TV and Vision Pro.
  The Mac set (game, learn) shows nothing that changed.
- [x] Draft review submission per platform with the 1.1 version as its item;
  the item POST passed Apple's readiness gate on all four (2026-10-09)
- [x] Builds 1.1 (8): each package inspected (version, no `.storekit`, privacy
  manifest present, no `-KakuroScreenshotUnlock`/`-uiTestResetState`
  strings), `--validate-app` clean, uploaded, `VALID`,
  `usesNonExemptEncryption = false`, attached

## 2. How this was checked

- 175 unit tests and the UI audits pass on iOS 18.5. `testDaily`, `testHome`
  and `testStatsFree` also pass on visionOS 2.5, which needs the command-line
  override `SUPPORTED_PLATFORMS="xros xrsimulator" SDKROOT=xros
  XROS_DEPLOYMENT_TARGET=2.0`, because the UI test target is iOS-only.
- iOS simulator: today's daily solved by idb taps → "Daily solved", streak 1;
  replay leaves the streak alone; Home shows the solved seal.
- macOS Debug build: the Daily card opened with AXPress (after the fix in
  `faf0f7a`), the board was solved with the cells' "Enter n" accessibility
  actions → "Daily solved", streak 4 → 5. Synthetic mouse clicks did not
  reach the window; use AX.
- tvOS 18.5 simulator: Home screenshot only. The Daily card takes focus on
  launch. Selecting it with the remote was not driven.
- Same seed gives the same board on iOS and macOS (2026-10-09, medium/hard).

## 3. Traps met this time

- **Screenshot sets kept their display types.** The iPhone set is
  `APP_IPHONE_67` (1320×2868), the type 1.0 was approved with, despite AppShip's
  note that 6.9" sets do not display. Swapping single screenshots (reserve,
  PUT, commit with MD5, delete the old one, PATCH the set's order) keeps every
  other shot and the order intact.
- **The builds list lags altool.** visionOS build 8 was not in
  `GET builds?filter[app]=…` minutes after upload while `altool --build-status`
  said `VALID`; `PATCH appStoreVersions/{id}/relationships/build` with the
  delivery id worked anyway.
