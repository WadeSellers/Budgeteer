import SwiftUI

struct CalendarHeatmapView: View {
    let transactions: [Transaction]
    let dailyBudget: Double
    let monthlyBudget: Double
    var selectedDate: Date? = nil
    var onDayTap: (Date?) -> Void = { _ in }
    var onBudgetTap: () -> Void = {}

    @Environment(ThemeManager.self) private var theme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]

    // MARK: - Calendar math

    /// Fixed Gregorian calendar — avoids locale/firstWeekday surprises
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "en_US_POSIX")
        return c
    }()

    private var today: Date { Date() }

    private var monthName: String {
        today.formatted(.dateTime.month(.wide))
    }

    private var daysInMonth: Int {
        cal.range(of: .day, in: .month, for: today)?.count ?? 30
    }

    /// Offset so the 1st lands on the correct column (Mon = 0 … Sun = 6).
    /// Explicitly constructs the 1st of the month with day:1 to avoid
    /// ambiguous date(from:) behaviour when only year+month are supplied.
    private var firstWeekdayOffset: Int {
        let y = cal.component(.year,  from: today)
        let m = cal.component(.month, from: today)
        let comps = DateComponents(year: y, month: m, day: 1)
        guard let first = cal.date(from: comps) else { return 0 }
        let wd = cal.component(.weekday, from: first) // 1=Sun … 7=Sat (Gregorian)
        return (wd + 5) % 7  // Mon=0, Tue=1, … Sun=6
    }

    private var todayDay: Int {
        cal.component(.day, from: today)
    }

    // MARK: - Spending data

    private var spendingByDay: [Int: Double] {
        let y = cal.component(.year,  from: today)
        let m = cal.component(.month, from: today)
        var result: [Int: Double] = [:]
        for t in transactions where !t.isPending {
            let tc = cal.dateComponents([.year, .month, .day], from: t.timestamp)
            if tc.year == y && tc.month == m, let day = tc.day {
                result[day, default: 0] += t.amount
            }
        }
        return result
    }

    /// Flat array of optional day numbers for the grid.
    /// nil = empty cell (before day 1 or after last day to complete the final row).
    private var gridCells: [Int?] {
        let leading  = firstWeekdayOffset
        let total    = leading + daysInMonth
        let trailing = (7 - total % 7) % 7   // pad to complete the last row
        return Array(repeating: nil, count: leading)
             + (1...daysInMonth).map { Optional($0) }
             + Array(repeating: nil, count: trailing)
    }

    // MARK: - Day helpers

    private func date(for day: Int) -> Date {
        let y = cal.component(.year,  from: today)
        let m = cal.component(.month, from: today)
        return cal.date(from: DateComponents(year: y, month: m, day: day)) ?? today
    }

    private func isSelected(day: Int) -> Bool {
        guard let sel = selectedDate else { return false }
        return cal.component(.day, from: sel) == day
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            // Month name + monthly budget
            HStack(alignment: .firstTextBaseline) {
                Text(monthName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(BudgeteerColors.green)

                Spacer()

                Button(action: onBudgetTap) {
                    Text(monthlyBudget, format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    + Text(" / mo")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Single grid for header + days — eliminates double spacing
            LazyVGrid(columns: columns, spacing: 5) {
                // Weekday labels
                ForEach(0..<7, id: \.self) { i in
                    Text(weekdays[i])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 12)
                }

                // Flat cell list: leading empties + days + trailing empties to
                // complete the final row. Using RoundedRectangle (a greedy Shape)
                // instead of Color.clear so every cell reports a real height —
                // Color.clear has zero intrinsic size and collapses the whole row.
                ForEach(gridCells, id: \.self) { cellDay in
                    if let day = cellDay {
                        dayCell(day: day)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.clear)
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Day cell

    @ViewBuilder
    private func dayCell(day: Int) -> some View {
        let isPast    = day < todayDay
        let isToday   = day == todayDay
        let isFuture  = day > todayDay
        let spent     = spendingByDay[day] ?? 0
        let selected  = isSelected(day: day)

        ZStack(alignment: .topLeading) {
            // Background — always present so all cells are the same size
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    (isPast || isToday)
                        ? heatmapColor(spent: spent)
                        : theme.card
                )

            if isPast || isToday {
                // Day number — top-left corner
                Text("\(day)")
                    .font(.system(size: 7, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding([.top, .leading], 3)

                // Spend amount — centered
                Text(compactAmount(spent))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Future day — centered day number, no fill
                Text("\(day)")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Today ring
            if isToday {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(.primary, lineWidth: 2.5)
            }

            // Selected past day ring — yellow border
            if selected && !isToday {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(BudgeteerColors.yellow, lineWidth: 2.5)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onTapGesture {
            guard !isFuture else { return }
            if selected {
                onDayTap(nil)   // deselect → back to today
            } else if isToday {
                onDayTap(nil)   // tapping today also returns to today mode
            } else {
                onDayTap(date(for: day))
            }
        }
    }

    // MARK: - Amount formatting

    /// Keeps text short enough to fit in a small cell
    private func compactAmount(_ amount: Double) -> String {
        if amount == 0       { return "$0" }
        if amount < 1000     { return String(format: "$%.0f", amount) }
        return String(format: "$%.1fk", amount / 1000)
    }

    // MARK: - Heatmap color
    // Delegates to BudgeteerColors.spendingColor so the scale is identical
    // everywhere in the app (calendar cells, mic button, recording overlay).

    private func heatmapColor(spent: Double) -> Color {
        BudgeteerColors.spendingColor(spent: spent, dailyBudget: dailyBudget)
    }
}
