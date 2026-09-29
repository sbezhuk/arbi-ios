import SwiftUI

/// Shared scroll state tracking whether boundaries have been reached
public struct ScrollFadeState: Equatable, Sendable {
    public var hasScrolledFromTop: Bool = false
    public var hasMoreContentBelow: Bool = false
    public var contentOffsetY: CGFloat = 0
    public var contentInsetTop: CGFloat = 0

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
            hasMoreContentBelow: hasMoreContentBelow,
            contentOffsetY: geom.contentOffset.y,
            contentInsetTop: geom.contentInsets.top
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
    public var enableTopFade: Bool

    @State private var hasScrolledFromTop: Bool = false
    @State private var hasMoreContentBelow: Bool = false
    @State private var contentOffsetY: CGFloat = 0
    @State private var contentInsetTop: CGFloat = 0

    public init(
        headerHeight: CGFloat = 0,
        fadeLength: CGFloat = 24,
        backgroundColor: Color = Color(uiColor: .systemGroupedBackground),
        enableTopFade: Bool = true
    ) {
        self.headerHeight = headerHeight
        self.fadeLength = fadeLength
        self.backgroundColor = backgroundColor
        self.enableTopFade = enableTopFade
    }

    public func body(content: Content) -> some View {
        content
            // Detach native background so only scrollable content cells are masked
            .scrollContentBackground(.hidden)
            .mask {
                if enableTopFade {
                    GeometryReader { proxy in
                        let safeAreaTop = proxy.safeAreaInsets.top
                        let collapsedHeight = safeAreaTop > 0 ? safeAreaTop : max(0, contentInsetTop - 52)
                        let navBottom: CGFloat = headerHeight > 0 ? headerHeight : max(collapsedHeight, -contentOffsetY)

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
                                // Native navigation bar region: always 100% solid black (opaque)
                                // so no part of the navigation bar, large title, or toolbar is ever masked
                                Color.black
                                    .frame(height: navBottom)

                                // Dynamic top fade: anchored to current bottom edge of native navigation bar
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
                } else {
                    VStack(spacing: 0) {
                        // Main viewport: 100% opaque from the very top edge, letting native navigation bar handle top transitions
                        Color.black

                        // Bottom fade: anchored to physical screen bottom edge
                        LinearGradient(
                            colors: [Color.black, hasMoreContentBelow ? Color.clear : Color.black],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: fadeLength)
                    }
                    .ignoresSafeArea()
                }
            }
            .background(backgroundColor.ignoresSafeArea())
            .onScrollGeometryChange(for: ScrollFadeState.self) { geom in
                ScrollFadeState.calculate(from: geom)
            } action: { _, newState in
                contentOffsetY = newState.contentOffsetY
                contentInsetTop = newState.contentInsetTop
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
    ///   - enableTopFade: Whether to enable top edge fading (set false when native navigation bar handles top transition).
    func scrollEdgeFade(
        headerHeight: CGFloat = 0,
        length: CGFloat = 24,
        backgroundColor: Color = Color(uiColor: .systemGroupedBackground),
        enableTopFade: Bool = true
    ) -> some View {
        modifier(ScrollEdgeFadeModifier(
            headerHeight: headerHeight,
            fadeLength: length,
            backgroundColor: backgroundColor,
            enableTopFade: enableTopFade
        ))
    }

    /// Applies a bottom-only alpha fade to scrollable content, allowing screens with native
    /// collapsing navigation bars to handle the top scrolling transition natively.
    func bottomScrollFade(
        length: CGFloat = 24,
        backgroundColor: Color = Color(uiColor: .systemGroupedBackground)
    ) -> some View {
        scrollEdgeFade(
            headerHeight: 0,
            length: length,
            backgroundColor: backgroundColor,
            enableTopFade: false
        )
    }
}
