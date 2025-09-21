//
//  HabitListModel.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/4/25.
//
import Foundation
import SwiftUI

struct HabitModel: Identifiable, Equatable {
    var id: UUID
    var icon: String?
    var iconColor: Color
    var title: String
    var description: String
    var tags: [String?] = []
    var priority: PriorityEisenhower
    var type: HabitType
    var repeating: Set<Weekday>
    var dueDate: Date
    var isNotificationActivated: Bool = false
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
    
    init(id: UUID = UUID(), icon: String? = nil, iconColor: Color, title: String = "", description: String = "", tags: [String?] = [], priority: PriorityEisenhower = .importantAndUrgent, type: HabitType = .repeating, repeating: Set<Weekday> = Weekday.allSet, dueDate: Date = Date(), notificationActivated: Bool = false, record: [HabitRecord] = []) {
        self.id = id
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.tags = tags
        self.priority = priority
        self.type = type
        self.repeating = repeating
        self.dueDate = dueDate
        self.isNotificationActivated = notificationActivated
        self.record = record
    }
}

extension HabitModel {
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

enum HabitType: Int, CaseIterable {
    case dueDate
    case repeating
    
    var text: String {
        switch self {
        case .dueDate:
            return Constants.dueDate
        case .repeating:
            return Constants.repeating
        }
    }
}

enum PriorityEisenhower: Int, CaseIterable {
    case importantAndUrgent
    case urgentButNotImportant
    case importantButNotUrgent
    case notUrgentAndNotImportant
    
    var text: String {
        switch self {
        case .importantAndUrgent:
            return Constants.importantAndUrgent
        case .importantButNotUrgent:
            return Constants.importantButNotUrgent
        case .urgentButNotImportant:
            return Constants.urgentButNotImportant
        case .notUrgentAndNotImportant:
            return Constants.notUrgentAndNotImportant
        }
    }
    // TODO: Remove after refact
    var color: Color {
        switch self {
        case .importantAndUrgent:        return .red
        case .urgentButNotImportant:     return .yellow
        case .importantButNotUrgent:     return .green
        case .notUrgentAndNotImportant:  return .blue
        }
    }
}

//extension PriorityEisenhower {
//    var key: String {
//        switch self {
//        case .importantAndUrgent: return "color_importantAndUrgent"
//        case .urgentButNotImportant: return "color_urgentButNotImportant"
//        case .importantButNotUrgent: return "color_importantButNotUrgent"
//        case .notUrgentAndNotImportant: return "color_notUrgentAndNotImportant"
//        }
//    }
//    
//    var color: Color {
//        if let hex = UserDefaults.standard.string(forKey: key),
//           let color = Color(hex: hex) {
//            print("get from User Defaults : \(color)")
//            return color
//        }
//        
//        print("Default values")
//        switch self {
//        case .importantAndUrgent:        return .red
//        case .urgentButNotImportant:     return .yellow
//        case .importantButNotUrgent:     return .blue
//        case .notUrgentAndNotImportant:  return .green
//        }
//    }
//    
//    func save(_ color: Color) {
//        let uiColor = UIColor(color)
//        if let hex = uiColor.hexString {
//            UserDefaults.standard.set(hex, forKey: key)
//            print("New HEX saved: \(hex)")
//        } else {
//            print("⚠️ Failed to make HEX from \(color)")
//        }
//    }
//}



extension HabitModel {
    static func habitExample() -> HabitModel {
        .init(
            icon: "empty_icon",
            iconColor: .clear,
            title: "Habit Example",
            description: "",
            priority: .notUrgentAndNotImportant,
            type: .repeating,
            repeating: .init(Weekday.all),
            dueDate: Date())
    }
    
    static func mock() -> HabitModel {
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

extension HabitModel {
    static func mock() -> [HabitModel] {
        [.init(
            icon: "atom",
            iconColor: .red,
            title: "Meditation",
            description: "",
            priority: .importantButNotUrgent,
            type: .repeating,
            repeating: Set<Weekday>(),
            dueDate: Date()
        ),
         .init(icon: "academic-cap",
               iconColor:.green,
               title: "Wash dishes, vacuum floor, laundry, etc",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeating: Set<Weekday>(),
               dueDate: Date()
        ),
         .init(icon: "atom",
               iconColor: .red,
               title: "Learn System Design",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeating: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: false
        ),
         .init(icon: "alien",
               iconColor: .yellow,
               title: "Swift 6.2",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeating: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: true
        ),
         .init(icon: "baby",
               iconColor: .yellow,
               title: "Candle puring",
               description: "",
               priority: .notUrgentAndNotImportant,
               type: .repeating,
               repeating: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: false
        ),
         .init(icon: "avocado",
               iconColor: .green,
               title: "Balance board",
               description: "",
               tags: [],
               priority: .notUrgentAndNotImportant,
               type: .dueDate,
               repeating: Set<Weekday>(),
               dueDate: Date(),
               notificationActivated: false
        ),
         .init(icon: "alarm",
               iconColor: .red,
               title: "Algorithms",
               description: "",
               tags: [],
               priority: .importantAndUrgent,
               type: .repeating,
               repeating: Set<Weekday>(),
               dueDate: Date()
        )]
    }
}

extension HabitType {
    enum Constants {
        static let dueDate = "Due Date"
        static let repeating = "Repeating"
    }
}


extension PriorityEisenhower {
    enum Constants {
        static let importantAndUrgent = "Important / Urgent"
        static let importantButNotUrgent = "Important / Not Urgent"
        static let urgentButNotImportant = "Not Important / Urgent"
        static let notUrgentAndNotImportant = "Not Important / Not Urgent"
    }
}
