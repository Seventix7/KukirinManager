import SwiftUI

enum KTheme {
    static let cardRadius: CGFloat = 20
    static let cardShadowRadius: CGFloat = 12
    static let cardShadowY: CGFloat = 4

    static let accentGradient = LinearGradient(
        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(.systemBackground),
            Color.accentColor.opacity(0.06),
            Color(.systemBackground)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let heroFont = Font.system(size: 72, weight: .bold, design: .rounded)
    static let metricFont = Font.system(size: 28, weight: .semibold, design: .rounded)
    static let captionFont = Font.system(.caption, design: .rounded)
}

enum KHaptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
