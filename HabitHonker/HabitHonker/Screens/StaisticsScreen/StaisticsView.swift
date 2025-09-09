//
//  CalendarScreen.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/28/25.
//

import SwiftUI
// MARK: - Views

struct StaisticsView: View {
    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    
    @State private var selectedYear: Int
    @State private var months: [MonthSection]
    @State private var path = NavigationPath()
    
    @StateObject private var viewModel: StatisticsViewModel
    
    private let builder = CalendarBuilder()
    
    init(viewModel: StatisticsViewModel,
         anchor: Date = Date()) {
        _viewModel = StateObject(wrappedValue: viewModel)
        
        let year = Calendar.current.component(.year, from: anchor)
        _selectedYear = State(initialValue: year)
        let start = Calendar.current.date(from: DateComponents(year: year, month: 1, day: 1))!
        _months = State(initialValue: CalendarBuilder().makeYear(for: start))
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.items) { item in
                                HStack(spacing: 6) {
                                    Image(item.icon ?? "empty_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 30)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 3)
                                .background(item.priority.color)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
//                    HabitFilterCollection()
                    .padding(.bottom, 8)
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
                    
                    Task {
                        await viewModel.loadPresetHabits()
                    }
                    
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
                        SelectHabitsView(viewModel: SelectHabitsViewModel(repo: viewModel.repo))
                default:
                    EmptyView()
                        .background(Color.red)
                }
            }
        }
    }
    
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
//
//struct YearCalendarScreen_Previews: PreviewProvider {
//    static var previews: some View {
//        NavigationStack { StaisticsView() }
//            .environment(\.colorScheme, .light)
//        
//        NavigationStack { StaisticsView() }
//            .environment(\.colorScheme, .dark)
//    }
//}
