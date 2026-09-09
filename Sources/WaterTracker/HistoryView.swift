import SwiftUI
import Charts

struct HistoryView: View {
    @ObservedObject var store: WaterStore

    @State private var monthAnchor = Date()
    @State private var selectedDay: String?

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                streakRing
                weekCurve
                monthCalendar
                summary
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDay) { key in
            DayDetailView(dateKey: key, record: store.history[key], goalML: store.goalML)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Streak ring

    /// The streak drawn as a ring closing on the next milestone, so the shape
    /// itself carries the progress rather than just decorating a number.
    private var streakRing: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.14), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: milestoneProgress)
                    .stroke(
                        LinearGradient(colors: [.orange, .red],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.9), value: milestoneProgress)

                VStack(spacing: 2) {
                    Image(systemName: store.currentStreak > 0 ? "flame.fill" : "flame")
                        .font(.title3)
                        .foregroundStyle(store.currentStreak > 0 ? .orange : .secondary)
                    Text("\(store.currentStreak)")
                        .font(.display(44, weight: .bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(store.currentStreak == 1 ? "day" : "days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 168, height: 168)

            Text(milestoneCaption)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var nextMilestone: Int {
        [3, 7, 14, 30, 60, 100, 180, 365].first { $0 > store.currentStreak }
            ?? store.currentStreak + 100
    }

    private var milestoneProgress: Double {
        guard nextMilestone > 0 else { return 0 }
        return min(Double(store.currentStreak) / Double(nextMilestone), 1)
    }

    private var milestoneCaption: String {
        let remaining = nextMilestone - store.currentStreak
        if store.currentStreak == 0 { return "Hit today's goal to start a streak" }
        return "\(remaining) more to reach \(nextMilestone) · best \(store.bestStreak)"
    }

    // MARK: - Week

    private var weekCurve: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Last 7 days")

            Chart(store.recentDays(7)) { day in
                AreaMark(
                    x: .value("Day", day.dateValue, unit: .day),
                    y: .value("Glasses", Double(day.intakeML) / Double(Glass.ml))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(colors: [Color.cyan.opacity(0.55), Color.blue.opacity(0.05)],
                                   startPoint: .top, endPoint: .bottom)
                )

                LineMark(
                    x: .value("Day", day.dateValue, unit: .day),
                    y: .value("Glasses", Double(day.intakeML) / Double(Glass.ml))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.blue)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                RuleMark(y: .value("Goal", Double(store.goalML) / Double(Glass.ml)))
                    .foregroundStyle(.gray.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 160)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemGroupedBackground)))
    }

    // MARK: - Month

    private var monthCalendar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    step(by: -1)
                } label: {
                    Image(systemName: "chevron.left").font(.subheadline.weight(.semibold))
                }

                Spacer()

                Text(monthTitle)
                    .font(.display(.subheadline))
                    .contentTransition(.identity)

                Spacer()

                Button {
                    step(by: 1)
                } label: {
                    Image(systemName: "chevron.right").font(.subheadline.weight(.semibold))
                }
                .disabled(isShowingCurrentMonth)
            }

            HStack(spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                spacing: 8
            ) {
                ForEach(monthDays, id: \.id) { day in
                    if day.key.isEmpty {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    } else {
                        Button {
                            selectedDay = day.key
                        } label: {
                            DayCell(
                                progress: day.record?.progress ?? 0,
                                metGoal: day.record?.metGoal ?? false,
                                isToday: day.isToday,
                                isFuture: day.isFuture,
                                label: day.number
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(day.isFuture)
                    }
                }
            }

            Text("Tap a day to see what you drank.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(Color(.secondarySystemGroupedBackground)))
    }

    private struct MonthDay {
        let id: String
        let key: String
        let number: String
        let record: DayRecord?
        let isToday: Bool
        let isFuture: Bool
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = calendar.isDate(monthAnchor, equalTo: Date(), toGranularity: .year)
            ? "MMMM"
            : "MMMM yyyy"
        return formatter.string(from: monthAnchor)
    }

    private var isShowingCurrentMonth: Bool {
        calendar.isDate(monthAnchor, equalTo: Date(), toGranularity: .month)
    }

    private func step(by months: Int) {
        guard let moved = calendar.date(byAdding: .month, value: months, to: monthAnchor) else { return }
        // Never walk past the current month; there is nothing logged ahead.
        if months > 0, moved > Date(), !calendar.isDate(moved, equalTo: Date(), toGranularity: .month) {
            return
        }
        withAnimation(.easeOut(duration: 0.2)) { monthAnchor = moved }
    }

    private var monthDays: [MonthDay] {
        let today = Date()
        guard let range = calendar.range(of: .day, in: .month, for: monthAnchor),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor))
        else { return [] }

        let leading = calendar.component(.weekday, from: first) - calendar.firstWeekday
        let padding = (leading + 7) % 7

        var days: [MonthDay] = (0..<padding).map {
            MonthDay(id: "pad-\($0)", key: "", number: "", record: nil, isToday: false, isFuture: true)
        }

        for offset in 0..<range.count {
            guard let date = calendar.date(byAdding: .day, value: offset, to: first) else { continue }
            let key = WaterStore.key(for: date)
            days.append(
                MonthDay(
                    id: key,
                    key: key,
                    number: "\(calendar.component(.day, from: date))",
                    record: store.history[key],
                    isToday: calendar.isDateInToday(date),
                    isFuture: date > today && !calendar.isDateInToday(date)
                )
            )
        }
        return days
    }

    // MARK: - Summary

    private var summary: some View {
        HStack(spacing: 12) {
            statTile(value: "\(store.daysGoalMet)", caption: "days hit")
            statTile(value: Glass.format(store.averageIntake), caption: "avg glasses")
            statTile(value: Volume.format(store.averageIntake), caption: "avg oz")
        }
    }

    private func statTile(value: String, caption: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.display(.title2))
                .monospacedDigit()
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemGroupedBackground)))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.display(.subheadline))
            .foregroundStyle(.secondary)
    }
}

/// One day in the calendar, filled to that day's progress.
private struct DayCell: View {
    var progress: Double
    var metGoal: Bool
    var isToday: Bool
    var isFuture: Bool
    var label: String

    /// White once the water is deep enough to swallow dark text.
    private var dayLabelColor: Color {
        if progress > 0.55 { return .white }
        return isFuture ? Color.secondary.opacity(0.45) : Color.secondary
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(Color.blue.opacity(isFuture ? 0.03 : 0.08))

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(
                            LinearGradient(colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.95)],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .frame(height: geometry.size.height * min(progress, 1))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 9))

            Text(label)
                .font(.caption2.weight(isToday ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(dayLabelColor)

            if metGoal {
                RoundedRectangle(cornerRadius: 9).strokeBorder(Color.blue.opacity(0.5), lineWidth: 1.5)
            }
            if isToday {
                RoundedRectangle(cornerRadius: 9).strokeBorder(Color.orange, lineWidth: 2)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// Lets a date key drive a sheet directly.
extension String: @retroactive Identifiable {
    public var id: String { self }
}
