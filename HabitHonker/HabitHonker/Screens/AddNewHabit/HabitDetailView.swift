//
//  HabitDetailView.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/8/25.
//

import SwiftUI
import SwiftData

extension HabitDetailView {
    enum HabitScreenMode {
        case addNewHabit
        case detailScreen
    }
}

struct HabitDetailView: View {
    @State var item: HabitModel
    @State private var isIconsSheetPresented: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @ViewBuilder private let saveButton: (() -> SaveButton)
    private let saveAction: (HabitModel) -> Void
    private let deleteAction: (HabitModel) -> Void
    
    @Environment(\.colorScheme) var colorSchema
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    let icons = ["academic-cap", "alarm", "alien", "archive-box", "atom", "attachment", "augmented-reality", "avocado", "axe", "baby-carriage", "baby"]
    let mode: HabitScreenMode
    
    init(item: HabitModel,
         mode: HabitScreenMode,
         saveAction: @escaping (HabitModel) -> Void,
         deleteAction: @escaping (HabitModel) -> Void,
         @ViewBuilder saveButton: @escaping () -> SaveButton) {
        self._item = State(initialValue: item)
        self.mode = mode
        self.deleteAction = deleteAction
        self.saveAction = saveAction
        self.saveButton = saveButton
    }
    // MARK: View
    var body: some View {
        
            ScrollView {
                LazyVStack (spacing: 20) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                        
                        VStack() {
                            VStack(alignment: .leading) {
                                Text("Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(height: 22)
                                
                                TextField("", text: $item.title)
                                    .textFieldStyle(.plain) // or .roundedBorder
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 30)
                            }
                            
                            Rectangle()
                                .foregroundStyle(.gray.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: 1)
                            
                            VStack(alignment: .leading) {
                                Text("Description")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(height: 22)
                                
                                TextField("", text: $item.description)
                                    .textFieldStyle(.plain) // or .roundedBorder
                                    .font(.system(size: 17, weight: .medium, design: .rounded))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .frame(height: 30)
                            }
                        }
                        
                        .padding(10)
                        
                    }
                    .padding(.horizontal, 10)
                    
                    // MARK: Icon picker
                    
                    
                    Button {
                        isIconsSheetPresented.toggle()
                    } label: {
                    ZStack{
                        RoundedRectangle(cornerRadius: 26)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 62)
                            .foregroundStyle(.white)
                        
                        HStack {
                            Text("Icon")
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            ZStack {
                                Image(item.icon ?? "")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 24, height: 24)
                                    .zIndex(2)
                                
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(.white)
                                    .frame(width: 42, height: 42)
                                    .shadow(color: .gray.opacity(0.3), radius: 6, x: 1, y: 1)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                    )
                                    .zIndex(1)
                                
                            }
                            Image(systemName: "chevron.right")
                                .scaledToFill()
                                .frame(width: 6, height: 22)
                                .tint(Color.gray.opacity(0.5))
                        }
                        .padding(.horizontal, 10)
                    }
                    .padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain) // prevents shrinking/tinting
                    .frame(maxWidth: .infinity)
                    .zIndex(3)
                    
                    
                    // MARK: PriorityPicker
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.clear)
                        VStack {
                            Text("Select priority")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                            PriorityPicker(priorityEisenhower: $item.priority)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(10)
                        .padding(.vertical, 10)
                    }
                    
                    .background(.white)
                    .cornerRadius(26)
                    .padding(.horizontal, 10)
                    //                }
                    
                    // MARK: Advanced Options
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.clear)
                        
                        VStack {
                            Text("Advanced Options")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Picker("Priority", selection: $item.type) {
                                ForEach(HabitModel.HabitType.allCases, id: \.self) { type in
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
                                WeekdayPicker(selection: $item.repeating, color: item.priority.color)
                            }
                        }
                        //                    .padding(.horizontal, 10)
                        .padding(10)
                    }
                    .background(.white)
                    .cornerRadius(26)
                    .padding(.horizontal, 10)
                    
                    // MARK: Schedule notification
                    ZStack {
                        RoundedRectangle(cornerRadius: 26)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.clear)
                        VStack {
                            Toggle("Schedule notification", isOn: $item.isNotificationActivated)
//                                .padding(.top, 10)
                                .padding(.vertical, 10)
                            if item.type != .dueDate {
                                Rectangle()
                                    .foregroundStyle(.gray.opacity(0.3))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 1)
//                                    .padding(.top, 20)
                                DatePicker(
                                    "Time",
                                    selection: $item.dueDate,
                                    displayedComponents: [.hourAndMinute]
                                )
                                .datePickerStyle(.graphical)
                                .disabled(!item.isNotificationActivated)
                                
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    //                .padding(.horizontal, 10)
                    .background(.white)
                    .cornerRadius(26)
                    .padding(.horizontal, 10)
                    
                    Button("Save") {
                        saveAction(item)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .multilineTextAlignment(.center)
                    .tint(Color.black)
                    .cornerRadius(26)
                    .padding(.horizontal, 10)
                    .background(.blue.opacity(0.6))
                    .cornerRadius(26)
                    .glassEffect(.regular, in: Capsule())
                    .shadow(color: .blue.opacity(0.7), radius: 5, x: 2, y: 2)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 20)
                }
                .background(Color(.systemGray6))
            }
        
            .sheet(isPresented: $isIconsSheetPresented) {
                // MARK: Icons bottom sheet view
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(icons, id: \.self) { icon in
                        Image(icon)
                            .font(.system(size: 35))
                            .font(.largeTitle)
                            .frame(maxWidth: .infinity, minHeight: 80)
                            .cornerRadius(10)
                            .onTapGesture {
                                item.icon = icon
                                    print(icon)
                                isIconsSheetPresented = false
                            }
                    }
                }
                .presentationDetents([.large])
            }
            .navigationTitle("Detail screen")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGray6))
            .toolbar { // MARK: ToolbarItem
                if mode == .detailScreen {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showDeleteConfirmation.toggle()
                        }) {
                            Image(systemName: "trash")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(Color(UIColor.systemRed).opacity(0.7))
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            }// MARK: Alert Delete Habit
            .alert("Delete Habit", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteAction(item)
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this habit? This action cannot be undone.")
            }
    }
}

// MARK: Preview
#Preview {
    HabitDetailView(
        item: HabitModel(icon: "atom",
                         iconColor: .red,
                         title: "Fly on a dragon",
                         description: "That is the only way",
                         priority: .importantAndUrgent,
                         type: .repeating,
                         repeating: Set<Weekday>(),
                         dueDate: Date()),
        mode: .detailScreen,
        saveAction: { _ in },
        deleteAction: { _ in},
        saveButton: {
            SaveButton() {
                print("sss")
            }
        }
    )
}


struct SaveButton: View {
    let action: () -> Void
    
    var body: some View {
        Button("Save") {
            action()
        }
    }
}
