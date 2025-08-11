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
            
            Section(header: Text("Priority")) {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(ListHabitItem.PriorityEisenhower.allCases, id: \.self) { index in
                        PriorityCell(title: index.text, priorityColor: index.color, isSelected: true)
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
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
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
