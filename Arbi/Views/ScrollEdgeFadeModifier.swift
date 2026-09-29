import SwiftUI

/// Shared scroll state tracking whether boundaries have been reached
public struct ScrollFadeState: Equatable, Sendable {
    public var hasScrolledFromTop: Bool = false
    public var hasMoreContentBelow: Bool = false

    public static func calculate(from geom: ScrollGeometry) -> ScrollFadeState {
        let topDistance = geom.contentOffset.y + geom.contentInsets.top
        let hasScrolledFromTop = topDistance > 4

        let visibleBottom = geom.contentOffset.y + geom.containerSize.height
        let totalBottom = geom.contentSize.height + geom.contentInsets.bottom
        let isScrollable = (geom.contentSize.height + geom.contentInsets.top + geom.contentInsets.bottom) > (geom.containerSize.height + 4)
        let bottomRemaining = totalBottom - visibleBottom
        let hasMoreContentBelow = isScrollable && (bottomRemaining > 4)

        return ScrollFadeState(
            hasScrolledFromTop: hasScrolledFromTop,
            hasMoreContentBelow: hasMoreContentBelow
        )
    }
}

/// Reusable view modifier that applies a pure visual alpha transparency mask
/// to scrollable content edges. The top fade integrates naturally under the header,
/// and the bottom fade anchors to the physical bottom edge of the screen.
public struct ScrollEdgeFadeModifier: ViewModifier {
    public var headerHeight: CGFloat
    public var fadeLength: CGFloat
    public var backgroundColor: Color

    @State private var hasScrolledFromTop: Bool = false
    @State private var hasMoreContentBelow: Bool = false

    public init(
        headerHeight: CGFloat = 0,
        fadeLength: CGFloat = 24,
        backgroundColor: Color = Color(uiColor: .systemGroupedBackground)
    ) {
        self.headerHeight = headerHeight
        self.fadeLength = fadeLength
        self.backgroundColor = backgroundColor
    }

    public func body(content: Content) -> some View {
        content
            // Detach native background so only scrollable content cells are masked
            .scrollContentBackground(.hidden)
            .mask {
                VStack(spacing: 0) {
                    if headerHeight > 0 {
                        // Region under the pinned header: content is hidden once it passes under header
                        Color.clear
                            .frame(height: headerHeight)

                        // Top fade: active only when scrolled from top
                        LinearGradient(
                            colors: [hasScrolledFromTop ? Color.clear : Color.black, Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: fadeLength)
                    } else {
                        // Direct navigation bar transition: fades only when scrolled from top
                        LinearGradient(
                            colors: [hasScrolledFromTop ? Color.clear : Color.black, Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: fadeLength)
                    }

                    // Main viewport: always 100% opaque
                    Color.black

                    // Bottom fade: anchored to physical screen bottom edge
                    LinearGradient(
                        colors: [Color.black, hasMoreContentBelow ? Color.clear : Color.black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: fadeLength)
                }
                .ignoresSafeArea(edges: .bottom)
            }
            .onScrollGeometryChange(for: ScrollFadeState.self) { geom in
                ScrollFadeState.calculate(from: geom)
            } action: { _, newState in
                withAnimation(.easeInOut(duration: 0.2)) {
                    hasScrolledFromTop = newState.hasScrolledFromTop
                    hasMoreContentBelow = newState.hasMoreContentBelow
                }
            }
    }
}

public extension View {
    /// Adds a subtle top and bottom alpha fade to scrollable content.
    /// - Parameters:
    ///   - headerHeight: Height of any sticky header content floating above the scrollable content.
    ///   - length: Height of the fade transition zone.
    ///   - backgroundColor: Screen background behind the content.
    func scrollEdgeFade(
        headerHeight: CGFloat = 0,
        length: CGFloat = 24,
        backgroundColor: Color = Color(uiColor: .systemGroupedBackground)
    ) -> some View {
        modifier(ScrollEdgeFadeModifier(
            headerHeight: headerHeight,
            fadeLength: length,
            backgroundColor: backgroundColor
        ))
    }
}
