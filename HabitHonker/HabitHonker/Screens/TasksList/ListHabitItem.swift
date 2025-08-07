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
                return " Important & Urgent"
            case .importantButNotUrgent:
                return "Important not Urgent"
            case .urgentButNotImportant:
                return "Urgent not Important"
            case .notUrgentAndNotImportant:
                return "Not Urgent and not Important"
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
            icon: "􁔴",
            iconColor: .blue,
            title: "Meditation",
            priority: .importantButNotUrgent,
            type: .repeating
        ),
         .init(icon: "􁐢",
               iconColor: .cyan,
               title: "Wash dishes",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               notificationActivated: Date()
        ),
         .init(icon: "􀥺",
               iconColor: .brown,
               title: "Algorithms",
               priority: .importantAndUrgent,
               type: .repeating
        )]
    }
}
