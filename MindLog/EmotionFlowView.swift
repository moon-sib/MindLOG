import SwiftUI
import SwiftData

/// Три шага в духе Apple Health: шкала ощущений → слово для чувства → что повлияло.
struct EmotionFlowView: View {
    enum Step { case scale, word, influence }

    var onDone: (CheckIn) -> Void
    var onCancel: () -> Void

    @Environment(\.modelContext) private var context
    @State private var step: Step = .scale
    @State private var valence = 0.0
    @State private var feelings: Set<String> = []
    @State private var influences: Set<String> = []

    private var tint: Color { Valence.color(valence) }
    private var label: String { Valence.label(valence) }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                Group {
                    switch step {
                    case .scale: scaleStep
                    case .word: wordStep
                    case .influence: influenceStep
                    }
                }
                .frame(maxHeight: .infinity)
                .transition(.opacity)

                nextButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Фон и верхняя панель

    private var background: some View {
        AppBackground(tint: tint)
    }

    private var topBar: some View {
        ZStack {
            if step == .scale {
                Text("Эмоция").font(.headline)
            }
            HStack {
                circleButton("chevron.left", action: back)
                Spacer()
                circleButton("xmark", action: onCancel)
            }
        }
        .padding(.top, 8)
    }

    private func circleButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .liquidGlass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbol == "xmark" ? "Закрыть" : "Назад")
    }

    // MARK: - Шаги

    private var scaleStep: some View {
        VStack(spacing: 0) {
            Text("Как ты сейчас себя ощущаешь?")
                .font(.system(.title, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.top, 32)

            Spacer()
            MoodOrb(valence: valence)
                .frame(width: 290, height: 290)
            Spacer()

            Text(label)
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .id(label)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: label)
                .padding(.bottom, 20)

            MoodSlider(value: $valence)

            HStack {
                Text("ОЧЕНЬ НЕПРИЯТНЫЕ")
                Spacer()
                Text("ОЧЕНЬ ПРИЯТНЫЕ")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    private var wordStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            question("Каким словом можно описать это чувство?")
            ScrollView {
                ChipGroup(options: Valence.words(for: valence), selected: $feelings, tint: tint)
                    .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var influenceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            question("Что оказывает наибольшее влияние?")
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(Valence.influenceGroups, id: \.self) { group in
                        ChipGroup(options: group, selected: $influences, tint: tint)
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            MoodOrb(valence: valence)
                .frame(width: 150, height: 150)
            Text(label)
                .font(.system(.title, design: .rounded).weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private func question(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.system(.title3, design: .rounded).weight(.semibold))
            Divider().overlay(Color.white.opacity(0.15))
        }
        .padding(.top, 8)
    }

    // MARK: - Кнопка и навигация

    private var nextButton: some View {
        Button(action: advance) {
            Text(step == .influence ? "Готово" : "Далее")
                .font(.headline)
                .foregroundStyle(valence < 0.05 ? Color.white : Color.black.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .liquidGlass(in: Capsule(), tint: tint.opacity(0.9), interactive: true)
                .animation(.smooth(duration: 0.5), value: valence)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    private func go(_ next: Step) {
        withAnimation(.smooth(duration: 0.35)) { step = next }
    }

    private func back() {
        switch step {
        case .scale: onCancel()
        case .word: go(.scale)
        case .influence: go(.word)
        }
    }

    private func advance() {
        switch step {
        case .scale:
            // Если вернулись и сменили шкалу — убираем слова, которых больше нет в списке.
            feelings = feelings.intersection(Valence.words(for: valence))
            go(.word)
        case .word:
            go(.influence)
        case .influence:
            finish()
        }
    }

    private func finish() {
        let checkIn = CheckIn(
            valence: valence,
            moodTags: Array(feelings).sorted(),
            influences: Array(influences).sorted()
        )
        context.insert(checkIn)
        try? context.save()
        onDone(checkIn)
    }
}

/// Ползунок с белым бегунком, как в Apple Health.
struct MoodSlider: View {
    @Binding var value: Double   // -1...1
    private let thumb: CGFloat = 46

    var body: some View {
        GeometryReader { geo in
            let track = max(1, geo.size.width - thumb)
            let x = CGFloat((value + 1) / 2) * track
            ZStack(alignment: .leading) {
                Capsule().fill(Color.clear).liquidGlass(in: Capsule())
                Circle()
                    .fill(.white)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                    .offset(x: x)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    let p = min(max((g.location.x - thumb / 2) / track, 0), 1)
                    value = Double(p) * 2 - 1
                }
            )
        }
        .frame(height: 54)
        .sensoryFeedback(.selection, trigger: Valence.index(value))
        .accessibilityElement()
        .accessibilityLabel("Самочувствие")
        .accessibilityValue(Valence.label(value))
        .accessibilityAdjustableAction { direction in
            let step = 1.0 / 3.0
            switch direction {
            case .increment: value = min(1, value + step)
            case .decrement: value = max(-1, value - step)
            @unknown default: break
            }
        }
    }
}
