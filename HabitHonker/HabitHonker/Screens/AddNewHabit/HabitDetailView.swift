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
    private let item: HabitModel?
    private let mode: HabitScreenMode
    
    @State var icon: String?
    @State var iconColor: Color
    @State var title: String
    @State var description: String
    @State var tags: [String] = []
    @State var priority: PriorityEisenhower
    @State var type: HabitType
    @State var repeating: Set<Weekday>
    @State var dueDate: Date
    @State var isNotificationActivated: Bool

    private(set) var colors: [Color] = [.red, .yellow, .blue, .green]
    private(set) var titles: [String] = ["", "", "", ""]
    
    @State private var isIconsSheetPresented: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    
    var sectionBackgroundColor: Color {
        colorSchema == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground)
    }
    var backgroundColor: Color {
        colorSchema == .dark ? Color(UIColor.systemBackground) : Color(UIColor.secondarySystemBackground)
    }
    
    private let saveAction: (HabitModel) -> Void
    private let deleteAction: (HabitModel) -> Void
    
    @Environment(\.colorScheme) var colorSchema
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    private func savedItem() -> HabitModel {
        if var oldItem = item {
            oldItem.icon = icon
            oldItem.iconColor = iconColor
            oldItem.title = title
            oldItem.description = description
            oldItem.tags = tags
            oldItem.priority = priority
            oldItem.type = type
            oldItem.repeating = repeating
            oldItem.dueDate = dueDate
            oldItem.isNotificationActivated = isNotificationActivated
            return oldItem
        } else {
            return HabitModel(id: UUID(),
                              icon: icon,
                              iconColor: iconColor,
                              title: title,
                              description: description,
                              tags: tags,
                              priority: priority,
                              type: type,
                              repeating: repeating,
                              dueDate: dueDate,
                              notificationActivated: isNotificationActivated,
                              record: [])
        }
        
    }
    
    static func editItemView(
        from model: HabitModel,
        priorityColors: [Color],
        priorityTitles: [String],
        saveAction: @escaping (HabitModel) -> Void,
        deleteAction: @escaping (HabitModel) -> Void,
    ) -> Self {
        return .init(
            item: model,
            mode: .detailScreen,
            icon: model.icon,
            iconColor: model.iconColor,
            title: model.title,
            description: model.description,
            tags: model.tags,
            priority: model.priority,
            type: model.type,
            repeating: model.repeating,
            dueDate: model.dueDate,
            isNotificationActivated: model.isNotificationActivated,
            colors: priorityColors,
            titles: priorityTitles,
            saveAction: saveAction,
            deleteAction: deleteAction
        )
    }

    
    
    static func creatNewItemView(
        priorityColors: [Color],
        priorityTitles: [String],
        saveAction: @escaping (HabitModel) -> Void,
        deleteAction: @escaping (HabitModel) -> Void,
    ) -> Self {
        .init(
            item: nil,
            mode: .addNewHabit,
            icon: nil,
            iconColor: Color.random,
            title: "",
            description: "",
            tags: [],
            priority: .importantAndUrgent,
            type: .repeating,
            repeating: Weekday.allSet,
            dueDate: Date(),
            isNotificationActivated: false,
            colors: priorityColors,
            titles: priorityTitles,
            saveAction: saveAction,
            deleteAction: deleteAction
        )
    }
    
    // MARK: View
    var body: some View {
        List {
            Section {
                VStack() {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Constants.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: 20)
                        TextField("", text: $title)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 36)
                    }
                    .padding(.vertical, 3)
                    
                    Divider()
                        .frame(height: 1)
                        .foregroundColor(.gray.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Constants.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(height: 20)
                        
                        TextField("", text: $description)
                            .textFieldStyle(.plain)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: 36)
                    }
                    .padding(.vertical, 3)
                }
                .padding(.horizontal, 10)
            }
            .listRowBackground(sectionBackgroundColor)
            .cornerRadius(26)
            
            // MARK: Icon picker
            Section {
                Button {
                    isIconsSheetPresented.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Text(Constants.icon)
                        Spacer()
                        ZStack {
                            Image(icon ?? "empty_icon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundStyle(.primary)
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
                        }
                        Image(systemName: "chevron.right").frame(width: 6, height: 22)
                            .tint(.gray.opacity(0.5))
                    }
                }
                .buttonStyle(.plain)
                
                // MARK: ColorPicker
                
                HStack {
                    ColorPicker("Select a color for Statistics", selection: $iconColor)
                        .padding(.trailing, 10)
                        .padding(.vertical, 5)
                    Image(systemName: "chevron.right").frame(width: 6, height: 22)
                        .tint(.gray.opacity(0.5))
                    
                }
            }
            .listRowBackground(sectionBackgroundColor)
            
            // MARK: PriorityPicker
            
            Section {
                VStack {
                    Text(Constants.selectPriorit)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    PriorityPicker(priorityEisenhower: $priority,
                                   priorityColors: colors,
                                   priorityTitles: titles)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(15)
                .padding(.vertical, 10)
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 10, trailing: 0))
            .listRowBackground(sectionBackgroundColor)
            .cornerRadius(26)
            
            // MARK: Advanced Options
            
            Section {
                VStack {
                    Text(Constants.advancedOption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    Picker(Constants.priority, selection: $type) {
                        ForEach(HabitType.allCases, id: \.self) { type in
                            Text(type.text)
                        }
                    }
                    .pickerStyle(.segmented)
                    if type == .dueDate {
                        DatePicker(
                            Constants.startDate,
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                    } else {
                        WeekdayPicker(selection: $repeating, color: colors[priority.index])
                    }
                }
                .padding(10)
            }
            .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 15, trailing: 0))
            .cornerRadius(26)
            .listRowBackground(sectionBackgroundColor)
            
            // MARK: Schedule notification
            Section {
                VStack {
                    Toggle(Constants.scheduleNotificatio, isOn: $isNotificationActivated)
                        .padding(.vertical, 10)
                    if type != .dueDate {
                        Rectangle()
                            .foregroundStyle(.gray.opacity(0.3))
                            .frame(maxWidth: .infinity)
                            .frame(height: 1)
                        DatePicker(
                            Constants.time,
                            selection: $dueDate,
                            displayedComponents: [.hourAndMinute]
                        )
                        .disabled(!isNotificationActivated)
                        
                    }
                }
                .padding(.horizontal, 10)
            }
            .cornerRadius(26)
            .listRowBackground(sectionBackgroundColor)
            
            PrimaryButton(title: Constants.save, color: .blue, foregroundStyle: .white) {
                saveAction(savedItem())
                dismiss()
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            
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
                                self.icon = icon
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
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)     // smoother scroll/keyb interaction
        .ignoresSafeArea(.keyboard, edges: .bottom)  // avoid layout fights with insets
        .listStyle(.insetGrouped)
        .background(backgroundColor)
        .toolbar(.hidden, for: .tabBar)
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
                deleteAction(savedItem())
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
    NavigationView {
        HabitDetailView.creatNewItemView(
            priorityColors: [.red, .yellow, .blue, .green],
            priorityTitles: ["Urgent", "Important", "Later", "Optional"],
            saveAction: { model in
                print("Save new habit:", model.title)
            },
            deleteAction: { model in
                print("Delete habit:", model.title)
            }
        )
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



extension View {
    func pillRow(height: CGFloat = 62) -> some View {
        self
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height) // single source of truth
            .background(
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color("cellContentColor"))
            )
            .contentShape(RoundedRectangle(cornerRadius: 26)) // full-surface tap
        // make List not add its own spacing/background:
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 12, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
