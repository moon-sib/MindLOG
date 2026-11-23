import SwiftUI
import SwiftData
import UIKit

/// Первый запуск: имя, возраст (любой, необязательно), пол, цель. Показывается один раз.
struct SetupView: View {
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var ageText = ""
    @State private var gender: Gender = .none
    @State private var goal = ""

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            AppBackground(tint: Valence.color(0.4))
            ScrollView {
                VStack(spacing: 24) {
                    MoodOrb(valence: 0.4)
                        .frame(width: 180, height: 180)
                        .padding(.top, 32)

                    VStack(spacing: 8) {
                        Text("Привет!")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        Text("Расскажи немного о себе. Это нужно только один раз.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 12) {
                        field("Имя", text: $name)
                        field("Возраст (необязательно)", text: $ageText, keyboard: .numberPad)
                        HStack {
                            Text("Пол")
                            Spacer()
                            Picker("Пол", selection: $gender) {
                                ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        field("Зачем следишь за состоянием? (необязательно)", text: $goal, axis: .vertical)
                    }

                    Button(action: save) {
                        PrimaryGlassLabel(title: "Начать", tint: Valence.color(0.4), darkText: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedName.isEmpty)
                    .opacity(trimmedName.isEmpty ? 0.5 : 1)
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: ageText) { _, v in
            let f = String(v.filter(\.isNumber).prefix(3))
            if f != v { ageText = f }
        }
    }

    private func field(_ title: String, text: Binding<String>,
                       keyboard: UIKeyboardType = .default, axis: Axis = .horizontal) -> some View {
        TextField(title, text: text, axis: axis)
            .keyboardType(keyboard)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func save() {
        let age = Int(ageText.filter(\.isNumber).prefix(3)) ?? 0
        context.insert(UserProfile(name: trimmedName, age: age, gender: gender, goal: goal))
        try? context.save()
    }
}
