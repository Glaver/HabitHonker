//
//  CalendarScreen.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/28/25.
//

import SwiftUI

// MARK: - Models

struct Pill: Identifiable, Hashable {
    let id = UUID()
    let color: Color
}

struct DayItem: Identifiable, Hashable {
    let id: UUID
    let date: Date?
    let inCurrentMonth: Bool
    let isToday: Bool
    let pills: [Pill]
    let isEmpty: Bool
    
    static let blank = DayItem(id: UUID(), date: nil, inCurrentMonth: false, isToday: false, pills: [], isEmpty: true)
}

struct MonthSection: Identifiable {
    let id = UUID()
    let monthDate: Date // any date inside that month
    let title: String   // "August 2025"
    let days: [DayItem] // padded to a multiple of 7
}

// MARK: - Calendar Builder

final class CalendarBuilder {
    private var calendar: Calendar
    private let locale: Locale
    
    init(calendar: Calendar = .current, locale: Locale = .current) {
        var cal = calendar
        cal.locale = locale
        self.calendar = cal
        self.locale = locale
    }
    
    // Month for a specific anchor date
    func makeMonth(for anchor: Date) -> MonthSection {
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor))!
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        let daysInMonth = range.count
        
        let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
        let leading = (weekdayOfFirst - calendar.firstWeekday + 7) % 7
        
        var items: [DayItem] = []
        items.append(contentsOf: Array(repeating: .blank, count: leading))
        
        for day in 1...daysInMonth {
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            let isToday = calendar.isDateInToday(date)
            let pills = demoPills(for: date)
            items.append(DayItem(id: UUID(), date: date, inCurrentMonth: true, isToday: isToday, pills: pills, isEmpty: false))
        }
        
        let remainder = items.count % 7
        if remainder != 0 {
            items.append(contentsOf: Array(repeating: .blank, count: 7 - remainder))
        }
        
        let fmt = DateFormatter()
        fmt.locale = locale
        fmt.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        let title = fmt.string(from: monthStart)
        
        return MonthSection(monthDate: monthStart, title: title, days: items)
    }
    
    // All 12 months of the year that contains `anchor`
    func makeYear(for anchor: Date) -> [MonthSection] {
        let comps = calendar.dateComponents([.year], from: anchor)
        guard let jan1 = calendar.date(from: DateComponents(year: comps.year, month: 1, day: 1)) else {
            return []
        }
        
        let today = Date()
        
        return (0..<12).compactMap { offset in
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: jan1) else { return nil }
            
            // Only include months that are NOT in the future
            if calendar.compare(monthDate, to: today, toGranularity: .month) != .orderedDescending {
                return makeMonth(for: monthDate)
            } else {
                return nil
            }
        }
    }
    
    // Demo pills so UI is visible immediately
    private func demoPills(for date: Date) -> [Pill] {
        let day = calendar.component(.day, from: date)
        let count = [0,1,2,3,4][day % 5]
        let palette: [Color] = [.blue, .green, .orange, .pink, .red, .purple]
        return (0..<count).map { i in Pill(color: palette[(day + i) % palette.count]) }
    }
}

// MARK: - Views

struct YearCalendarScreen: View {
    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    
    @State private var selectedYear: Int
    @State private var months: [MonthSection]
    @State private var path = NavigationPath()
    
    private let builder = CalendarBuilder()
    
    init(anchor: Date = Date()) {
        let year = Calendar.current.component(.year, from: anchor)
        _selectedYear = State(initialValue: year)
        let start = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!
        _months = State(initialValue: CalendarBuilder().makeYear(for: start))
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    HabitFilterCollection()
                        .padding(.vertical, 8)
                    WeekdayHeader()
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    Divider()
                    GeometryReader { geometry in
                        ScrollView {
                            
                            let width = geometry.size.width
                            
                            VStack(alignment: .leading, spacing: 16) {
                                
                                ForEach(months) { section in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(section.title)
                                            .font(.title3.weight(.semibold))
                                            .padding(.horizontal)
                                        
                                        LazyVGrid(columns: gridColumns, spacing: 8) {
                                            ForEach(Array(section.days.enumerated()), id: \.offset) { _, day in
                                                DayCell(day: day, widthCell: (width / 7) - 7)
                                            }
                                        }
//                                        LazyVGrid(columns: gridColumns, spacing: 8) {
//                                            ForEach(section.days) { day in
//                                                DayCell(day: day, widthCell: (width / 7) - 7)
//                                            }
//                                        }
                                        .padding(.horizontal)
                                        .padding(.bottom, 6)
                                    }
                                    .id(sectionID(section))
                                }
                                Spacer(minLength: 24)
                            }
                            .padding(.top, 12)
                        }}
                    .background(Color(.systemGroupedBackground))
                }
                .onChange(of: selectedYear) { _, _ in regenerateYear() }
                .onAppear {
                    // Jump to the month that contains "today" on first load
                    if let idx = months.firstIndex(where: { Calendar.current.isDate(Date(), equalTo: $0.monthDate, toGranularity: .month) }) {
                        proxy.scrollTo(sectionID(months[idx]), anchor: .top)
                    }
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        path.append(Route.choseHabitForStatistics)
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                            .glassEffect()
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .choseHabitForStatistics:
                    SelectHabitsView()
                default:
                    EmptyView()
                        .background(Color.red)
                }
            }
        }
    }
    
    // MARK: - Private methods
    
//    private func header(proxy: ScrollViewProxy) -> some View {
//        HStack(spacing: 12) {
//            // Year picker (±10 years around current)
//            let current = Calendar.current.component(.year, from: Date())
//            Picker("Year", selection: $selectedYear) {
//                ForEach((current-5)...(current), id: \.self) { y in
//                    Text("\(y)").tag(y)
//                }
//            }
//            .pickerStyle(.menu)
//
//            Spacer()
//
//            Button {
//                // Scroll to today's month
//                if let idx = months.firstIndex(where: { Calendar.current.isDate(Date(), equalTo: $0.monthDate, toGranularity: .month) }) {
//                    proxy.scrollTo(sectionID(months[idx]), anchor: .top)
//                }
//            } label: {
//                Label("Today", systemImage: "location.fill")
//            }
//            .labelStyle(.iconOnly)
//            .buttonStyle(.bordered)
//        }
//        .padding(.horizontal)
//        .padding(.vertical, 8)
//        .background(.ultraThinMaterial)
//    }
    
    private func regenerateYear() {
        let start = Calendar.current.date(from: DateComponents(year: selectedYear, month: 1, day: 1))!
        months = builder.makeYear(for: start)
    }
    
    private func sectionID(_ m: MonthSection) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: m.monthDate)
        return "m-\(comps.year ?? 0)-\(comps.month ?? 0)"
    }
}

// MARK: - WeekdayHeader

struct WeekdayHeader: View {
    private var symbols: [String] {
        var cal = Calendar.current
        cal.locale = Locale.current
        let base = cal.shortWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(base[start...] + base[..<start])
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(symbols, id: \.self) { s in
                Text(s)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - DayCell

struct DayCell: View {
    let day: DayItem
    var widthCell: CGFloat
    
    var body: some View {
        ZStack {
            if !day.isEmpty {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: widthCell)
                    .frame(height: 74)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(day.isToday ? Color.blue : Color(.tertiaryLabel),
                                          lineWidth: day.isToday ? 2 : 1)
                    )
            }
            
            VStack(spacing: 6) {
                PillStack(pills: day.pills)
                    .padding(.bottom, 2)
                    .frame(height: 44)
                Text(dayLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 74)
        .opacity(day.inCurrentMonth ? 1.0 : 0.28)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }
    
    private var dayLabel: String {
        guard let date = day.date else { return "" }
        let df = DateFormatter()
        df.setLocalizedDateFormatFromTemplate("dd.MM")
        return df.string(from: date)
    }
    
    private var accessibilityText: String {
        guard let date = day.date else { return "Empty" }
        let df = DateFormatter()
        df.dateStyle = .full
        return "\(df.string(from: date)). \(day.pills.count) items."
    }
}

// MARK: - PillStack

struct PillStack: View {
    let pills: [Pill]
    private let maxVisible = 4
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(pills.prefix(maxVisible))) { pill in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(pill.color)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
            }
            if pills.count > maxVisible {
                Text("+\(pills.count - maxVisible)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

struct YearCalendarScreen_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { YearCalendarScreen() }
            .environment(\.colorScheme, .light)
        
        NavigationStack { YearCalendarScreen() }
            .environment(\.colorScheme, .dark)
    }
}
