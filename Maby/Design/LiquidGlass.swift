import SwiftUI

/// A thin compatibility layer over the system's Liquid Glass APIs.
///
/// On iOS 26 and later every surface here is a *real* `glassEffect`, so it picks up
/// the system's lensing, specular highlights and morphing for free. On earlier
/// releases we fall back to the closest thing the platform can do — a material with
/// a hairline rim and a soft shadow — so the layout and the rhythm of the app stay
/// identical and only the finish degrades.
enum GlassStyle {
    /// Standard translucent chrome. The default for cards and bars.
    case regular
    /// Translucent chrome that picks up an accent tint.
    case tinted(Color)
    /// Reacts to touch: scales and brightens under the finger.
    case interactive
    /// Tinted *and* interactive — used for primary actions.
    case interactiveTinted(Color)

    var tint: Color? {
        switch self {
        case .regular, .interactive: return nil
        case .tinted(let color), .interactiveTinted(let color): return color
        }
    }

    var isInteractive: Bool {
        switch self {
        case .interactive, .interactiveTinted: return true
        case .regular, .tinted: return false
        }
    }
}

// MARK: - Glass surfaces

extension View {
    /// Applies Liquid Glass to the view, clipped to `shape`.
    @ViewBuilder
    func liquidGlass(
        _ style: GlassStyle = .regular,
        in shape: some Shape = RoundedRectangle(cornerRadius: Radius.large, style: .continuous)
    ) -> some View {
        if #available(iOS 26.0, *) {
            var glass = Glass.regular
            if let tint = style.tint { glass = glass.tint(tint) }
            if style.isInteractive { glass = glass.interactive() }
            self.glassEffect(glass, in: shape)
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.55),
                                .white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
                }
                .overlay {
                    if let tint = style.tint {
                        shape.fill(tint.opacity(0.18))
                    }
                }
                .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        }
    }

    /// Convenience for the app's standard glass card: glass plus generous padding.
    func glassCard(
        _ style: GlassStyle = .regular,
        radius: CGFloat = Radius.large,
        padding: CGFloat = 18
    ) -> some View {
        self
            .padding(padding)
            .liquidGlass(style, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Tags a glass surface so sibling surfaces inside the same ``GlassStack`` can
    /// morph into one another instead of cross-fading.
    @ViewBuilder
    func glassMorphID(_ id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffectID(id, in: namespace)
        } else {
            self.matchedGeometryEffect(id: id, in: namespace)
        }
    }
}

/// Groups glass surfaces so that, when they move close to each other, the system
/// blends them into a single blob the way the native controls do.
struct GlassStack<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 20, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

// MARK: - Buttons

extension View {
    /// Applies the system glass button style where available, and a tasteful
    /// bordered-prominent equivalent everywhere else.
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                self.buttonStyle(.glassProminent).tint(tint ?? Palette.brand)
            } else {
                self.buttonStyle(.glass).tint(tint ?? Palette.brand)
            }
        } else {
            if prominent {
                self.buttonStyle(.borderedProminent).tint(tint ?? Palette.brand)
            } else {
                self.buttonStyle(.bordered).tint(tint ?? Palette.brand)
            }
        }
    }
}

// MARK: - Scroll & bar refinements

extension View {
    /// Lets the tab bar shrink out of the way while the user reads a long list.
    @ViewBuilder
    func minimizingTabBar() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// Softens the top scroll edge so content dissolves under the glass chrome
    /// rather than being cut off by a hard line.
    @ViewBuilder
    func softScrollEdges() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }

    /// Bleeds a hero background out under the system chrome.
    @ViewBuilder
    func extendedBackground() -> some View {
        if #available(iOS 26.0, *) {
            self.backgroundExtensionEffect()
        } else {
            self
        }
    }
}
