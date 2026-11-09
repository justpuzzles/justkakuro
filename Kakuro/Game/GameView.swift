import SwiftUI

/// The play screen: board, pad, toolbar, hints, pause and win states.
struct GameView: View {
    let game: KakuroGame
    /// Restored from its slot, so it may be saved before the first move.
    var resumed = false
    @Environment(ProgressStore.self) private var progress
    @Environment(MasteryTracker.self) private var mastery
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(TodayClock.self) private var clock
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hint: Hint?
    @State private var hintEngine = HintEngine()
    @State private var tappedClue: ClueSelection?
    @State private var sweep: [GridPosition: Int] = [:]
    @State private var showWinSheet = false
    /// The clue sweep, set once on the solving move.
    @State private var winSweep: WinSweep?
    /// The running sweep-then-sheet sequence; a tap cancels it and jumps on.
    @State private var winSequence: Task<Void, Never>?
    @State private var successPlayed = false
    /// Clears a run-complete sweep. Held so a second completion replaces the
    /// first one's timer instead of being wiped by it 0.4 s in.
    @State private var sweepReset: Task<Void, Never>?
    /// Set when the player taps Apply on a hint, consumed by the next entry
    /// change so that placement does not count toward unaided mastery.
    @State private var appliedHint = false
    @State private var newBestTime = false
    /// Set when the win was a daily already solved: nothing was recorded,
    /// and the sheet says so and shows the first time.
    @State private var replayOf: TimeInterval?
    /// Presented once the win sheet is gone: two sheets cannot be up at once,
    /// and the paywall is rooted above the NavigationStack.
    @State private var pendingPaywall: PaidFeature?
    #if os(tvOS)
    /// tvOS only: Select on a focused cell opens the digit chooser.
    @State private var choosingDigit = false
    #endif

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            layout
                .padding(16)
                // The overlay hid the board from sight only: VoiceOver still
                // read every cell, with actions that silently did nothing.
                .accessibilityHidden(game.phase == .paused)
                #if os(tvOS)
                // The board keeps its focusable cells while the chooser is over
                // it, so arrowing inside the chooser walked focus straight out
                // onto the hidden grid behind: the panel stayed on screen with
                // nothing in it focused and no key doing anything. Disabling the
                // board takes its cells out of the focus engine entirely for as
                // long as the chooser is up.
                .disabled(choosingDigit)
                #endif
            if game.phase == .paused {
                pauseOverlay
            }
            if winSequence != nil {
                // A tap anywhere skips the sweep straight to the sheet. Hidden
                // from VoiceOver, which gets the sheet on its own a beat later.
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { presentWinSheet() }
                    .accessibilityHidden(true)
            }
            #if os(tvOS)
            if choosingDigit {
                Color.black.opacity(0.45).ignoresSafeArea()
                DigitChooser(
                    notesMode: game.notesMode,
                    canErase: game.selected.map { game.board.entry(at: $0) != nil
                        || !game.board.notes(at: $0).isEmpty } ?? false,
                    paused: game.phase == .paused,
                    handle: { game.handle($0) },
                    onHint: { requestHint() },
                    onAutoNotes: { game.fillAutoNotes() },
                    onPause: { game.phase == .paused ? game.resume() : game.pause() },
                    close: { choosingDigit = false })
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            }
            #endif
        }
        #if os(tvOS)
        .animation(Motion.overlay, value: choosingDigit)
        #endif
        .navigationTitleDisplay(.inline)
        .swipeBackDisabled()
        .puzzleKeyboard { command in
            game.handle(command)
            if case .digit = command { Haptics.tap() }
        }
        #if !os(tvOS)
        .toolbar { toolbarContent }
        #endif
        .task(id: game.phase) {
            guard game.phase == .playing else { return }
            while !Task.isCancelled {
                game.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .onChange(of: game.phase) { _, phase in
            if phase == .won {
                progress.clearSavedGame(game.slot)
                // The daily is recorded before stats inside recordWin, so the
                // win sheet's streak line reads the updated record on its
                // first frame; a replayed daily records nothing.
                let result = progress.recordWin(
                    size: sizeOf(game.puzzle), difficulty: game.difficultyForRecords,
                    time: game.elapsed, daily: game.dailyKey)
                newBestTime = result.newBestTime
                replayOf = result.firstDailyTime
                celebrate()
            } else {
                // A hint is a look at the board, which pausing hides.
                if phase == .paused { hint = nil }
                persist()
            }
        }
        .onChange(of: game.board.entries) { old, new in
            handleEntriesChange(old: old, new: new)
        }
        // Persist as the player works. Phase changes alone are not enough: a
        // game that is started and never paused never changes phase, so quitting
        // mid-puzzle used to lose the whole board.
        .onChange(of: game.board) { _, _ in persist() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                // Pause, don't just save. `tick` adds a wall-clock delta, and
                // Task.sleep runs on a continuous clock, so without this the
                // first tick after returning folds the entire background
                // interval into `elapsed` — an overnight background added ~8
                // hours to lifetime play time and could poison a first best
                // time. Pausing clears `lastTick` and stops the timer task.
                game.pause()
                persist()
            }
        }
        // Pause as well as save: leaving via Back otherwise keeps `lastTick`
        // set, exactly the wall-clock folding the scene-phase handler above
        // exists to prevent.
        #if DEBUG
        // Eyeballing the clue sweep: fills every cell but the last with its
        // solution and selects that one, so one digit wins. DEBUG only,
        // string included.
        .onAppear {
            guard ProcessInfo.processInfo.arguments.contains("-KakuroNearlySolved"),
                  game.phase == .playing else { return }
            for pos in game.puzzle.whitePositions.sorted().dropLast()
            where game.board.entry(at: pos) == nil {
                if case .white(let solution) = game.puzzle.cells[pos.row][pos.col] {
                    game.place(solution, at: pos)
                }
            }
            game.selected = game.puzzle.whitePositions.first { game.board.entry(at: $0) == nil }
        }
        #endif
        .onDisappear {
            winSequence?.cancel()
            winSequence = nil
            sweepReset?.cancel()
            game.pause()
            persist()
        }
        .sheet(isPresented: $showWinSheet, onDismiss: {
            if let feature = pendingPaywall {
                pendingPaywall = nil
                paywall.present(feature)
            } else if game.phase == .won {
                // Done and a swipe down both end here. A swipe used to leave
                // the player on a solved board with nothing left to do.
                dismiss()
            }
        }) { winSheet }
        .sheet(item: $tappedClue) { selection in
            CombinationSheet(selection: selection) { game.remainingCombinations(for: $0) }
        }
        .safeAreaInset(edge: .bottom) {
            if let hint {
                HintBanner(hint: hint) {
                    advanceHint()
                } onApply: {
                    // Consumed by handleEntriesChange: the placement this makes
                    // is the hint's work, not the player's.
                    // Only when it really placed something: a no-op Apply
                    // left the flag set, and the player's next genuine entry
                    // then earned no mastery credit.
                    appliedHint = game.apply(hint.application)
                    self.hint = nil
                } onDismiss: {
                    self.hint = nil
                } onUnlock: {
                    paywall.present(.teachingHints)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                #if os(tvOS)
                // Its own section, so focus can leave the banner and return to
                // the board rather than being caught by whichever of its four
                // buttons happens to be nearest.
                .focusSection()
                #endif
            }
        }
        .animation(Motion.overlay, value: hint != nil)
        // Every rung, not just the first: "Tell me more" changes the text
        // in place, which VoiceOver doesn't notice on its own.
        .onChange(of: hint) { _, hint in
            guard let hint else { return }
            BoardSpeech.announce(BoardSpeech.spokenHint(hint, puzzle: game.puzzle))
        }
    }

    // MARK: - Layout

    /// Board beside the pad when the space is wider than it is tall, stacked
    /// otherwise. Keyed on the actual shape rather than the size class: an iPad
    /// in portrait is `.regular` but tall, and the side-by-side arrangement left
    /// the board using a quarter of the screen with the rest empty.
    @ViewBuilder
    private var layout: some View {
        #if os(tvOS)
        // No keypad on screen. It would be focusable, so the remote could walk
        // off the board into it, and then every digit would cost a trip across
        // the screen and back. The chooser opens where the eye already is.
        VStack(spacing: 24) {
            // Spans the full width on purpose. Capped to the reading column it
            // was narrower than the board beneath it, so pressing up from most
            // columns found nothing above and the hint controls were
            // unreachable. The focus engine looks along the direction of travel,
            // so the row has to cover every column the board occupies.
            statusRow
                .frame(maxWidth: .infinity)
            boardSection
            Text(game.selected == nil
                 ? "Move with the remote to pick a square"
                 : "Press Select to enter a digit")
                .font(.title3)
                .foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #else
        legacyLayout
        #endif
    }

    /// Hint and the overflow menu, in the content rather than the toolbar.
    ///
    /// On tvOS a toolbar is its own focus container, sitting outside the view
    /// tree the board lives in. Focus could climb into it and then had no way
    /// back down: `focusSection` on the board did not help, because the two are
    /// not in the same focus space to begin with. Rendering the controls as
    /// ordinary buttons in the same stack as the board makes up and down mean
    /// what they look like they mean.
    #if os(tvOS)
    private var tvControls: some View {
        HStack(spacing: 12) {
            Button { requestHint() } label: {
                Label("Hint", systemImage: "lightbulb")
            }
            .accessibilityLabel("Hint")
            .disabled(game.phase != .playing)
            Button { game.fillAutoNotes() } label: {
                Label("Auto notes", systemImage: "pencil.circle")
            }
            Button {
                game.phase == .paused ? game.resume() : game.pause()
            } label: {
                Label(game.phase == .paused ? "Resume" : "Pause",
                      systemImage: game.phase == .paused ? "play" : "pause")
            }
        }
        .buttonStyle(.kakuro)
    }
    #endif

    private var legacyLayout: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                HStack(spacing: 32) {
                    boardSection
                    VStack(spacing: 20) {
                        statusRow
                        NumberPadView(game: game)
                    }
                    // The cap belongs to the whole column, not just the pad.
                    // statusRow stretches to fill its width, so capping only the
                    // pad left the column expanding and pushed the keypad away
                    // from the board with the difficulty and timer strung out
                    // across the gap.
                    .frame(maxWidth: 420)
                }
                // Centred on both axes: a GeometryReader aligns its content
                // top-leading, which left a Mac window with the board jammed
                // into the top-left and the bottom half empty.
                //
                // The cap keeps the two halves together. Without it the pad
                // column expands to fill whatever is left and the board and
                // keypad drift to opposite edges of a wide window. 1120 is
                // deliberate: minus the 420 pad and 32 spacing it leaves 668 for
                // the board, which is just past what a small board can use at
                // the 88pt cell cap, so the board reaches its own limit rather
                // than being squeezed by this one.
                .frame(maxWidth: 1120)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 12) {
                    statusRow
                    // Slack above and below so the board sits optically centred
                    // in the space between status row and pad, rather than
                    // hanging off the top with a dead gap under it.
                    Spacer(minLength: 0)
                    boardSection
                    Spacer(minLength: 0)
                    NumberPadView(game: game)
                        .frame(maxWidth: Metrics.column)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    /// Grouped as a focus section on tvOS.
    ///
    /// Without it, focus that has climbed into the toolbar or dropped into the
    /// hint banner cannot get back: the engine looks for a focusable view
    /// directly along the direction of travel, and the cell it needs is usually
    /// offset, or the nearest thing below the toolbar is a black cell, which is
    /// deliberately not focusable. A section lets the engine aim at the group
    /// and land on the nearest cell inside it, and `@FocusState` still holds the
    /// cell you left, so you come back where you were.
    private var boardSection: some View {
        BoardView(game: game, highlighted: hintHighlights, sweep: sweep, winSweep: winSweep,
                  onTap: { pos in handleTap(pos) },
                  onAssistiveEdit: { pos, edit in assistiveEdit(pos, edit) },
                  onActivate: { _ in
                      #if os(tvOS)
                      choosingDigit = true
                      #endif
                  })
    }

    private var hintHighlights: Set<GridPosition> {
        hint?.visibleCells ?? []
    }

    private var statusRow: some View {
        HStack {
            Text((game.dailyKey != nil ? "Daily · " : "") + game.generated.difficulty.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(formatTime(game.elapsed))
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(Theme.inkSoft)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryTrailing) {
            Button {
                requestHint()
            } label: {
                Image(systemName: "lightbulb")
            }
            .accessibilityLabel("Hint")
            .disabled(game.phase != .playing)
        }
        ToolbarItem(placement: .primaryTrailing) {
            Menu {
                Button("Auto notes") { game.fillAutoNotes() }
                Button(game.phase == .paused ? "Resume" : "Pause") {
                    game.phase == .paused ? game.resume() : game.pause()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Interactions

    private func handleTap(_ pos: GridPosition) {
        switch game.puzzle.cells[pos.row][pos.col] {
        case .white:
            game.tap(pos)
        case .clue:
            // Tap a clue to see which digit sets still fit its run(s).
            let runs = game.puzzle.runs.filter { $0.clueCell == pos }
            guard !runs.isEmpty else { return }
            tappedClue = ClueSelection(position: pos, runs: runs)
            Haptics.note()
        case .block:
            break
        }
    }

    /// Snapshots the game unless it is finished — a won board clears its save
    /// instead, and must not resurrect it on the way out.
    /// Saves into the game's own slot, but never a board the player has not
    /// touched: opening a board and backing out used to overwrite the game
    /// waiting under Continue with an empty one. A resumed game owns its slot
    /// already, so it always saves.
    private func persist() {
        guard game.phase != .won else { return }
        progress.saveGame(game.snapshot, hasProgress: resumed || game.hasMoves)
    }

    /// Free players keep the error check ("something here is wrong"); the
    /// teaching ladder is part of the unlock.
    private var hintPolicy: HintPolicy {
        entitlements.isUnlocked ? .full : .errorsOnly
    }

    private func requestHint() {
        // Also reachable from the keyboard and the tvOS chooser.
        guard game.phase == .playing else { return }
        hint = hintEngine.hint(for: game, mastery: mastery,
                               showErrors: progress.settings.showErrors,
                               policy: hintPolicy)
    }

    private func advanceHint() {
        guard let current = hint else { return }
        guard !current.isLocked else {
            paywall.present(.teachingHints)
            return
        }
        hint = hintEngine.escalate(current, for: game, mastery: mastery, policy: hintPolicy)
    }

    private func handleEntriesChange(old: [GridPosition: Int], new: [GridPosition: Int]) {
        // Mastery: does the new entry match the pending logical step?
        let wasApplied = appliedHint
        appliedHint = false
        if new.count == old.count + 1,
           let added = new.first(where: { old[$0.key] == nil }) {
            let firstTimeHere = game.claimMasteryCredit(at: added.key)
            mastery.recordEntry(position: added.key, digit: added.value, game: game,
                                unaided: !wasApplied && firstTimeHere)
        }
        // Run-completion sweep.
        var completed: [GridPosition: Int] = [:]
        var completedRuns: [Run] = []
        for run in game.puzzle.runs where game.isRunComplete(run) {
            let wasComplete = run.cells.allSatisfy { old[$0] != nil }
            if !wasComplete {
                completedRuns.append(run)
                for (index, cell) in run.cells.enumerated() {
                    completed[cell] = index
                }
            }
        }
        if game.phase != .won,
           let spoken = BoardSpeech.entriesChanged(old: old, new: new, completed: completedRuns,
                                                   puzzle: game.puzzle) {
            BoardSpeech.announce(spoken)
        }
        // The solving move's runs are the clue sweep's to celebrate.
        if !completed.isEmpty, game.phase != .won {
            Haptics.runComplete()
            withAnimation(Motion.runComplete) { sweep = completed }
            sweepReset?.cancel()
            sweepReset = Task {
                try? await Task.sleep(for: .seconds(0.7))
                guard !Task.isCancelled else { return }
                withAnimation(Motion.runComplete) { sweep = [:] }
            }
        }
        hint = nil
    }

    /// A cell's accessibility action. Digits go through the same calls as the
    /// pad; entries are announced by `handleEntriesChange`, notes here.
    private func assistiveEdit(_ pos: GridPosition, _ edit: CellEdit) {
        guard game.phase == .playing else { return }
        switch edit {
        case .digit(let digit) where game.notesMode:
            guard game.board.entry(at: pos) == nil else {
                BoardSpeech.announce("This cell holds a digit. Clear it before adding notes.")
                return
            }
            let had = game.board.notes(at: pos).contains(digit)
            game.toggleNote(digit, at: pos)
            BoardSpeech.announce(had ? "Note \(digit) removed" : "Note \(digit) added")
        case .digit(let digit):
            game.place(digit, at: pos)
        case .clear:
            if game.board.entry(at: pos) != nil {
                game.clear(at: pos)
            } else {
                game.selected = pos
                game.clearSelected()
                BoardSpeech.announce("Notes cleared")
            }
        }
        Haptics.tap()
    }

    // MARK: - Win

    /// The solving move: the clue sweep crosses the board corner to corner,
    /// light run-complete pulses ride along with it, `.success` lands as the
    /// last cell crests, and the sheet follows. About 0.85 s on any board size,
    /// a quarter of that under Reduce Motion, where every cell fades at once.
    private func celebrate() {
        let sweepPlan = WinSweep(puzzle: game.puzzle, span: Motion.winSweepSpan,
                                 maxStagger: Motion.runCompleteStagger)
        sweep = [:]
        winSweep = sweepPlan
        let travel = reduceMotion ? 0 : sweepPlan.duration
        Haptics.runComplete()
        winSequence = Task {
            if travel > 0 {
                for _ in 0..<2 {
                    try? await Task.sleep(for: .seconds(travel / 2))
                    guard !Task.isCancelled else { return }
                    Haptics.runComplete()
                }
            }
            try? await Task.sleep(for: .seconds(Motion.winFlashUp))
            guard !Task.isCancelled else { return }
            playSuccess()
            try? await Task.sleep(for: .seconds(Motion.winSheetLead))
            guard !Task.isCancelled else { return }
            presentWinSheet()
        }
    }

    private func playSuccess() {
        guard !successPlayed else { return }
        successPlayed = true
        Haptics.win()
    }

    /// End of the sequence, or a tap that skipped it. Idempotent.
    private func presentWinSheet() {
        winSequence?.cancel()
        winSequence = nil
        playSuccess()
        guard !showWinSheet else { return }
        showWinSheet = true
        var spoken = "Solved in \(TimeFormatting.spoken(game.elapsed))"
            + (newBestTime ? ", a new best time." : ".")
        if let first = replayOf {
            spoken += " Already solved today in \(TimeFormatting.spoken(first)), so this one is not counted."
        }
        if game.dailyKey != nil {
            spoken += " \(streak) day streak."
        }
        Task {
            // After the sheet takes focus, or its own focus change
            // cuts the announcement off.
            try? await Task.sleep(for: .seconds(0.8))
            BoardSpeech.announce(spoken)
        }
    }

    /// The streak as it stands today. `currentStreak` is the stored counter,
    /// which an older daily finished late leaves untouched, so it could show a
    /// run that ended weeks ago.
    private var streak: Int {
        progress.displayStreak(today: clock.today)
    }

    /// The weekend Daily hands a free player a large board. The moment they
    /// solve it is the one moment worth making the case.
    private var offersUnlock: Bool {
        FeatureGate.shouldOfferUnlock(afterSolving: sizeOf(game.puzzle),
                                      wasDaily: game.dailyKey != nil,
                                      unlocked: entitlements.isUnlocked)
    }

    private var streakLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(Theme.indigo)
                .accessibilityHidden(true)
            Text("\(streak) day streak")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.ink)
            if progress.daily.isBestStreak(today: clock.today) {
                Text("· best")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Scrolls, with Done pinned below: a daily's streak line, a long technique
    /// recap on a large board and the weekend upsell together overflow the
    /// medium detent, which pushed Done off the bottom of the sheet.
    private var winSheet: some View {
        ScrollView {
        VStack(spacing: 20) {
            // Leads with the time: it is what the player just earned.
            VStack(spacing: 6) {
                Text(formatTime(game.elapsed))
                    .scaledDigitFont(40, relativeTo: .largeTitle)
                    .accessibilityLabel(TimeFormatting.spoken(game.elapsed))
                    .foregroundStyle(Theme.indigo)
                Text(game.dailyKey != nil ? "Daily solved" : "Solved")
                    .font(Theme.title)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                if let techniques = WinSummary.techniquesLine(
                    profile: game.generated.techniqueProfile) {
                    Text(techniques)
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
            }
            // Taken from recordSolve rather than re-derived by comparing against
            // a store that has already been updated: on an exact tie the old
            // comparison claimed a new best that was never recorded.
            if let first = replayOf {
                Text("A replay. Your daily time stays \(formatTime(first)).")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            } else if newBestTime {
                Text("New best time")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            } else if let best = progress.bestTime(size: sizeOf(game.puzzle),
                                                   difficulty: game.difficultyForRecords) {
                Text("Best: \(formatTime(best))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
            if let day = game.dailyKey {
                streakLine
                #if !os(tvOS)
                ShareLink(item: dailyShare(day).text()) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(Theme.indigo)
                #endif
            }
            TechniqueRecapView(profile: game.generated.techniqueProfile)
            if offersUnlock {
                VStack(spacing: 8) {
                    Text("That was a large board, free because it is today's Daily. Large boards are part of the full game.")
                        .font(.footnote)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                    Button("See what's included") {
                        pendingPaywall = .largeBoards
                        showWinSheet = false
                    }
                    .font(.subheadline.weight(.semibold))
                    .tint(Theme.indigo)
                }
            }
        }
        .padding([.horizontal, .top], 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Button {
                // The sheet's onDismiss leaves the game.
                showWinSheet = false
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(Theme.paper)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.indigo))
            }
            .buttonStyle(.kakuro)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(Theme.paper)
        }
        #if os(iOS)
        .presentationDetents([.medium, .large])
        #else
        .mediumSheet()
        #endif
        .presentationBackground(Theme.paper)
    }

    private var pauseOverlay: some View {
        ZStack {
            Theme.paper.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Paused")
                    .font(Theme.heading)
                    .foregroundStyle(Theme.ink)
                Button {
                    game.resume()
                } label: {
                    Text("Resume")
                        .font(.headline)
                        .foregroundStyle(Theme.paper)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Theme.indigo))
                }
                .buttonStyle(.kakuro)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    /// Spoiler-free: the day, the time of the *first* solve (a replay does
    /// not get to share a faster time), the board and the streak.
    private func dailyShare(_ day: DayKey) -> DailyShare {
        let spec = DailySeed.spec(for: day)
        return DailyShare(
            game: "Just Kakuro", day: day,
            timeText: formatTime(replayOf ?? game.elapsed),
            streak: streak,
            detail: "\(spec.size.displayName) · \(spec.difficulty.displayName)",
            url: URL(string: "https://apps.apple.com/app/id6796701026"))
    }

    private func sizeOf(_ puzzle: KakuroPuzzle) -> BoardSize {
        BoardSize.allCases.first { $0.dimension == puzzle.rows } ?? .small
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        TimeFormatting.clock(interval)
    }
}

/// Which techniques this puzzle exercised — the win screen teaches too.
struct TechniqueRecapView: View {
    let profile: [Technique: Int]

    var body: some View {
        let used = profile.filter { $0.value > 0 }.keys.sorted()
        if !used.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Techniques in this puzzle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSoft)
                ForEach(used) { technique in
                    HStack {
                        Text(technique.displayName)
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(profile[technique] ?? 0)×")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        }
    }
}
