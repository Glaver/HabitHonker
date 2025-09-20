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

    private let mode: HabitScreenMode
    
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
                        .foregroundStyle(Color("cellContentColor"))
                    
                    VStack() {
                        VStack(alignment: .leading) {
                            Text(Constants.name)
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
                            Text(Constants.description)
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
                            .foregroundStyle(Color("cellContentColor"))
                        
                        HStack {
                            Text(Constants.icon)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            ZStack {
                                Image(item.icon ?? "empty_icon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .foregroundColor(.primary)
                                    .frame(width: 24, height: 24)
                                    .zIndex(2)
                                
                                RoundedRectangle(cornerRadius: 20)
                                    .frame(width: 42, height: 42)
                                    .foregroundStyle(Color("cellContentColor"))
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
                        .foregroundStyle(Color("cellContentColor"))
                    VStack {
                        Text(Constants.selectPriorit)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
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
                
                // MARK: Advanced Options
                
                ZStack {
                    RoundedRectangle(cornerRadius: 26)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(Color("cellContentColor"))
                    
                    VStack {
                        Text(Constants.advancedOption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Picker(Constants.priority, selection: $item.type) {
                            ForEach(HabitModel.HabitType.allCases, id: \.self) { type in
                                Text(type.text)
                                
                            }
                        }
                        
                        .pickerStyle(.palette)
                        if item.type == .dueDate {
                            DatePicker(
                                Constants.startDate,
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
                        .foregroundColor(Color("cellContentColor"))
                    VStack {
                        Toggle(Constants.scheduleNotificatio, isOn: $item.isNotificationActivated)
                            .padding(.vertical, 10)
                        if item.type != .dueDate {
                            Rectangle()
                                .foregroundStyle(.gray.opacity(0.3))
                                .frame(maxWidth: .infinity)
                                .frame(height: 1)
                            DatePicker(
                                Constants.time,
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
                
                PrimaryButton(title: Constants.save, color: .blue, foregroundStyle: .white) {
                    saveAction(item)
                    dismiss()
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGray6))
        }
        .sheet(isPresented: $isIconsSheetPresented) {
            // MARK: Icons bottom sheet view
            ScrollView { // REFACTOR NEED MOVE TO SEPARATE VIEW
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(HabitDetailView.icons, id: \.self) { icon in
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
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .presentationDetents([.large])
            }
            .navigationTitle(Constants.detailScreen)
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
            .alert(Constants.deleteHabit, isPresented: $showDeleteConfirmation) {
                Button(Constants.delete, role: .destructive) {
                    deleteAction(item)
                    dismiss()
                }
                Button(Constants.cancel, role: .cancel) { }
            } message: {
                Text(Constants.areYouSureDelete)
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

extension HabitDetailView {
    enum Constants {
        static let name = "Name"
        static let description = "Description"
        static let icon = "Icon"
        static let selectPriorit = "Select priority"
        static let advancedOption = "Advanced Options"
        static let priority = "Priority"
        static let startDate = "Start Date"
        static let scheduleNotificatio = "Schedule notification"
        static let time = "Time"
        static let save = "Save"
        static let detailScreen = "Detail screen"
        static let deleteHabit = "Delete Habit"
        static let delete = "Delete"
        static let cancel = "Cancel"
        static let areYouSureDelete = "Are you sure you want to delete this habit? This action cannot be undone."
    }
}
// Icon pack
extension HabitDetailView {
    static let icons: [String] = ["academic-cap","alarm","alien","archive-box","atom","attachment","augmented-reality","avocado","axe","baby-carriage","baby","backpack","balloon","bank-card-fill","bank","bao-bun","basketball","bathroom","battery-charging","bed","biceps-flexed","bill","bluetooth","boarding-pass","boat","bolt","bone","brand-dropbox-fill","brand-github-fill","brand-github-mascot-fill","brand-instagram-fill","brand-linkedin-fill","brand-open-ai-fill","brandy","bread","cable-car","calendar-dates","call","campfire","car-alt-2","cell-signal","checklist","cheers","chef-hat","clover","club","cocktail","coffee-bean","coin","cornflakes","cyclist","disconnect","discount-alt","dna","dress","drill","drone","drop","drum","electric-car-charging","elephant","eye","face-angry","face-love","face-very-happy","fan","film-slate","fingerprint","fire-extinguisher","fire-truck","fishing","flask","flying-saucer","game-controller","generate","ghost","give","guitar","hammer","head-circuit","headphones","ice-cream","justice","magic-wand-ai","mailbox","navigation-north-east","office-chair","office","paint-roller","passport","pig","pizza-slice","plane","planet","plant","print","rain","rocket-ship","satellite","savings","scissors","speakers","split","sunrise","sunset","surveillance-cameras-two","sword-alt","telescope","temperature","tire","toilet-paper","toilet","tooth","tour-bus","train","transfer","tulip","tv","umbrella","university-hat-simple","unlock","vault","vial","virus","wallet","washing-machine","weight","wheelchair-alt","wifi","wind","world","yen"]
}
