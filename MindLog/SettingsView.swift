import SwiftUI
import SwiftData
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]

    @AppStorage("reminderOn") private var reminderOn = false
    @AppStorage("reminderMinutes") private var reminderMinutes = 21 * 60
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(tint: Valence.color(0.4))
                ScrollView {
                    VStack(spacing: 16) {
                        if let p = profiles.first { ProfileCard(profile: p) }
                        reminderCard
                        GlassCard {
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Label("Удалить все записи", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        Text("Приложение не заменяет врача или психотерапевта и не ставит диагнозов.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Готово") { dismiss() } }
            }
            .confirmationDialog("Удалить все записи?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) { deleteAll() }
            } message: {
                Text("Это действие нельзя отменить.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60, minute: reminderMinutes % 60,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (c.hour ?? 21) * 60 + (c.minute ?? 0)
            }
        )
    }

    private var reminderCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Ежедневное напоминание", isOn: $reminderOn)
                if reminderOn {
                    DatePicker("Время", selection: timeBinding, displayedComponents: .hourAndMinute)
                }
            }
        }
        .onChange(of: reminderOn) { _, on in
            Task {
                if on {
                    let ok = await Reminders.enable(minutes: reminderMinutes)
                    if !ok { reminderOn = false }
                } else {
                    Reminders.disable()
                }
            }
        }
        .onChange(of: reminderMinutes) { _, m in
            if reminderOn { Task { _ = await Reminders.enable(minutes: m) } }
        }
    }

    private func deleteAll() {
        let all = (try? context.fetch(FetchDescriptor<CheckIn>())) ?? []
        all.forEach { context.delete($0) }
        try? context.save()
    }
}

private struct ProfileCard: View {
    @Bindable var profile: UserProfile

    private var ageText: Binding<String> {
        Binding(
            get: { profile.age > 0 ? String(profile.age) : "" },
            set: { profile.age = Int($0.filter(\.isNumber).prefix(3)) ?? 0 }
        )
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("О тебе").font(.headline)
                TextField("Имя", text: $profile.name)
                Divider()
                TextField("Возраст (любой, необязательно)", text: ageText)
                    .keyboardType(.numberPad)
                Divider()
                Picker("Пол", selection: $profile.gender) {
                    ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
                }
                Divider()
                TextField("Цель", text: $profile.goal, axis: .vertical)
            }
        }
    }
}
