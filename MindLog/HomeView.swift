import SwiftUI
import SwiftData
import Charts

/// Главный экран: приветствие, последнее состояние, статистика, график и список записей.
/// Новая запись — «+» в правом верхнем углу.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CheckIn.date, order: .reverse) private var checkIns: [CheckIn]
    @Query private var profiles: [UserProfile]

    @State private var showNew = false
    @State private var showSettings = false

    private var name: String { profiles.first?.name ?? "" }
    private var lastValence: Double { checkIns.first?.valence ?? 0 }
    private var tint: Color { Valence.color(lastValence) }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground(tint: tint)
                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        if !checkIns.isEmpty { statsRow }
                        if checkIns.count >= 2 { TrendCard(checkIns: checkIns) }
                        entries
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Дневник")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Настройки")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Новая запись")
                }
            }
            .fullScreenCover(isPresented: $showNew) {
                NewCheckInFlow { showNew = false }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Блоки

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Доброе утро"
        case 12..<18: return "Добрый день"
        case 18..<23: return "Добрый вечер"
        default: return "Доброй ночи"
        }
    }

    private var hero: some View {
        GlassCard(corner: 36) {
            VStack(spacing: 14) {
                Text(name.isEmpty ? greeting : "\(greeting), \(name)")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                MoodOrb(valence: lastValence)
                    .frame(width: 170, height: 170)

                if let last = checkIns.first {
                    Text(last.moodLabel)
                        .font(.system(.title, design: .rounded).weight(.bold))
                    Text("Последняя запись: " + last.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Пока нет записей")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text("Нажми «Записать» или «+» в углу, чтобы отметить первое состояние.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button { showNew = true } label: {
                    PrimaryGlassLabel(title: "Записать состояние", tint: tint,
                                      systemImage: "plus", darkText: lastValence >= 0.05)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat("\(streak)", "серия, дней")
            stat("\(checkIns.count)", "записей")
            stat(weekAverage, "за 7 дней")
        }
    }

    private func stat(_ value: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .multilineTextAlignment(.center)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var streak: Int {
        let cal = Calendar.current
        let days = Set(checkIns.map { cal.startOfDay(for: $0.date) })
        var day = cal.startOfDay(for: Date())
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day) ?? .distantPast }
        var n = 0
        while days.contains(day) {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? .distantPast
        }
        return n
    }

    private var weekAverage: String {
        let from = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? .distantPast
        let recent = checkIns.filter { $0.date >= from }
        guard !recent.isEmpty else { return "—" }
        let avg = recent.map(\.valence).reduce(0, +) / Double(recent.count)
        return Valence.label(avg)
    }

    private var entries: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !checkIns.isEmpty {
                Text("Записи")
                    .font(.title3.weight(.semibold))
                    .padding(.leading, 4)
                    .padding(.top, 4)
            }
            ForEach(checkIns) { item in
                NavigationLink {
                    HistoryDetailView(checkIn: item)
                } label: {
                    row(item)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) { delete(item) } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                }
            }
        }
    }

    private func row(_ item: CheckIn) -> some View {
        HStack(spacing: 14) {
            MoodOrb(valence: item.valence, animated: false)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.moodLabel)
                    .font(.headline)
                    .foregroundStyle(Valence.color(item.valence))
                Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !item.moodTags.isEmpty {
                    Text(item.moodTags.joined(separator: " · "))
                        .font(.subheadline)
                        .lineLimit(1)
                }
                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func delete(_ item: CheckIn) {
        context.delete(item)
        try? context.save()
    }
}

/// График состояния по последним записям.
struct TrendCard: View {
    let checkIns: [CheckIn]   // новые первыми

    private var points: [CheckIn] { Array(checkIns.prefix(14).reversed()) }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Динамика").font(.headline)
                Chart(points, id: \.persistentModelID) { c in
                    LineMark(x: .value("Дата", c.date), y: .value("Состояние", c.valence))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(Color.white.opacity(0.7))
                    PointMark(x: .value("Дата", c.date), y: .value("Состояние", c.valence))
                        .foregroundStyle(Valence.color(c.valence))
                        .symbolSize(80)
                }
                .chartYScale(domain: -1.1...1.1)
                .chartYAxis(.hidden)
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
                .frame(height: 150)
            }
        }
    }
}
