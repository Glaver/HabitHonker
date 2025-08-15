//
//  ListHabitItem.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/4/25.
//
import Foundation
import SwiftUI

struct ListHabitItem: Identifiable, Equatable {
    let id = UUID()
    var icon: String?
    var iconColor: Color?
    var title: String
    var description: String
    var priority: PriorityEisenhower
    var type: HabitType
    var repeting: Set<Weekday>
    var dueDate: Date
    var notificationActivated: Bool = false
    var record: [HabitRecord] = []
    
    mutating func completeHabitNow() {
        self.record.append(.init(date: Date(), count: 1))
    }
    
    func isCompleted(on date: Date) -> Bool {
        record.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
    }
    
    init(icon: String? = nil, iconColor: Color? = nil, title: String = "", description: String = "", priority: PriorityEisenhower = .importantAndUrgent, type: HabitType = .repeating, repeting: Set<Weekday> = Weekday.allSet, dueDate: Date = Date(), notificationActivated: Bool = false, record: [HabitRecord] = []) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.priority = priority
        self.type = type
        self.repeting = repeting
        self.dueDate = dueDate
        self.notificationActivated = notificationActivated
        self.record = record
    }
}

extension ListHabitItem {
    struct HabitRecord: Identifiable, Codable, Equatable {
        let id = UUID()
        var date: Date
        var count: Int
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
            repeting: .init(Weekday.all),
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
            repeting: Set<Weekday>(),
            dueDate: Date()
        ),
         .init(icon: "cheers",
               iconColor: ListHabitItem.PriorityEisenhower.urgentButNotImportant.color,
               title: "Wash dishes, vacuum floor, laundry, etc",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeting: Set<Weekday>(),
               dueDate: Date()
        ),
         .init(icon: "dna",
               iconColor: ListHabitItem.PriorityEisenhower.importantAndUrgent.color,
               title: "Learn System Design",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeting: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: false
        ),
         .init(icon: "campfire",
               iconColor: ListHabitItem.PriorityEisenhower.importantButNotUrgent.color,
               title: "Swift 6.2",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeting: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: true
        ),
         .init(icon: "campfire",
               iconColor: ListHabitItem.PriorityEisenhower.importantButNotUrgent.color,
               title: "Candle puring",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .repeating,
               repeting: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: false
        ),
         .init(icon: "cyclist",
               iconColor: ListHabitItem.PriorityEisenhower.notUrgentAndNotImportant.color,
               title: "Balance board",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeting: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: false
        ),
         .init(icon: "cyclist",
               iconColor: ListHabitItem.PriorityEisenhower.importantAndUrgent.color,
               title: "Algorithms",
               description: "",
               priority: .importantAndUrgent,
               type: .repeating,
               repeting: Set<Weekday>(),
               dueDate: Date()
        )]
    }
}
