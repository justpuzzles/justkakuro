import SwiftUI

@main
struct KakuroApp: App {
    @State private var progress: ProgressStore
    @State private var mastery: MasteryTracker
    @State private var cache = PuzzleCache()
    @State private var entitlements: EntitlementStore
    @State private var paywall = PaywallPresenter()
    /// Today's day key for every screen, kept current across midnight.
    @State private var clock = TodayClock()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        // UI tests and accessibility audits start from a fresh install, or
        // they inherit a saved game and stray state. DEBUG only, string
        // included, like the unlock flag below.
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetState"),
           let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }
        #endif
        let store = ProgressStore()
        _progress = State(initialValue: store)
        _mastery = State(initialValue: MasteryTracker(store: store))
        _entitlements = State(initialValue: Self.makeEntitlementStore())
    }

    /// Real StoreKit, except when capturing App Store screenshots of the paid
    /// tier, which cannot be reached in a simulator without a live purchase.
    ///
    /// Wrapped in `#if DEBUG` deliberately: a launch argument that grants the
    /// unlock must not exist in the binary that ships. `ReleaseBuildTests`
    /// checks the flag string is absent from a Release build.
    private static func makeEntitlementStore() -> EntitlementStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(Self.screenshotUnlockFlag) {
            return EntitlementStore(source: PreviewEntitlementSource(owned: true))
        }
        #endif
        return EntitlementStore()
    }

    static let screenshotUnlockFlag = "-KakuroScreenshotUnlock"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(progress)
                .environment(mastery)
                .environment(cache)
                .environment(entitlements)
                .environment(paywall)
                .environment(clock)
                .onAppear {
                    Haptics.enabled = progress.settings.hapticsEnabled
                }
                // Tall enough for the stacked phone layout to stay the sensible
                // one at the default size, and wide enough that widening the
                // window is what switches to board-beside-pad.
                #if os(macOS)
                .frame(minWidth: 620, minHeight: 640)
                #endif
        }
        // No day-change notification reaches a suspended app, so a phone
        // unlocked the next morning would still be on yesterday.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { clock.refresh() }
        }
        #if os(macOS)
        .defaultSize(width: 720, height: 820)
        .windowResizability(.contentMinSize)
        #endif
        #if os(visionOS)
        // A visionOS window opens very wide by default, which left the 560pt
        // reading column stranded in the middle of a large dark slab with empty
        // margins either side. Sized to the content instead, so the window is
        // the app rather than a backdrop for it. Taller than wide keeps the
        // stacked board-over-keypad arrangement, which suits a window you look
        // at head-on.
        .defaultSize(width: 760, height: 900)
        #endif
    }
}
