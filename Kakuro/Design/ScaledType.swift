import SwiftUI

/// A fixed-size system font that still follows Dynamic Type.
///
/// `Font.system(size:)` ignores the user's text size. Counters, times and
/// combination digits were drawn that way; `@ScaledMetric` scales the size
/// with the text style it sits next to.
private struct ScaledSystemFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo style: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

extension View {
    func scaledFont(_ size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default,
                    relativeTo style: Font.TextStyle = .body) -> some View {
        modifier(ScaledSystemFont(size: size, weight: weight, design: design, relativeTo: style))
    }

    /// The serif numeral (`Theme.digitFont`), scaled.
    func scaledDigitFont(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> some View {
        scaledFont(size, weight: .semibold, design: .serif, relativeTo: style)
    }
}

/// A row that stacks at accessibility text sizes, where an icon or arrow
/// beside the text would squeeze it to a word per line.
struct CardRow<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var typeSize
    @ViewBuilder let content: () -> Content

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout())
        layout { content() }
    }
}
