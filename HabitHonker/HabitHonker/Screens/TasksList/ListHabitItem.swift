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
    var priority: PriorityEisenhower
    var type: HabitType
    var notificationActivated: Date?
}

extension ListHabitItem {
    enum PriorityEisenhower {
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
    }
    
    enum HabitType {
        case dueDate
        case repeating
    }
}

extension ListHabitItem {
    static func mock() -> [ListHabitItem] {
        [.init(
            icon: "person.crop.circle",
            iconColor: .blue,
            title: "Meditation",
            priority: .importantButNotUrgent,
            type: .repeating
        ),
         .init(icon: "archivebox",
               iconColor: .cyan,
               title: "Wash dishes, vacuum floor, laundry, etc",
               priority: .notUrgentAndNotImportant,
               type: .dueDate
        ),
         .init(icon: "archivebox",
               iconColor: .gray,
               title: "Learn System Design",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               notificationActivated: Date()
        ),
         .init(icon: "archivebox",
               iconColor: .cyan,
               title: "Swift 6.2",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               notificationActivated: Date()
        ),
         .init(icon: "archivebox",
               iconColor: .green,
               title: "Candle puring",
               priority: .notUrgentAndNotImportant,
               type: .repeating,
               notificationActivated: Date()
        ),
         .init(icon: "archivebox",
               iconColor: .yellow,
               title: "Balance board",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               notificationActivated: Date()
        ),
         .init(icon: "square.3.layers.3d.top.filled",
               iconColor: .brown,
               title: "Algorithms",
               priority: .importantAndUrgent,
               type: .repeating
        )]
    }
}
