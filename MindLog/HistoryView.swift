import SwiftUI
import SwiftData

/// Подробности одной записи.
struct HistoryDetailView: View {
    let checkIn: CheckIn

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var confirmDelete = false

    private var tint: Color { Valence.color(checkIn.valence) }

    var body: some View {
        ZStack {
            AppBackground(tint: tint)
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        MoodOrb(valence: checkIn.valence)
                            .frame(width: 150, height: 150)
                        Text(checkIn.moodLabel)
                            .font(.system(.title, design: .rounded).weight(.bold))
                        Text(checkIn.date.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    if !checkIn.moodTags.isEmpty {
                        section("Чувства") { pills(checkIn.moodTags) }
                    }
                    if !checkIn.influences.isEmpty {
                        section("Что повлияло") { pills(checkIn.influences) }
                    }
                    if !checkIn.answers.isEmpty {
                        section("Опросник") {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(checkIn.answers, id: \.self) { qa in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(qa.question).font(.caption).foregroundStyle(.secondary)
                                        Text(qa.answer.isEmpty ? "—" : qa.answer)
                                    }
                                }
                            }
                        }
                    }
                    if !checkIn.summary.isEmpty {
                        section("Итог дня") { Text(checkIn.summary) }
                    }
                    if !checkIn.messages.isEmpty {
                        section("Разговор") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(checkIn.messages.sorted { $0.date < $1.date }) { m in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(m.role == .user ? "Ты" : "Помощник")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(m.text)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle(checkIn.date.formatted(date: .abbreviated, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) { confirmDelete = true } label: { Image(systemName: "trash") }
                    .accessibilityLabel("Удалить запись")
            }
        }
        .confirmationDialog("Удалить запись?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Удалить", role: .destructive) {
                let item = checkIn
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    context.delete(item)
                    try? context.save()
                }
            }
        }
    }

    private func pills(_ items: [String]) -> some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { Pill(text: $0, tint: tint) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title).font(.headline)
                content()
            }
        }
    }
}
