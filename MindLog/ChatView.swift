import SwiftUI
import SwiftData

/// Чат с нейросетью про прошедший день. «Завершить» сохраняет итог дня.
struct ChatView: View {
    let checkIn: CheckIn
    var onClose: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \CheckIn.date, order: .reverse) private var allCheckIns: [CheckIn]

    @State private var input = ""
    @State private var sending = false
    @State private var errorText: String?
    @State private var showCrisis = false

    private let service = AppConfig.makeService()

    private var tint: Color { Valence.color(checkIn.valence) }
    private var sorted: [ChatMessage] { checkIn.messages.sorted { $0.date < $1.date } }
    private var canSend: Bool {
        !sending && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground(tint: tint)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(sorted) { m in
                            bubble(m).id(m.persistentModelID)
                        }
                        if sending {
                            ProgressView()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 8)
                        }
                        if let errorText {
                            Text(errorText).font(.footnote).foregroundStyle(.red)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: checkIn.messages.count) {
                    if let last = sorted.last {
                        withAnimation { proxy.scrollTo(last.persistentModelID, anchor: .bottom) }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { inputBar }
        .navigationTitle("Разговор")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .accessibilityLabel("Закрыть")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Завершить") { finish() }.disabled(sending)
            }
        }
        .alert("Ты не один(а)", isPresented: $showCrisis) {
            Button("Понятно", role: .cancel) {}
        } message: {
            Text(Safety.message)
        }
        .onAppear(perform: greetIfNeeded)
    }

    private func bubble(_ m: ChatMessage) -> some View {
        let mine = m.role == .user
        return HStack {
            if mine { Spacer(minLength: 50) }
            Text(m.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous),
                             tint: mine ? tint.opacity(0.75) : nil)
            if !mine { Spacer(minLength: 50) }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Напиши что-нибудь…", text: $input, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 46, height: 46)
                    .liquidGlass(in: Circle(), tint: canSend ? tint : nil, interactive: true)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Логика

    private func greetIfNeeded() {
        guard checkIn.messages.isEmpty else { return }
        let name = profiles.first?.name ?? ""
        let hello = name.isEmpty ? "Привет!" : "Привет, \(name)!"
        append(.assistant, "\(hello) Спасибо, что отметил(а) состояние. Расскажи, как прошёл твой день?")
    }

    private func append(_ role: ChatRole, _ text: String) {
        let m = ChatMessage(role: role, text: text)
        context.insert(m)
        m.checkIn = checkIn
        try? context.save()
    }

    /// API ждёт, что первой идёт реплика пользователя, поэтому приветствие ассистента отбрасываем.
    private func history() -> [ChatTurn] {
        let turns = sorted.map { ChatTurn(role: $0.role.rawValue, content: $0.text) }
        return Array(turns.drop(while: { $0.role != "user" }))
    }

    private func system() -> String {
        PromptBuilder.system(profile: profiles.first, checkIn: checkIn, recent: allCheckIns)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !sending else { return }
        input = ""
        errorText = nil
        append(.user, text)
        if Safety.isCrisis(text) { showCrisis = true }

        sending = true
        Task {
            do {
                let reply = try await service.reply(system: system(), history: history())
                append(.assistant, reply)
            } catch {
                errorText = "Не удалось получить ответ. Проверь соединение и попробуй ещё раз."
            }
            sending = false
        }
    }

    private func finish() {
        guard !sending else { return }
        sending = true
        Task {
            var summary = ""
            if sorted.contains(where: { $0.role == .user }) {
                let ask = ChatTurn(role: "user", content: "Подведи короткий итог дня в 2–3 предложениях, без вопросов.")
                summary = (try? await service.reply(system: system(), history: history() + [ask])) ?? ""
            }
            if summary.isEmpty { summary = checkIn.dayNote }
            checkIn.summary = summary
            try? context.save()
            sending = false
            onClose()
        }
    }
}
