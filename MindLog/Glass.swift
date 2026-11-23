import SwiftUI

#if compiler(>=6.2)
@available(iOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var g = Glass.regular
    if let tint { g = g.tint(tint) }
    if interactive { g = g.interactive() }
    return g
}
#endif

extension View {
    /// Liquid Glass на iOS 26+, на старых iOS — матовое стекло (material).
    @ViewBuilder
    func liquidGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            self.glassFallback(in: shape, tint: tint)
        }
        #else
        self.glassFallback(in: shape, tint: tint)
        #endif
    }

    fileprivate func glassFallback<S: Shape>(in shape: S, tint: Color?) -> some View {
        self
            .background((tint ?? Color.clear).opacity(tint == nil ? 0 : 0.35), in: shape)
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.14), lineWidth: 0.75))
    }
}

/// Тёмный фон с цветными размытыми пятнами — под стеклом они красиво преломляются.
struct AppBackground: View {
    var tint: Color = Valence.color(0)

    var body: some View {
        ZStack {
            Color.black
            Circle().fill(tint.opacity(0.55)).frame(width: 340, height: 340)
                .blur(radius: 90).offset(x: -120, y: -260)
            Circle().fill(tint.opacity(0.30)).frame(width: 300, height: 300)
                .blur(radius: 100).offset(x: 140, y: 120)
            Circle().fill(Color.indigo.opacity(0.25)).frame(width: 280, height: 280)
                .blur(radius: 100).offset(x: -80, y: 360)
        }
        .ignoresSafeArea()
        .animation(.smooth(duration: 0.8), value: tint)
    }
}

/// Стеклянная карточка.
struct GlassCard<Content: View>: View {
    var corner: CGFloat
    var tint: Color?
    let content: Content

    init(corner: CGFloat = 28, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.corner = corner
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .liquidGlass(in: RoundedRectangle(cornerRadius: corner, style: .continuous), tint: tint)
    }
}

/// Большая стеклянная кнопка (подпись; сама кнопка снаружи).
struct PrimaryGlassLabel: View {
    let title: String
    var tint: Color
    var systemImage: String? = nil
    var darkText: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.headline)
        .foregroundStyle(darkText ? Color.black.opacity(0.8) : Color.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .liquidGlass(in: Capsule(), tint: tint.opacity(0.9), interactive: true)
    }
}

/// Небольшая «таблетка» с текстом (только отображение).
struct Pill: View {
    let text: String
    var tint: Color

    var body: some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .liquidGlass(in: Capsule(), tint: tint.opacity(0.45))
    }
}
