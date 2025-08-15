//
//  ListHabitItem.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/4/25.
//
import Foundation
import SwiftUI

struct ListHabitItem: Identifiable, Equatable {
    var id: UUID
    var icon: String?
    var iconColor: Color?
    var title: String
    var description: String
    var priority: PriorityEisenhower
    var type: HabitType
    var repeating: Set<Weekday>
    var dueDate: Date
    var notificationActivated: Bool = false
    var record: [HabitRecord] = []
    var isCompletedToday: Bool { isCompleted(on: Date()) }
    
    mutating func completeHabitNow() {
        let today = Date()
        print("Completing habit: \(title)")
        print("Current records count: \(record.count)")
        
        if let existingIndex = record.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            // Increment count for existing record
            print("Found existing record for today, incrementing count from \(record[existingIndex].count)")
            record[existingIndex].count += 1
            print("New count: \(record[existingIndex].count)")
        } else {
            // Create new record for today
            print("Creating new record for today")
            let newRecord = HabitRecord(date: today, count: 1)
            print("New record: id=\(newRecord.id), date=\(newRecord.date), count=\(newRecord.count)")
            record.append(newRecord)
        }
        
        print("Total records after completion: \(record.count)")
    }
    
    func isCompleted(on date: Date) -> Bool {
        record.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
    }
    
    func getTodayCount() -> Int {
        let today = Date()
        return record.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })?.count ?? 0
    }
    
    init(id: UUID = UUID(), icon: String? = nil, iconColor: Color? = nil, title: String = "", description: String = "", priority: PriorityEisenhower = .importantAndUrgent, type: HabitType = .repeating, repeating: Set<Weekday> = Weekday.allSet, dueDate: Date = Date(), notificationActivated: Bool = false, record: [HabitRecord] = []) {
        self.id = id
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.priority = priority
        self.type = type
        self.repeating = repeating
        self.dueDate = dueDate
        self.notificationActivated = notificationActivated
        self.record = record
    }
}

extension ListHabitItem {
    struct HabitRecord: Identifiable, Codable, Equatable {
        var id: UUID
        var date: Date
        var count: Int
        
        init(id: UUID = UUID(), date: Date, count: Int) {
            self.id = id
            self.date = date
            self.count = count
        }
        
        /// MARK: this entity will be extended by specific needs(properties) of tasks or habits in future
    }
}

extension ListHabitItem {
    enum HabitType: Int, CaseIterable {
        case dueDate
        case repeating
        
        var text: String {
            switch self {
            case .dueDate:
                return "Due Date"
            case .repeating:
                return "Repeating"
            }
        }
    }
}

extension ListHabitItem {
    enum PriorityEisenhower: Int, CaseIterable {
        case importantAndUrgent
        case importantButNotUrgent
        case urgentButNotImportant
        case notUrgentAndNotImportant
        
        var text: String {
            switch self {
            case .importantAndUrgent:
                return "Important / Urgent"
            case .importantButNotUrgent:
                return "Important / Not Urgent"
            case .urgentButNotImportant:
                return "Urgent / Not Important"
            case .notUrgentAndNotImportant:
                return "Not Urgent / Not Important"
            }
        }
        
        var color: Color {
            switch self {
            case .importantAndUrgent:
                return .red
            case .importantButNotUrgent:
                return .blue
            case .urgentButNotImportant:
                return .yellow
            case .notUrgentAndNotImportant:
                return .green
            }
        }
        
        var colorsNasty: Color {
            switch self {
            case .importantAndUrgent:
                return Color.honkerRed
            case .importantButNotUrgent:
                return Color.goldenGooseYellow
            case .urgentButNotImportant:
                return Color.charcoalWingGray
            case .notUrgentAndNotImportant:
                return Color.warmFeatherBeige
            }
        }
        
//        var color: Color {
//            switch self {
//            case .importantAndUrgent:
//                return Color.honkerRed
//            case .importantButNotUrgent:
//                return Color.goldenGooseYellow
//            case .urgentButNotImportant:
//                return Color.charcoalWingGray
//            case .notUrgentAndNotImportant:
//                return Color.warmFeatherBeige
//            }
//        }
    }
}

extension ListHabitItem {
    static func mock() -> ListHabitItem {
        .init(
            icon: "empty_icon",
            iconColor: .clear,
            title: "",
            description: "",
            priority: .notUrgentAndNotImportant,
            type: .repeating,
            repeating: .init(Weekday.all),
            dueDate: Date())
    }
}

extension ListHabitItem {
    static func mock() -> [ListHabitItem] {
        [.init(
            icon: "axe",
            iconColor: ListHabitItem.PriorityEisenhower.importantButNotUrgent.color,
            title: "Meditation",
            description: "",
            priority: .importantButNotUrgent,
            type: .repeating,
            repeating: Set<Weekday>(),
            dueDate: Date()
        ),
         .init(icon: "cheers",
               iconColor: ListHabitItem.PriorityEisenhower.urgentButNotImportant.color,
               title: "Wash dishes, vacuum floor, laundry, etc",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeating: Set<Weekday>(),
               dueDate: Date()
        ),
         .init(icon: "dna",
               iconColor: ListHabitItem.PriorityEisenhower.importantAndUrgent.color,
               title: "Learn System Design",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeating: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: false
        ),
         .init(icon: "campfire",
               iconColor: ListHabitItem.PriorityEisenhower.importantButNotUrgent.color,
               title: "Swift 6.2",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeating: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: true
        ),
         .init(icon: "campfire",
               iconColor: ListHabitItem.PriorityEisenhower.importantButNotUrgent.color,
               title: "Candle puring",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .repeating,
               repeating: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: false
        ),
         .init(icon: "cyclist",
               iconColor: ListHabitItem.PriorityEisenhower.notUrgentAndNotImportant.color,
               title: "Balance board",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeating: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: false
        ),
         .init(icon: "cyclist",
               iconColor: ListHabitItem.PriorityEisenhower.importantAndUrgent.color,
               title: "Algorithms",
               description: "",
               priority: .importantAndUrgent,
               type: .repeating,
               repeating: Set<Weekday>(),
               dueDate: Date()
        )]
    }
}
