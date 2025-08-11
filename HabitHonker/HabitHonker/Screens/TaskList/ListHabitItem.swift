//
//  ListHabitItem.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/4/25.
//
import Foundation
import SwiftUI

struct ListHabitItem: Identifiable {
    let id = UUID()
    var icon: String
    var iconColor: Color?
    var title: String
    var description: String
    var priority: PriorityEisenhower
    var type: HabitType
    var dueDate: Date?
    var notificationActivated: Bool?
}

extension ListHabitItem {
    enum PriorityEisenhower: CaseIterable {
        case importantAndUrgent
        case importantButNotUrgent
        case urgentButNotImportant
        case notUrgentAndNotImportant
        
        var text: String {
            switch self {
            case .importantAndUrgent:
                return " Important / Urgent"
            case .importantButNotUrgent:
                return "Important / Not Urgent"
            case .urgentButNotImportant:
                return "Urgent / Not Important"
            case .notUrgentAndNotImportant:
                return "Not Urgent / Not Important"
            }
        }
        
//        var color: Color {
//            switch self {
//            case .importantAndUrgent:
//                return .red
//            case .importantButNotUrgent:
//                return .blue
//            case .urgentButNotImportant:
//                return .yellow
//            case .notUrgentAndNotImportant:
//                return .green
//            }
//        }
        
        var color: Color {
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
    }
    
    enum HabitType: CaseIterable {
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
    static func mock() -> ListHabitItem {
        .init(
            icon: "person.crop.circle",
            iconColor: .blue,
            title: "Meditation",
            description: "",
            priority: .importantButNotUrgent,
            type: .repeating)
    }
}

extension ListHabitItem {
    static func mock() -> [ListHabitItem] {
        [.init(
            icon: "person.crop.circle",
            iconColor: ListHabitItem.PriorityEisenhower.importantButNotUrgent.color,
            title: "Meditation",
            description: "",
            priority: .importantButNotUrgent,
            type: .repeating
        ),
         .init(icon: "archivebox",
               iconColor: ListHabitItem.PriorityEisenhower.notUrgentAndNotImportant.color,
               title: "Wash dishes, vacuum floor, laundry, etc",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate
        ),
         .init(icon: "archivebox",
               iconColor: ListHabitItem.PriorityEisenhower.notUrgentAndNotImportant.color,
               title: "Learn System Design",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               notificationActivated: false
        ),
         .init(icon: "archivebox",
               iconColor: ListHabitItem.PriorityEisenhower.importantButNotUrgent.color,
               title: "Swift 6.2",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               notificationActivated: false
        ),
         .init(icon: "archivebox",
               iconColor: ListHabitItem.PriorityEisenhower.importantButNotUrgent.color,
               title: "Candle puring",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .repeating,
               notificationActivated: false
        ),
         .init(icon: "archivebox",
               iconColor: ListHabitItem.PriorityEisenhower.notUrgentAndNotImportant.color,
               title: "Balance board",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               notificationActivated: false
        ),
         .init(icon: "square.3.layers.3d.top.filled",
               iconColor: ListHabitItem.PriorityEisenhower.importantAndUrgent.color,
               title: "Algorithms",
               description: "",
               priority: .importantAndUrgent,
               type: .repeating
        )]
    }
}
