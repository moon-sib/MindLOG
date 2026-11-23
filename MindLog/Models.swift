import Foundation
import SwiftData

enum Gender: String, CaseIterable, Identifiable {
    case none = "Не указываю"
    case female = "Женский"
    case male = "Мужской"
    case other = "Другое"
    var id: String { rawValue }
}

enum ChatRole: String {
    case user
    case assistant
}

/// Ответ на вопрос опросника в читаемом виде (для истории и для ИИ).
struct QAItem: Codable, Hashable {
    var question: String
    var answer: String
}

@Model
final class UserProfile {
    var name: String
    var age: Int
    var genderRaw: String
    var goal: String
    var createdAt: Date

    init(name: String, age: Int, gender: Gender, goal: String) {
        self.name = name
        self.age = age
        self.genderRaw = gender.rawValue
        self.goal = goal
        self.createdAt = Date()
    }

    var gender: Gender {
        get { Gender(rawValue: genderRaw) ?? .none }
        set { genderRaw = newValue.rawValue }
    }
}

/// Одна запись «сессии»: состояние на входе + опросник + чат + итог дня.
@Model
final class CheckIn {
    var date: Date
    var valence: Double = 0              // -1 (очень неприятные) ... +1 (очень приятные)
    var moodTags: [String]               // слова-чувства: «Тревога», «Радость» и т.д.
    var influences: [String] = []        // что повлияло: «Работа», «Семья» и т.д.
    var sleepHours: Double
    var energy: Int          // 1...5
    var stress: Int          // 1...5
    var anxiety: Int         // 1...5
    var dayNote: String
    var answers: [QAItem]
    var summary: String

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.checkIn)
    var messages: [ChatMessage] = []

    var moodLabel: String { Valence.label(valence) }

    init(valence: Double, moodTags: [String], influences: [String]) {
        self.date = Date()
        self.valence = valence
        self.moodTags = moodTags
        self.influences = influences
        self.sleepHours = 7
        self.energy = 3
        self.stress = 3
        self.anxiety = 3
        self.dayNote = ""
        self.answers = []
        self.summary = ""
    }
}

@Model
final class ChatMessage {
    var roleRaw: String
    var text: String
    var date: Date
    var checkIn: CheckIn?

    init(role: ChatRole, text: String) {
        self.roleRaw = role.rawValue
        self.text = text
        self.date = Date()
    }

    var role: ChatRole { ChatRole(rawValue: roleRaw) ?? .assistant }
}
