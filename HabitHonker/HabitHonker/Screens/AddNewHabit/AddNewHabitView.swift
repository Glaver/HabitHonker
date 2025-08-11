//
//  AddNewHabit.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/8/25.
//

import SwiftUI
import SwiftData

struct AddNewHabitView: View {
    @State var item: ListHabitItem
    @State var advancedOptions: ListHabitItem.HabitType = .repeating
    @State private var repeatHabit = RepeatHabit(weekdays: [.monday, .wednesday, .friday])
    @State var dueDate: Date = Date()
    @Environment(\.presentationMode) var presentationMode
    
    let columns = [
        GridItem(.flexible()), // 1st column
        GridItem(.flexible())  // 2nd column
    ]
    
    var body: some View {
        List {
            Section() {
                TextField("Name", text: $item.title)
                //                        .textFieldStyle(RoundedBorderTextFieldStyle())
                //                        .padding(.bottom, 5)
                
                TextField("Description", text: $item.description)
                //                    .textFieldStyle(RoundedBorderTextFieldStyle())
                //                    .padding(.bottom, 5)
            }
            
            NavigationLink(value: Route.detailHabit) {
                Section() {
                    HStack{
                        Text("Icon")
                        Spacer()
                        ZStack {
                            Image("empty_icon")//item.icon ??
                                .font(Font.title)
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.gray.opacity(0.2))
                                .shadow(color: .black.opacity(0.45), radius: 3, x: 1, y: 1)
                                .frame(width: 42, height: 42)
                        }
                    }
                }
            }
            
            Section() {
                VStack() {
                    Text("Select priority")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(ListHabitItem.PriorityEisenhower.allCases, id: \.self) { index in
                            PriorityCell(title: index.text, priorityColor: index.color, isSelected: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            }
            
            
            Section(header: Text("Advanced Options")) {
                VStack {
                    Picker("Priority", selection: $advancedOptions) {
                        ForEach(ListHabitItem.HabitType.allCases, id: \.self) { type in
                            Text(type.text)
                        }
                    }
                    .pickerStyle(.palette)
                    if advancedOptions == .dueDate {
                        DatePicker(
                            "Start Date",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                    } else {
                        WeekdayPicker(selection: $repeatHabit.weekdays)
                        // MARK: !!!
                    }
                }
            }
            
            Section() {
                Text("Schedule notification")
                Text("Time")
            }
        }
        .listStyle(.insetGrouped)
    }
}

#Preview {
    AddNewHabitView(item: ListHabitItem(icon: "person.crop.circle",
                                        title: "",
                                        description: "",
                                        priority: .notUrgentAndNotImportant,
                                        type: .repeating),
                                        dueDate: Date())
        .modelContainer(for: Item.self, inMemory: true)
}







enum Weekday: Int, CaseIterable, Codable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    var shortSymbol: String {
        let idx = rawValue - 1 // DateFormatter symbols are 0-based
        return DateFormatter().shortWeekdaySymbols[idx]
    }
}

struct RepeatHabit: Codable, Equatable {
    var weekdays: Set<Weekday> = []        // e.g. [.monday, .wednesday, .friday]
}

extension Calendar {
    func weekday(for date: Date) -> Weekday {
        Weekday(rawValue: component(.weekday, from: date))!
    }
}






struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>
    var calendar: Calendar = .current

    private var orderedWeekdays: [Weekday] {
        // Respect the user’s locale firstWeekday in ordering
        let start = calendar.firstWeekday // 1...7
        return (0..<7).compactMap { Weekday(rawValue: ((start - 1 + $0) % 7) + 1) }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(orderedWeekdays, id: \.rawValue) { day in
                let isOn = selection.contains(day)
                Text(day.shortSymbol.uppercased())
                    .lineLimit(1)
                    .font(.caption).monospaced()
                    .padding(.vertical, 17)
                    .padding(.horizontal, 5)
                    .background(Capsule().fill(isOn ? Color.accentColor.opacity(0.2) : .clear))
//                    .overlay(Capsule().stroke(isOn ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: 1))
                    .onTapGesture {
                        if isOn { selection.remove(day) } else { selection.insert(day) }
                    }
                    .accessibilityLabel(Text(day.shortSymbol))
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .glassEffect()
                
            }
        }
        
    }
}


/*.buttonStyle(.plain)
 .glassEffect()
 .overlay(
     RoundedRectangle(cornerRadius: 30, style: .continuous)
         .stroke(priorityColor.opacity(0.8), lineWidth: 0.2)
 )
 .shadow(color: priorityColor.opacity(0.8), radius: 5, x: 0, y: 0)*/
