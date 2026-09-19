//
//  BehaviorPriority.swift
//  HabitHonker
//

enum BehaviorPriority: Int, CaseIterable, Codable, Equatable, Sendable {
    case importantAndUrgent
    case urgentButNotImportant
    case importantButNotUrgent
    case notUrgentAndNotImportant

    var isImportant: Bool {
        switch self {
        case .importantAndUrgent, .importantButNotUrgent:
            return true
        case .urgentButNotImportant, .notUrgentAndNotImportant:
            return false
        }
    }

    var isUrgent: Bool {
        switch self {
        case .importantAndUrgent, .urgentButNotImportant:
            return true
        case .importantButNotUrgent, .notUrgentAndNotImportant:
            return false
        }
    }
}
