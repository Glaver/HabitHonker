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
    @State var isScheduled: Bool = false
    @State private var isIconsSheetPresented: Bool = false
    @State var isPresented: String? = nil
    
    @Environment(\.presentationMode) var presentationMode
    
    let icons = ["checkmark","checkmark.circle","checkmark.circle.fill","checkmark.square","checkmark.square.fill","checkmark.seal","checkmark.seal.fill","circle","square","list.bullet","list.number","list.bullet.rectangle","calendar","calendar.badge.clock","bell","bell.fill","bell.badge","alarm","alarm.fill","clock","stopwatch","timer","hourglass","hourglass.bottomhalf.filled","pencil","square.and.pencil","note.text","flag","bookmark","repeat"]
    
    var body: some View {
        List {
            Section() {
                TextField("Name", text: $item.title)
                TextField("Description", text: $item.description)
            }
            
            
                Section() {
                    HStack{
                        Button("Icon") {
                            isIconsSheetPresented.toggle()
                        }
                        .foregroundColor(.gray)
                        
                        Spacer()
                        ZStack {
                            Image(item.icon != "" ? "empty_icon" : item.icon)//item.icon ??
                                .font(Font.title)
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .fill(Color.gray.opacity(0.2))
                                .shadow(color: .black.opacity(0.45), radius: 3, x: 1, y: 1)
                                .frame(width: 42, height: 42)
                        }
                    }
                }
            
            
            Section() {
                VStack() {
                    Text("Select priority")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
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
                    }
                }
            }
            
            Section() {
                Toggle("Schedule notification", isOn: $isScheduled)
                if advancedOptions != .dueDate {
                    DatePicker(
                        "Time",
                        selection: $dueDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .disabled(!isScheduled)
                    
                }
            }
            .listStyle(.insetGrouped)
        }
        .sheet(isPresented: $isIconsSheetPresented) {
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(icons, id: \.self) { icon in
                    Image(systemName: icon)
                        .font(.system(size: 35))
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .cornerRadius(10)
                        .onTapGesture {
                            print(icon)
                        }
                }
            }
            .presentationDetents([.large])
        }
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
