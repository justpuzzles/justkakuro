import SwiftUI

/// Named motion tokens — views never use inline animation values.
///
/// `nonisolated` for the same reason as `Theme`: under
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` these would be MainActor-isolated
/// statics read during off-main render passes. Nothing here is implicated in the
/// crash `Theme` caused — no closure escapes to UIKit — but every member is a
/// `Sendable` value type, so this costs nothing and keeps the design tokens
/// uniformly safe to read from any isolation domain.
nonisolated enum Motion {
    /// Snappy spring for digit entry (scale 1.12 → 1.0).
    static let digitEntry = Animation.spring(response: 0.25, dampingFraction: 0.7)
    /// Note toggles and small state flips.
    static let noteFlip = Animation.spring(response: 0.2, dampingFraction: 0.8)
    /// Selection movement.
    static let selection = Animation.spring(response: 0.28, dampingFraction: 0.85)
    /// Run-completion sweep: per-cell stagger in seconds.
    static let runCompleteStagger: TimeInterval = 0.04
    static let runComplete = Animation.easeOut(duration: 0.35)
    /// Board entrance: staggered fade-up.
    static let boardEntrance = Animation.spring(response: 0.5, dampingFraction: 0.85)
    static let boardEntranceStagger: TimeInterval = 0.012
    /// Hint highlight pulse.
    static let hintPulse = Animation.easeInOut(duration: 0.6).repeatCount(2, autoreverses: true)
    /// Win clue sweep: how long the diagonal wave takes to cross the board,
    /// whatever its size. Per-step stagger is capped at `runCompleteStagger`.
    static let winSweepSpan: TimeInterval = 0.55
    /// One cell's flash: up to the crest, then back down to the solved rest tint.
    static let winFlashUp: TimeInterval = 0.16
    static let winFlashDown: TimeInterval = 0.4
    /// Crest strength of the flash, and the tint the board settles at.
    static let winFlashPeak: Double = 0.45
    static let winRestTint: Double = 0.18
    static let winSettle = Animation.easeOut(duration: winFlashDown)
    /// Pause between the `.success` haptic and the win sheet.
    static let winSheetLead: TimeInterval = 0.12
    /// Sheet/overlay transitions.
    static let overlay = Animation.spring(response: 0.35, dampingFraction: 0.9)
}
