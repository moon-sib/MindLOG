import SwiftUI
import SwiftData

/// Короткий опросник: сон, энергия, стресс, тревога, заметка о дне.
struct QuestionnaireView: View {
    @Bindable var checkIn: CheckIn
    var onClose: () -> Void
    var onDone: () -> Void

    @Environment(\.modelContext) private var context

    private var tint: Color { Valence.color(checkIn.valence) }

    var body: some View {
        ZStack {
            AppBackground(tint: tint)
            ScrollView {
                VStack(spacing: 16) {
                    sleepCard
                    RatingRow(title: "Энергия", low: "нет сил", high: "много сил",
                              value: $checkIn.energy, tint: tint)
                    RatingRow(title: "Стресс", low: "спокойно", high: "очень сильный",
                              value: $checkIn.stress, tint: tint)
                    RatingRow(title: "Тревога", low: "нет", high: "очень сильная",
                              value: $checkIn.anxiety, tint: tint)
                    noteCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: finish) {
                PrimaryGlassLabel(title: "Продолжить", tint: tint, darkText: checkIn.valence >= 0.05)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .navigationTitle("Как прошёл день")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .accessibilityLabel("Закрыть")
            }
        }
    }

    private var sleepCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Сколько спал(а)?").font(.headline)
                HStack {
                    stepButton("minus") { checkIn.sleepHours = max(0, checkIn.sleepHours - 0.5) }
                    Spacer()
                    Text("\(checkIn.sleepHours, specifier: "%.1f") ч")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    Spacer()
                    stepButton("plus") { checkIn.sleepHours = min(14, checkIn.sleepHours + 0.5) }
                }
            }
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 52, height: 52)
                .liquidGlass(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
    }

    private var noteCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Что было за день?").font(.headline)
                TextField("Коротко, как получится", text: $checkIn.dayNote, axis: .vertical)
                    .lineLimit(3...8)
            }
        }
    }

    private func finish() {
        checkIn.answers = [
            QAItem(question: "Сон, часов", answer: String(format: "%.1f", checkIn.sleepHours)),
            QAItem(question: "Энергия (1–5)", answer: "\(checkIn.energy)"),
            QAItem(question: "Стресс (1–5)", answer: "\(checkIn.stress)"),
            QAItem(question: "Тревога (1–5)", answer: "\(checkIn.anxiety)"),
            QAItem(question: "Что было за день", answer: checkIn.dayNote)
        ]
        try? context.save()
        onDone()
    }
}

/// Оценка от 1 до 5 пятью стеклянными кнопками.
struct RatingRow: View {
    let title: String
    let low: String
    let high: String
    @Binding var value: Int
    var tint: Color

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title).font(.headline)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { n in
                        Button { value = n } label: {
                            Text("\(n)")
                                .font(.system(.title3, design: .rounded).weight(.semibold))
                                .foregroundStyle(value == n ? Color.black.opacity(0.85) : Color.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .liquidGlass(in: Capsule(),
                                             tint: value == n ? tint.opacity(0.95) : nil,
                                             interactive: true)
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    Text(low)
                    Spacer()
                    Text(high)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .sensoryFeedback(.selection, trigger: value)
    }
}
