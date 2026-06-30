import SwiftUI

/// Shared animation and transition helpers for ProMotion-friendly UI.
extension AnyTransition {
    static var kukirinSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    static var kukirinFade: AnyTransition {
        .opacity.animation(KAnimation.fade)
    }
}

struct MatchedHeroModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        content.matchedGeometryEffect(id: id, in: namespace)
    }
}

extension View {
    func matchedHero(id: String, in namespace: Namespace.ID) -> some View {
        modifier(MatchedHeroModifier(id: id, in: namespace))
    }
}
