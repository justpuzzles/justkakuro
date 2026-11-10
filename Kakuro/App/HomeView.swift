import SwiftUI

/// Home: wordmark with the diagonal signature, continue card, new game,
/// and the learning path.
struct HomeView: View {
    @Binding var path: [Route]
    @Environment(ProgressStore.self) private var progress
    @Environment(MasteryTracker.self) private var mastery
    @Environment(PuzzleCache.self) private var cache
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(TodayClock.self) private var clock

    @State private var newGameSize: BoardSize = .small
    @State private var newGameDifficulty: Difficulty = .easy
    @State private var showNewGame = false
    /// Play while a standard game is saved asks first: the new board takes
    /// that slot as soon as the player makes a move on it.
    @State private var confirmingNewGame = false
    /// Today's daily over an unfinished one from an earlier day: the daily
    /// slot holds one game, so ask, as Play does for the standard slot.
    @State private var confirmingDaily: DayKey?
    /// Suppresses the size gate while the pickers are being restored — see
    /// `restorePickers()`.
    @State private var isRestoring = false
    @State private var didRestore = false
    #if os(tvOS)
    /// Where the remote should be pointing when Home appears. Without this the
    /// focus engine picks the first control it finds, which is the Size picker:
    /// a poor greeting, and it made every keypress sequence unpredictable.
    @FocusState private var homeFocus: HomeFocus?
    private enum HomeFocus: Hashable { case daily, resume, resumeDaily, play }
    #endif

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    wordmark
                        .padding(.top, 24)

                    // From the observable clock, not `DayKey(date: .now)`: a
                    // body only re-runs when something it reads changes, so
                    // 1.1's Home left open overnight kept yesterday's daily.
                    let today = clock.today
                    DailyCard(today: today) { openDaily(today) }
                        #if os(tvOS)
                        .focused($homeFocus, equals: .daily)
                        #endif

                    if let saved = progress.savedGame(.standard) {
                        continueCard(.standard, saved)
                    }
                    // Today's daily resumes from the Daily card. An unfinished
                    // daily from an earlier day has nowhere else to go.
                    if let saved = progress.savedGame(.daily), let day = saved.dailyKey,
                       day != today, !progress.hasCompletedDaily(day) {
                        continueCard(.daily, saved)
                    }

                    if progress.showsIntro {
                        introCard
                    }

                    newGameCard

                    HStack(spacing: 12) {
                        menuTile(title: "Learn", symbol: "book", route: .learn)
                        menuTile(title: "Practice", symbol: "target", route: .practiceMenu)
                    }
                    HStack(spacing: 12) {
                        // Open to everyone: the Daily streak panel is free, and
                        // StatsView locks the rest in place.
                        menuTile(title: "Stats", symbol: "chart.bar", route: .stats)
                        menuTile(title: "Settings", symbol: "gearshape", route: .settings)
                    }
                }
                .padding(20)
                .frame(maxWidth: Metrics.column)
                .frame(maxWidth: .infinity)
                // Centre the column when it is shorter than the window instead
                // of hanging it off the top. A phone screen is roughly the
                // height of this content so it changes little there, but a Mac
                // window is any height at all, and top-aligned left a band of
                // dead space under the tiles.
                .frame(minHeight: proxy.size.height)
            }
            }
        }
        // Home draws its own title, so the bar would only add a second one.
        // There is no window-toolbar equivalent to hide on macOS: the window has
        // no toolbar to begin with.
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .task {
            guard !didRestore else { return }
            didRestore = true
            restorePickers()
            // .onChange does not fire on first appear, so this seeding call is
            // what actually warms the key the pickers point at.
            cache.warm(size: newGameSize, difficulty: newGameDifficulty)
        }
    }

    /// Opens today's daily. If the daily slot holds this day, resume it instead
    /// of generating the board again and losing the player's progress on it.
    private func openDaily(_ day: DayKey) {
        if let saved = progress.savedGame(.daily), saved.dailyKey == day,
           !progress.hasCompletedDaily(day) {
            path.append(.resume(.daily))
        } else if let earlier = progress.savedGame(.daily)?.dailyKey, earlier != day,
                  !progress.hasCompletedDaily(earlier), !progress.hasCompletedDaily(day) {
            confirmingDaily = earlier
        } else {
            path.append(.daily(day))
        }
    }

    /// Restores the pickers to the last game played.
    ///
    /// `isRestoring` is load-bearing: assigning `newGameSize` fires the size
    /// gate below, and at launch `entitlements.isUnlocked` is still false while
    /// StoreKit resolves — so a *paying* customer whose last game was large
    /// would be shown a paywall the moment the app opened.
    private func restorePickers() {
        guard let choice = progress.lastPlayed else { return }
        isRestoring = true
        defer { isRestoring = false }
        // Still respect the gate. Someone who does not own large simply keeps
        // the default size — quietly, with no sheet.
        if FeatureGate.isSizeAvailable(choice.size, unlocked: entitlements.isUnlocked) {
            newGameSize = choice.size
        }
        newGameDifficulty = choice.difficulty
    }

    /// The wordmark: serif title crossed by the clue-cell diagonal.
    private var wordmark: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Whole-lockup fitting rather than minimumScaleFactor: the two Texts
            // would otherwise each pick their own scale and drift apart, taking
            // the diagonal off the K with them.
            ViewThatFits(in: .horizontal) {
                lockup(fontSize: Metrics.wordmark[0])
                lockup(fontSize: Metrics.wordmark[1])
                lockup(fontSize: Metrics.wordmark[2])
            }
            Text("The crossword of sums")
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    /// "Just Kakuro" with the clue-cell diagonal struck through the K. The
    /// diagonal is an overlay on the "Kakuro" Text, so it tracks that word
    /// wherever the prefix puts it — the old version anchored to the whole
    /// string's bottom-leading and slid onto the J when the name changed.
    /// Every diagonal measurement is a fraction of `fontSize` so the candidates
    /// stay internally consistent.
    private func lockup(fontSize: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text(verbatim: "Just")
                .padding(.trailing, fontSize * 0.22)
            Text(verbatim: "Kakuro")
                .overlay(alignment: .bottomLeading) {
                    // Anchored to the Text's bottom edge, which sits a descender
                    // below the baseline — hence the negative y, which lifts the
                    // stroke back into the K instead of trailing into the subtitle.
                    DiagonalLine()
                        .stroke(Theme.indigo,
                                style: StrokeStyle(lineWidth: fontSize / 22, lineCap: .round))
                        .frame(width: fontSize * 0.62, height: fontSize * 0.55)
                        .offset(x: -fontSize * 0.09, y: -fontSize * 0.16)
                }
        }
        .font(.system(size: fontSize, weight: .bold, design: .serif))
        .foregroundStyle(Theme.ink)
        .lineLimit(1)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Just Kakuro")
    }

    private func continueCard(_ slot: GameSlot, _ snapshot: KakuroGame.Snapshot) -> some View {
        Button {
            path.append(.resume(slot))
        } label: {
            CardRow {
                VStack(alignment: .leading, spacing: 4) {
                    Text(slot == .daily ? "Continue daily" : "Continue")
                        .font(Theme.heading)
                        .foregroundStyle(Theme.ink)
                    Text(continueDetail(snapshot))
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    // Doubled on tvOS with the other glyphs (Metrics.glyph).
                    .scaledFont(18 * Metrics.glyph / 13, weight: .medium)
                    .foregroundStyle(Theme.indigo)
                    .accessibilityHidden(true)
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
        }
        .buttonStyle(.kakuro)
        #if os(tvOS)
        .focused($homeFocus, equals: slot == .daily ? .resumeDaily : .resume)
        #endif
    }

    /// First run: the app's pitch is that it teaches Kakuro, so someone who
    /// does not know the rules is pointed at them instead of a board they
    /// cannot read.
    private var introCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                progress.markIntroSeen()
                path.append(.tutorial(nil))
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("New to Kakuro?")
                        .font(Theme.heading)
                        .foregroundStyle(Theme.ink)
                    Text("Learn the rules in two minutes, on a real board.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Start the lesson")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.indigo)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.kakuro)
            .accessibilityIdentifier("introCard")
            Button {
                withAnimation(Motion.overlay) { progress.markIntroSeen() }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: Metrics.glyph, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.kakuro)
            .accessibilityLabel("Dismiss")
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
    }

    private func continueDetail(_ snapshot: KakuroGame.Snapshot) -> String {
        let difficulty = (snapshot.requestedDifficulty ?? snapshot.generated.difficulty).displayName
        let time = formatTime(snapshot.elapsed)
        if let day = snapshot.dailyKey {
            let date = day.date().formatted(.dateTime.month(.abbreviated).day())
            return "\(date) · \(difficulty) · \(time)"
        }
        return "\(difficulty) · \(time)"
    }

    private func startNewGame() {
        // No prefetch here — the selection is already warm, and the
        // loader claims that entry rather than racing it.
        path.append(.game(size: newGameSize, difficulty: newGameDifficulty))
    }

    /// Quiet row label, matching the secondary-text treatment used for the
    /// status row and the Settings subtitles.
    private func rowLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.inkSoft)
    }

    private var newGameCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New game")
                .font(Theme.heading)
                .foregroundStyle(Theme.ink)
            // A Grid, so both rows share one label column and the two segmented
            // controls start at the same x. iOS discards a segmented picker's
            // title, which is why this read fine there while macOS, which draws
            // the title as a leading label, staggered them by the difference
            // between "Size" and "Difficulty".
            //
            // The labels are worth their space on both platforms: each row has a
            // segment called Medium, meaning two different things, so without
            // them the pair is genuinely ambiguous.
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    rowLabel("Size")
                    Picker("Size", selection: $newGameSize) {
                        ForEach(BoardSize.allCases) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    // Fill the column so both controls end where Play does.
                    // macOS sizes a segmented picker to its content, which left
                    // them stopping short of the card's right edge. tvOS is the
                    // opposite problem: stretched across a 1100pt column each
                    // segment became 300pt wide, so there it keeps its own size.
                    .frame(maxWidth: Metrics.stretchesSegments ? .infinity : nil)
                    // A Grid hands its column all the width going, and a
                    // segmented picker takes whatever it is offered, so on
                    // tvOS the segments spread to 300pt each. fixedSize is
                    // what actually stops it; capping maxWidth does not.
                    .fixedSize(horizontal: !Metrics.stretchesSegments, vertical: false)
                }
                GridRow {
                    rowLabel("Difficulty")
                    Picker("Difficulty", selection: $newGameDifficulty) {
                        ForEach(Difficulty.allCases) { difficulty in
                            Text(difficulty.displayName).tag(difficulty)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    // Fill the column so both controls end where Play does.
                    // macOS sizes a segmented picker to its content, which left
                    // them stopping short of the card's right edge. tvOS is the
                    // opposite problem: stretched across a 1100pt column each
                    // segment became 300pt wide, so there it keeps its own size.
                    .frame(maxWidth: Metrics.stretchesSegments ? .infinity : nil)
                    // A Grid hands its column all the width going, and a
                    // segmented picker takes whatever it is offered, so on
                    // tvOS the segments spread to 300pt each. fixedSize is
                    // what actually stops it; capping maxWidth does not.
                    .fixedSize(horizontal: !Metrics.stretchesSegments, vertical: false)
                }
            }
            Button {
                if progress.savedGame(.standard) != nil {
                    confirmingNewGame = true
                } else {
                    startNewGame()
                }
            } label: {
                Text("Play")
                    .font(.headline)
                    .foregroundStyle(Theme.paper)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.indigo))
            }
            .buttonStyle(.kakuro)
            #if os(tvOS)
            .focused($homeFocus, equals: .play)
            #endif
            .confirmationDialog("Start today's Daily?",
                                isPresented: Binding(get: { confirmingDaily != nil },
                                                     set: { if !$0 { confirmingDaily = nil } }),
                                titleVisibility: .visible) {
                Button("Today's Daily") { path.append(.daily(clock.today)) }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let earlier = confirmingDaily {
                    Text("Your unfinished Daily from \(earlier.date().formatted(.dateTime.month(.wide).day())) is replaced once you enter something on today's.")
                }
            }
            .confirmationDialog("Start a new game?", isPresented: $confirmingNewGame,
                                titleVisibility: .visible) {
                Button("New game", role: .destructive) { startNewGame() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your game in progress is replaced once you enter something on the new board.")
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
        .onChange(of: newGameSize) { previous, size in
            guard !isRestoring else { return }
            // Snap back rather than hide the segment — a hidden feature can't be
            // sold. The warm must stay inside the guard: building a large board
            // costs seconds of CPU for a puzzle they can't open.
            guard FeatureGate.isSizeAvailable(size, unlocked: entitlements.isUnlocked) else {
                newGameSize = previous
                paywall.present(.largeBoards)
                return
            }
            cache.warm(size: size, difficulty: newGameDifficulty)
        }
        .onChange(of: newGameDifficulty) { _, difficulty in
            guard !isRestoring else { return }
            cache.warm(size: newGameSize, difficulty: difficulty)
        }
    }

    private func menuTile(title: String, symbol: String, route: Route,
                          lockedBehind feature: PaidFeature? = nil) -> some View {
        let paywalled = feature.map { !FeatureGate.isAvailable($0, unlocked: entitlements.isUnlocked) }
            ?? false
        return Button {
            if let feature, paywalled {
                paywall.present(feature)
            } else {
                path.append(route)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .scaledFont(22, weight: .medium, relativeTo: .title2)
                    .foregroundStyle(Theme.indigo)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
            }
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(alignment: .topTrailing) {
                if paywalled {
                    Image(systemName: "lock.fill")
                        .font(.system(size: Metrics.glyph, weight: .semibold))
                        .foregroundStyle(Theme.indigo)
                        .padding(10)
                }
            }
        }
        .buttonStyle(.kakuro)
        .accessibilityValue(paywalled ? "Locked, part of the full game" : "")
    }

    private func formatTime(_ interval: TimeInterval) -> String {
        TimeFormatting.clock(interval)
    }
}
