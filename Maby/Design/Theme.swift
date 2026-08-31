import SwiftUI

// MARK: - Dynamic color helper

extension Color {
    /// Builds a color that resolves differently in light and dark appearance.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255,
            blue: CGFloat(rgb & 0x0000FF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Palette

/// The app's semantic palette. Every color resolves for both appearances so that
/// glass surfaces stay legible whichever way the system leans.
enum Palette {
    // Brand
    static let brand = Color.adaptive(light: 0x6C4BF6, dark: 0x9E86FF)
    static let brandDeep = Color.adaptive(light: 0x4B2ED8, dark: 0x7458FF)
    static let brandSoft = Color.adaptive(light: 0xEFEAFF, dark: 0x241C46)

    // Surfaces
    static let canvas = Color.adaptive(light: 0xF7F5FF, dark: 0x0D0B18)
    static let hairline = Color.adaptive(light: 0xE4DEF6, dark: 0x2E2846)

    // Text
    static let ink = Color.adaptive(light: 0x1A1330, dark: 0xF4F1FF)
    static let inkSoft = Color.adaptive(light: 0x6B6382, dark: 0xA49CC0)

    // Accents used by the aurora background
    static let auroraA = Color.adaptive(light: 0xFFB4C6, dark: 0x6B2B57)
    static let auroraB = Color.adaptive(light: 0x9FD8FF, dark: 0x1E4C79)
    static let auroraC = Color.adaptive(light: 0xCDB6FF, dark: 0x40308C)
    static let auroraD = Color.adaptive(light: 0xFFE0A3, dark: 0x6B4E1C)

    // Pro / premium
    static let gold = Color.adaptive(light: 0xC98A16, dark: 0xF3C766)
}

// MARK: - Event styling

/// Everything the UI needs to render one kind of event consistently: the emoji we
/// have always used, an SF Symbol for the places where an emoji would look out of
/// place, and the tint that identifies the category at a glance.
struct EventStyle {
    let title: String
    let emoji: String
    let symbol: String
    let tint: Color
    let gradient: [Color]

    static let nursing = EventStyle(
        title: "Nursing",
        emoji: "🤱",
        symbol: "heart.circle.fill",
        tint: Color.adaptive(light: 0xE0568C, dark: 0xFF8FB8),
        gradient: [
            Color.adaptive(light: 0xFF8FB8, dark: 0xC2447A),
            Color.adaptive(light: 0xE0568C, dark: 0x8E2F58)
        ]
    )

    static let bottle = EventStyle(
        title: "Bottle",
        emoji: "🍼",
        symbol: "waterbottle.fill",
        tint: Color.adaptive(light: 0x2E86C8, dark: 0x74C0F5),
        gradient: [
            Color.adaptive(light: 0x74C0F5, dark: 0x2A6EA6),
            Color.adaptive(light: 0x2E86C8, dark: 0x1B4B75)
        ]
    )

    static let diaper = EventStyle(
        title: "Diaper",
        emoji: "🧷",
        symbol: "drop.circle.fill",
        tint: Color.adaptive(light: 0x1E9E86, dark: 0x5FD9C0),
        gradient: [
            Color.adaptive(light: 0x5FD9C0, dark: 0x1B8874),
            Color.adaptive(light: 0x1E9E86, dark: 0x11604F)
        ]
    )

    static let sleep = EventStyle(
        title: "Sleep",
        emoji: "🌙",
        symbol: "moon.stars.fill",
        tint: Color.adaptive(light: 0x5B54C4, dark: 0x9C95FF),
        gradient: [
            Color.adaptive(light: 0x9C95FF, dark: 0x4F48B4),
            Color.adaptive(light: 0x5B54C4, dark: 0x2F2A78)
        ]
    )

    static let vomit = EventStyle(
        title: "Spit-up",
        emoji: "🤢",
        symbol: "exclamationmark.triangle.fill",
        tint: Color.adaptive(light: 0x8A7A2E, dark: 0xD6C36B),
        gradient: [
            Color.adaptive(light: 0xD6C36B, dark: 0x8A7A2E),
            Color.adaptive(light: 0x8A7A2E, dark: 0x584D1C)
        ]
    )

    static let timer = EventStyle(
        title: "Timer",
        emoji: "⏱️",
        symbol: "timer",
        tint: Color.adaptive(light: 0xD1622B, dark: 0xFFA173),
        gradient: [
            Color.adaptive(light: 0xFFA173, dark: 0xC25C29),
            Color.adaptive(light: 0xD1622B, dark: 0x8A3D18)
        ]
    )
}

// MARK: - Shape tokens

enum Radius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 20
    static let large: CGFloat = 28
    static let capsule: CGFloat = 999
}
