import Foundation

struct ChatTurn: Codable {
    let role: String   // "user" | "assistant"
    let content: String
}

protocol ChatService {
    func reply(system: String, history: [ChatTurn]) async throws -> String
}

enum AppConfig {
    /// Адрес твоего прокси (см. server.mjs). Пока nil — работает заглушка без нейросети.
    /// Пример: URL(string: "https://your-domain.example/chat")
    static let proxyURL: URL? = nil
    /// Тот же токен, что APP_TOKEN на сервере (необязательно).
    static let appToken: String? = nil

    static func makeService() -> ChatService {
        if let url = proxyURL { return ProxyChatService(endpoint: url) }
        return MockChatService()
    }
}

/// Ходит в твой сервер-прокси, а тот — в Claude API. Ключ API в приложении не хранится.
struct ProxyChatService: ChatService {
    let endpoint: URL

    private struct Payload: Encodable {
        let system: String
        let messages: [ChatTurn]
    }
    private struct Response: Decodable { let text: String }

    func reply(system: String, history: [ChatTurn]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AppConfig.appToken { request.setValue(token, forHTTPHeaderField: "x-app-token") }
        request.httpBody = try JSONEncoder().encode(Payload(system: system, messages: history))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Response.self, from: data).text
    }
}

/// Заглушка без нейросети: реагирует на темы в сообщении, чтобы поток можно было проверить без сервера.
struct MockChatService: ChatService {
    private struct Topic {
        let keys: [String]
        let replies: [String]
    }

    private static let topics: [Topic] = [
        Topic(keys: ["работ", "проект", "дедлайн", "начальник", "коллег", "клиент", "созвон"], replies: [
            "Похоже, работа сегодня заняла много места в голове. Что давило сильнее всего: объём задач, люди или ощущение, что не успеваешь?",
            "Звучит так, будто рабочий день выжал из тебя немало. Был ли момент, когда стало хоть чуть легче?",
            "Если бы завтра можно было изменить одну вещь на работе, что бы это было?"
        ]),
        Topic(keys: ["сон", "спал", "выспал", "бессонн", "проснул"], replies: [
            "Сон сильно влияет на всё остальное. Как ты думаешь, что мешало выспаться: мысли, режим или что-то другое?",
            "А как ты себя чувствовал(а) после пробуждения: сразу было тяжело или разошёлся(лась) к середине дня?",
            "Что из вечернего ритуала обычно помогает тебе заснуть легче?"
        ]),
        Topic(keys: ["устал", "нет сил", "вымотал", "выгор", "без сил"], replies: [
            "Усталость бывает разной: от недосыпа, от людей, от бесконечных задач. На что она больше похожа сегодня?",
            "Когда в последний раз ты давал(а) себе нормально отдохнуть, без чувства вины?",
            "Что одно маленькое можно убрать из завтрашнего дня, чтобы стало полегче?"
        ]),
        Topic(keys: ["тревог", "волну", "страшно", "боюсь", "беспоко", "паник"], replies: [
            "Тревога часто привязана к чему-то конкретному. О чём были мысли, когда она накрывала сильнее всего?",
            "Бывает, тревога относится к будущему, которого ещё нет. Что именно ты боишься не удержать под контролем?",
            "Что помогало тебе хоть немного успокоиться раньше: движение, разговор, тишина?"
        ]),
        Topic(keys: ["друз", "семь", "родител", "партн", "отношен", "девушк", "парн", "муж", "жена", "мама", "папа"], replies: [
            "Люди рядом сильно влияют на самочувствие. Что в этом общении сегодня было самым важным для тебя?",
            "Как ты думаешь, чего тебе сейчас не хватает от близких: внимания, поддержки или пространства?",
            "Если бы можно было сказать этому человеку одну честную фразу, какой бы она была?"
        ]),
        Topic(keys: ["груст", "плохо", "тяжело", "одинок", "пусто", "обидно", "грустн"], replies: [
            "Мне жаль, что день получился тяжёлым. В какой момент стало хуже всего?",
            "Это чувство появилось внезапно или копилось несколько дней?",
            "Что бы тебе сейчас хоть чуть-чуть помогло: побыть одному, с кем-то поговорить или просто отвлечься?"
        ]),
        Topic(keys: ["хорошо", "рад", "круто", "отлично", "счастл", "получилось", "доволен", "здорово"], replies: [
            "Приятно слышать! Что именно сделало день хорошим?",
            "Хочется запомнить это состояние. Что из сегодняшнего ты бы с удовольствием повторил(а)?",
            "Кто или что помогло тебе почувствовать себя так?"
        ])
    ]

    private static let short = [
        "Расскажи чуть подробнее: в какой момент дня ты это почувствовал(а) сильнее всего?",
        "Что за этим стоит: событие, мысль или человек?",
        "Если выбрать одно слово для сегодняшнего дня, какое оно?"
    ]

    private static let generic = [
        "Слышу, что для тебя это важно. Что в этой ситуации задевает больше всего?",
        "Спасибо, что объясняешь. Как это отражается на твоём состоянии прямо сейчас?",
        "Интересно. А что ты хотел(а) бы изменить в этом, если бы мог(ла)?"
    ]

    func reply(system: String, history: [ChatTurn]) async throws -> String {
        try await Task.sleep(nanoseconds: 700_000_000)
        let lastUser = history.last(where: { $0.role == "user" })?.content ?? ""
        if lastUser.hasPrefix("Подведи короткий итог") {
            return "Итог дня сохранён (режим заглушки). Подключи сервер, и итог напишет нейросеть."
        }
        let userCount = history.filter { $0.role == "user" }.count
        let i = max(userCount - 1, 0)
        if userCount >= 5 {
            return "Кажется, мы уже многое разобрали. Если хватит, нажми «Завершить», и я сохраню итог дня."
        }
        let text = lastUser.lowercased()
        if let t = Self.topics.first(where: { topic in topic.keys.contains(where: { text.contains($0) }) }) {
            return t.replies[i % t.replies.count]
        }
        if text.count < 25 { return Self.short[i % Self.short.count] }
        return Self.generic[i % Self.generic.count]
    }
}

enum PromptBuilder {
    static func system(profile: UserProfile?, checkIn: CheckIn, recent: [CheckIn] = []) -> String {
        var lines: [String] = [
            "Ты — внимательный собеседник в дневнике самочувствия. Говори по-русски, на «ты», живым человеческим языком — как умный и тёплый друг, а не как анкета или робот.",
            "",
            "КАК ОТВЕЧАТЬ",
            "- 2–4 коротких предложения, без списков, заголовков и эмодзи.",
            "- Сначала покажи, что услышал именно ЭТО: перескажи суть своими словами, опираясь на конкретные слова человека. Никаких общих фраз вроде «понимаю, это непросто».",
            "- Затем задай ОДИН конкретный вопрос, который ведёт вглубь: что стояло за чувством, в какой момент дня оно появилось, что помогло или могло бы помочь, чего не хватало. Не повторяй уже заданные вопросы.",
            "- Если человек отвечает коротко или не знает, что сказать, предложи два-три конкретных варианта на выбор или спроси про конкретный момент дня.",
            "- Замечай связи между ощущениями, влияниями и опросником («после короткого сна стресс выше») и формулируй их как мягкое наблюдение, а не вывод. Числа упоминай, только если они заметны (сон меньше 6 часов, стресс или тревога 4–5).",
            "- Не давай советов, пока не попросили или пока не ясно, что человеку нужно. Если советуешь, то одно маленькое конкретное действие.",
            "- Избегай клише: «это нормально чувствовать», «я здесь для тебя», «важно помнить». Не хвали за то, что человек поделился.",
            "- После 4–5 реплик человека мягко предложи подвести итог дня кнопкой «Завершить».",
            "- Если просят подвести итог дня, напиши 2–3 предложения без вопросов: как прошёл день, что было главным, что стоит запомнить.",
            "",
            "ГРАНИЦЫ",
            "- Не ставь диагнозов, не давай медицинских назначений, не говори «у тебя депрессия/тревожное расстройство».",
            "- Если человек пишет о желании навредить себе или о суициде, не продолжай обычный разговор: прояви заботу, спроси, в безопасности ли он сейчас, и предложи обратиться к близким или в службу экстренной помощи (112 или местный номер).",
            "",
            "КОНТЕКСТ",
            "Сейчас: \(partOfDay())."
        ]

        if let p = profile {
            var who = "Человека зовут \(p.name)"
            if p.age > 0 { who += ", возраст \(p.age)" }
            if p.gender != Gender.none { who += ", пол: \(p.gender.rawValue.lowercased())" }
            who += ". Цель дневника: \(p.goal.isEmpty ? "не указана" : p.goal)."
            lines.append(who)
        }

        lines.append("Ощущения на входе: \(checkIn.moodLabel.lowercased()) (шкала от «очень неприятные» до «очень приятные»). Слова-чувства: \(checkIn.moodTags.isEmpty ? "не отмечены" : checkIn.moodTags.joined(separator: ", ")). Что повлияло: \(checkIn.influences.isEmpty ? "не отмечено" : checkIn.influences.joined(separator: ", ")).")

        for qa in checkIn.answers {
            lines.append("\(qa.question): \(qa.answer.isEmpty ? "—" : qa.answer)")
        }

        let others = recent.filter { $0.persistentModelID != checkIn.persistentModelID }.prefix(5)
        if !others.isEmpty {
            lines.append("")
            lines.append("ПРЕДЫДУЩИЕ ЗАПИСИ (для контекста; упоминай, только если это помогает заметить закономерность):")
            for c in others {
                let tags = c.moodTags.isEmpty ? "" : "; чувства: " + c.moodTags.joined(separator: ", ")
                let inf = c.influences.isEmpty ? "" : "; влияло: " + c.influences.joined(separator: ", ")
                let day = c.date.formatted(.dateTime.day().month(.abbreviated))
                lines.append("- \(day): \(c.moodLabel.lowercased())\(tags)\(inf)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func partOfDay() -> String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "утро"
        case 12..<18: return "день"
        case 18..<23: return "вечер"
        default: return "ночь"
        }
    }
}
