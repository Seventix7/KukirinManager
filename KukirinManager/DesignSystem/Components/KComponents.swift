import SwiftUI

enum KAnimation {
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.82)
    static let springBouncy = Animation.spring(response: 0.45, dampingFraction: 0.65)
    static let easeOut = Animation.easeOut(duration: 0.25)
    static let fade = Animation.easeInOut(duration: 0.3)
}

struct KGradientBackground: View {
    var body: some View {
        KTheme.backgroundGradient
            .ignoresSafeArea()
    }
}

struct KCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: KTheme.cardRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: KTheme.cardShadowRadius, y: KTheme.cardShadowY)
    }
}

struct KPrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isPressed = false

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button {
            KHaptics.light()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(KTheme.accentGradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .foregroundStyle(.white)
            .scaleEffect(isPressed ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(KAnimation.spring) { isPressed = true } }
                .onEnded { _ in withAnimation(KAnimation.spring) { isPressed = false } }
        )
    }
}

struct KSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon) }
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct KSkeletonLoader: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.gray.opacity(0.2), .gray.opacity(0.35), .gray.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: phase)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 300
                }
            }
    }
}
