import SwiftUI

/// Digit input: 9 keys plus notes toggle and erase. Long-press (or the toggle)
/// switches to note entry; tapping a key with nothing selected highlights that
/// digit on the board.
struct NumberPadView: View {
    let game: KakuroGame

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 5)

    var body: some View {
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...9, id: \.self) { digit in
                    digitKey(digit)
                }
                controlKey(
                    symbol: game.notesMode ? "pencil.circle.fill" : "pencil.circle",
                    label: "Notes",
                    active: game.notesMode
                ) {
                    game.notesMode.toggle()
                    Haptics.note()
                }
            }
            HStack(spacing: 8) {
                wideControlKey(symbol: "arrow.uturn.backward", label: "Undo", enabled: game.canUndo) {
                    game.undo()
                    Haptics.note()
                }
                wideControlKey(symbol: "eraser", label: "Erase", enabled: game.selected != nil) {
                    game.clearSelected()
                    Haptics.note()
                }
            }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        Button {
            if game.selected != nil {
                game.enter(digit)
                Haptics.tap()
            } else {
                game.highlightedDigit = game.highlightedDigit == digit ? nil : digit
                Haptics.note()
            }
        } label: {
            Text("\(digit)")
                .font(Theme.digitFont(size: 24))
                .foregroundStyle(game.highlightedDigit == digit ? Theme.paper : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(game.highlightedDigit == digit ? Theme.indigo : Theme.surface)
                )
        }
        .buttonStyle(.kakuro)
        .accessibilityLabel("\(digit)")
        .accessibilityAddTraits(game.highlightedDigit == digit ? .isSelected : [])
        .accessibilityHint(game.selected == nil ? "Shows where \(digit) can go" : "")
    }

    private func controlKey(symbol: String, label: String, active: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                // Scales with Dynamic Type, capped so the key keeps its height
                // beside the digits (which are sized to their keys on purpose,
                // docs/ACCESSIBILITY.md).
                .scaledFont(20, weight: .medium, relativeTo: .title3)
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .foregroundStyle(active ? Theme.paper : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(active ? Theme.indigo : Theme.surface)
                )
        }
        .buttonStyle(.kakuro)
        .accessibilityLabel(label)
        .accessibilityValue(active ? "On" : "Off")
    }

    private func wideControlKey(symbol: String, label: String, enabled: Bool,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol)
                .font(.system(.subheadline, weight: .medium))
                .foregroundStyle(enabled ? Theme.ink : Theme.inkSoft)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Theme.surface)
                )
        }
        .buttonStyle(.kakuro)
        .disabled(!enabled)
    }
}
