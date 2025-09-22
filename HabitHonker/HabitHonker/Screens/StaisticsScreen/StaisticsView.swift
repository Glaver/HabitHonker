//
//  CalendarScreen.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/28/25.
//

import SwiftUI
// MARK: - Views

struct StaisticsView: View {
    @State private var selectedYear: Int
    @State private var path = NavigationPath()

    @StateObject private var viewModel: StatisticsViewModel
    
    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    
    // MARK: - Init
    
    init(viewModel: StatisticsViewModel,
         anchor: Date = Date()) {
        _viewModel = StateObject(wrappedValue: viewModel)
        
        let year = Calendar.current.component(.year, from: anchor)
        _selectedYear = State(initialValue: year)
    }
    
    // MARK: View
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    HabitFilterCollection(viewModel: viewModel)
                    WeekdayHeader()
                        .padding(.horizontal)
                        .padding(.top, 7)
                        .padding(.bottom, 8)
                        .background(Color(.systemGroupedBackground).ignoresSafeArea())//.background(Color(.systemGray6).opacity(0.68)) // REFACTOR: find best solution for background
                    Divider()
                    GeometryReader { geometry in
                        ScrollView {
                            
                            let width = geometry.size.width
                            
                            VStack(alignment: .leading, spacing: 16) {
                                
                                ForEach(viewModel.months) { section in
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
                        }
                    }
                }
                .onChange(of: selectedYear) { _, _ in regenerateYear() }

                .onAppear {
                    Task {
                        await viewModel.loadPresetHabits()
                        viewModel.reloadStatistic()
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        if let idx = viewModel.months.firstIndex(where: {
                            Calendar.current.isDate(Date(), equalTo: $0.monthDate, toGranularity: .month)
                        }) {
                            withAnimation {
                                proxy.scrollTo(sectionID(viewModel.months[idx]), anchor: .top)
                            }
                        }
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
        viewModel.reloadStatistic(anchor: start)
    }
    
    private func sectionID(_ m: MonthSection) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: m.monthDate)
        return "m-\(comps.year ?? 0)-\(comps.month ?? 0)"
    }
}

// MARK: - WeekdayHeader

struct WeekdayHeader: View {
    private var weekday: [String] {
        var cal = Calendar.current
        cal.locale = Locale.current
        let base = cal.shortWeekdaySymbols
        let start = cal.firstWeekday - 1
        return Array(base[start...] + base[..<start])
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekday, id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - PillStack
//
//struct PillStack: View {
//    let pills: [Pill]
//    private let maxVisible = 4
//    
//    var body: some View {
//        HStack(spacing: 1) {
//            ForEach(Array(pills.prefix(maxVisible))) { pill in
//                RoundedRectangle(cornerRadius: 5, style: .continuous)
//                    .fill(pill.color)
//                    .frame(height: 40)
//                    .frame(maxWidth: .infinity)
//            }
//            if pills.count > maxVisible {
//                Text("+\(pills.count - maxVisible)")
//                    .font(.caption2.weight(.bold))
//                    .foregroundStyle(.secondary)
//            }
//        }
//    }
//}

struct PillStack: View {
    let pills: [Pill]
    private let maxVisible = 4
    @State private var shown = 0
    
    var body: some View {
        HStack(spacing: 1) {
            ForEach(Array(pills.prefix(min(shown, maxVisible)))) { pill in
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(pill.color)
                    .frame(height: 40)
                    .frame(maxWidth: .infinity)
                    .transition(.scale.combined(with: .opacity))
            }
            
            if pills.count > maxVisible {
                Text("+\(pills.count - maxVisible)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
            }
        }
        .onAppear { animateIn() }
        .onChange(of: pills) {
            shown = 0
            animateIn()
        }
    }
    
    private func animateIn() {
        for i in 0..<min(pills.count, maxVisible) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.25 * Double(i))) {
                shown = i + 1
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
