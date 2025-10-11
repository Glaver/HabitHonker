//
//  DeletedHabitSD.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/14/25.
//
import Foundation
import SwiftData

@Model
final class DeletedHabitSD {
    var id: UUID = UUID()
    var icon: String? = nil
    var iconColorHex: String = ""
    var title: String = ""
    var descriptionText: String = ""
    var tags: [String] = []
    var priorityRaw: Int = 0
    var typeRaw: Int = 1
    var repeatingWeekdays: [Int] = []
    var dueDate: Date = Date()
    var notificationActivated: Bool = false
    var deletedAt: Date = Date()

    @Relationship(deleteRule: .nullify)
    var records: [HabitRecordSD]?

    init(
        id: UUID = UUID(),
        icon: String? = nil,
        iconColorHex: String = "",
        title: String = "",
        descriptionText: String = "",
        tags: [String] = [],
        priorityRaw: Int = 0,
        typeRaw: Int = 1,
        repeatingWeekdays: [Int] = [],
        dueDate: Date = Date(),
        notificationActivated: Bool = false,
        deletedAt: Date = Date(),
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
        self.deletedAt = deletedAt
        self.records = records
    }
}
