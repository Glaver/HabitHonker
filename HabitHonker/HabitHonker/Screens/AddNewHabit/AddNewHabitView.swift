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
    @State private var isIconsSheetPresented: Bool = false
    @ViewBuilder private let saveButton: (() -> SaveButton)
    private let saveAction: (ListHabitItem) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    let icons = ["axe", "cheers", "dna", "campfire", "cyclist"]
    
    init(item: ListHabitItem,
        saveAction: @escaping (ListHabitItem) -> Void,
         @ViewBuilder saveButton: @escaping () -> SaveButton) {
        self._item = State(initialValue: item)
        self.saveAction = saveAction
        self.saveButton = saveButton
    }
    
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
                        Image(item.icon ?? "")
                            .font(Font.title)
                            .frame(width: 20, height: 20)
                        
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
                    PriorityPicker(priorityEisenhower: $item.priority)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Section(header: Text("Advanced Options")) {
                VStack {
                    Picker("Priority", selection: $item.type) {
                        ForEach(ListHabitItem.HabitType.allCases, id: \.self) { type in
                            Text(type.text)
                            
                        }
                    }
                    .pickerStyle(.palette)
                    if item.type == .dueDate {
                        DatePicker(
                            "Start Date",
                            selection: $item.dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                    } else {
                        WeekdayPicker(selection: $item.repeting)
                    }
                }
            }
            
            Section() {
                Toggle("Schedule notification", isOn: $item.notificationActivated)
                if item.type != .dueDate {
                    DatePicker(
                        "Time",
                        selection: $item.dueDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .disabled(!item.notificationActivated)
                    
                }
            }
            .listStyle(.insetGrouped)
            
//            Section() {
                //                RoundedRectangle(cornerRadius: 100, style: .continuous)
                Button("Save") {
                    saveAction(item)
                    print("hoy")
                    dismiss()
                }
                .listRowInsets(EdgeInsets())
                .frame(maxWidth: .infinity, maxHeight: 50)
                .multilineTextAlignment(.center)
                .background(Color.blue)
                .tint(Color.black)
                .scaledToFill()
            
        }
        .sheet(isPresented: $isIconsSheetPresented) {
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(icons, id: \.self) { icon in
                    Image(icon)
                        .font(.system(size: 35))
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .cornerRadius(10)
                        .onTapGesture {
                            item.icon = icon
                            isIconsSheetPresented = false
                        }
                }
            }
            .presentationDetents([.large])
        }
    }
}

#Preview {
    AddNewHabitView(
        item: ListHabitItem(icon: "circle",
                            iconColor: .red,
                            title: "Fly with dragon",
                            description: "That is the only way",
                            priority: .importantAndUrgent,
                            type: .repeating,
                            repeting: Set<Weekday>(),
                            dueDate: Date()),
        saveAction: { _ in },
        saveButton: {
            SaveButton() {
                print("sss")
            }
        }
    )
            .modelContainer(for: Item.self, inMemory: true)
}


struct SaveButton: View {
    let action: () -> Void

    var body: some View {
        Button("Save") {
            action()
        }
    }
}
