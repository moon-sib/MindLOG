import SwiftUI

/// Фигура, которая плавно перетекает: острая колючая звезда → круг → мягкий цветок.
struct BlobShape: Shape {
    var petals: Double
    var jag: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(petals, jag) }
        set {
            petals = newValue.first
            jag = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let base = min(rect.width, rect.height) / 2 / (1 + petals + jag * 1.1)
        var path = Path()
        let steps = 240
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let r = base * (1 + petals * cos(5 * t) + jag * (0.8 * cos(8 * t) + 0.3 * cos(16 * t)))
            let p = CGPoint(x: c.x + CGFloat(r * sin(t)), y: c.y - CGFloat(r * cos(t)))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}

/// Слои фигуры: медленно вращаются в разные стороны и «дышат».
struct MoodOrb: View {
    let valence: Double
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if animated && !reduceMotion {
            TimelineView(.animation) { ctx in
                layers(t: ctx.date.timeIntervalSinceReferenceDate)
            }
        } else {
            layers(t: 0)
        }
    }

    private func layers(t: Double) -> some View {
        let color = Valence.color(valence)
        let petals = Valence.petals(valence)
        let jag = Valence.jag(valence)
        let scales: [Double] = [1.0, 0.78, 0.56, 0.34]

        return ZStack {
            ForEach(0..<4, id: \.self) { i in
                let dir: Double = i % 2 == 0 ? 1 : -1
                let angle = t * (0.05 + 0.035 * Double(i)) * dir
                let pulse = 1 + 0.025 * sin(t * 1.1 + Double(i) * 0.9)
                let k = Double(i)

                BlobShape(petals: petals, jag: jag)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.14 + 0.16 * k), color.opacity(0.04 + 0.10 * k)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .overlay {
                        BlobShape(petals: petals, jag: jag)
                            .stroke(color.opacity(0.85), lineWidth: 1)
                    }
                    .scaleEffect(scales[i] * pulse)
                    .rotationEffect(.radians(angle))
            }
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: 6, height: 6)
        }
        .shadow(color: color.opacity(0.45), radius: 28)
        .animation(.smooth(duration: 0.5), value: valence)
    }
}
