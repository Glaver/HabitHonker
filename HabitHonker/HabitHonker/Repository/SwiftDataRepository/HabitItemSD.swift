//
//  HabitItemSD.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/12/25.
//
import Foundation
import SwiftData

@Model
final class HabitSD {
    var id: UUID = UUID()
    var icon: String? = nil
    var iconColorHex: String? = nil
    var title: String = ""
    var descriptionText: String = ""
    var tags: [String] = []
    var priorityRaw: Int = 1
    var typeRaw: Int = 1
    var repeatingWeekdays: [Int] = []
    var dueDate: Date = Date()
    var notificationActivated: Bool = false

    @Relationship(deleteRule: .cascade)
        var records: [HabitRecordSD]?
    
    init(
        id: UUID = UUID(),
        icon: String? = nil,
        iconColorHex: String? = nil,
        title: String = "",
        descriptionText: String = "",
        tags: [String] = [],
        priorityRaw: Int = 1,
        typeRaw: Int = 1,
        repeatingWeekdays: [Int] = [],
        dueDate: Date = Date(),
        notificationActivated: Bool = false,
        records: [HabitRecordSD]? = nil
    ) {
        self.id = id
        self.icon = icon
        self.iconColorHex = iconColorHex
        self.title = title
        self.descriptionText = descriptionText
        self.tags = tags
        self.priorityRaw = priorityRaw
        self.typeRaw = typeRaw
        self.repeatingWeekdays = repeatingWeekdays
        self.dueDate = dueDate
        self.notificationActivated = notificationActivated
        self.records = records
    }
}


// MARK: - HabitRecord

@Model
final class HabitRecordSD {
    var id: UUID = UUID()
    var date: Date = Date()
    var count: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \HabitSD.records)
    var habit: HabitSD? = nil

    @Relationship(deleteRule: .nullify, inverse: \DeletedHabitSD.records)
    var deletedHabit: DeletedHabitSD? = nil

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        count: Int = 0,
        habit: HabitSD? = nil,
        deletedHabit: DeletedHabitSD? = nil
    ) {
        self.id = id
        self.date = date
        self.count = count
        self.habit = habit
        self.deletedHabit = deletedHabit
    }
}


