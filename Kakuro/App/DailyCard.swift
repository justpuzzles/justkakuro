import SwiftUI

/// The daily puzzle on Home: today's size and difficulty, the streak, and a
/// solved seal with the time once it is done. Free at every size — see
/// `FeatureGate.isDailyAvailable`.
struct DailyCard: View {
    let today: DayKey
    let onPlay: () -> Void
    @Environment(ProgressStore.self) private var progress

    /// The badge, arrow and seal are fixed sizes tuned for a phone; on tvOS
    /// they scale with `Metrics.glyph` so they read from the sofa.
    private let k = Metrics.glyph / 13

    private var spec: (size: BoardSize, difficulty: Difficulty) {
        DailySeed.spec(for: today)
    }

    var body: some View {
        Button(action: onPlay) {
            CardRow {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily")
                        .font(Theme.heading)
                        .foregroundStyle(Theme.ink)
                    Text("\(spec.size.displayName) · \(spec.difficulty.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                if let time = progress.dailyTime(today) {
                    doneSeal(time)
                } else {
                    streakBadge
                }
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.indigo.opacity(0.35), lineWidth: 1.5)
            )
        }
        .buttonStyle(.kakuro)
        // A label on the Button itself, not `.accessibilityElement(children:
        // .ignore)`: that replaces the button's element with one that has no
        // press action, so VoiceOver on the Mac could not open the Daily.
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("dailyCard")
    }

    @ViewBuilder
    private var streakBadge: some View {
        let streak = progress.displayStreak(today: today)
        HStack(spacing: 6) {
            if streak > 0 {
                Image(systemName: "flame.fill")
                    .scaledFont(17 * k, weight: .semibold)
                    .foregroundStyle(Theme.indigo)
                Text("\(streak)")
                    .scaledDigitFont(18 * k)
                    .foregroundStyle(Theme.ink)
            }
            Image(systemName: "arrow.right")
                .scaledFont(18 * k, weight: .medium)
                .foregroundStyle(Theme.indigo)
        }
    }

    /// Solved today: the time beside a clue-cell seal — the board's own
    /// diagonal, so the mark is Kakuro's rather than a generic checkmark.
    private func doneSeal(_ time: TimeInterval) -> some View {
        HStack(spacing: 10) {
            Text(TimeFormatting.clock(time))
                .scaledDigitFont(16 * k)
                .foregroundStyle(Theme.inkSoft)
            ZStack {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Theme.block)
                DiagonalLine()
                    .stroke(Theme.clueText, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .padding(5)
                Image(systemName: "checkmark")
                    .font(.system(size: 11 * k, weight: .bold))
                    .foregroundStyle(Theme.clueText)
                    .offset(x: 5 * k, y: -5 * k)
            }
            .frame(width: 28 * k, height: 28 * k)
        }
    }

    private var accessibilityText: String {
        let what = "Daily puzzle, \(spec.size.displayName) \(spec.difficulty.displayName)"
        if let time = progress.dailyTime(today) {
            return "\(what), solved in \(TimeFormatting.spoken(time))"
        }
        let streak = progress.displayStreak(today: today)
        if progress.streakIsAtRisk(today: today) {
            return "\(what), \(streak) day streak, solve today to keep it"
        }
        return streak > 0 ? "\(what), \(streak) day streak" : what
    }
}
