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
    @Attribute(.unique) var id: UUID
    var icon: String?
    var iconColorHex: String
    var title: String
    var descriptionText: String
    var tags: [String?]
    var priorityRaw: Int
    var typeRaw: Int
    var repeatingWeekdays: [Int]
    var dueDate: Date
    var notificationActivated: Bool
    var deletedAt: Date
    @Relationship(deleteRule: .cascade) var records: [HabitRecordSD]

    init(
        id: UUID,
        icon: String?,
        iconColorHex: String,
        title: String,
        descriptionText: String,
        tags: [String?],
        priorityRaw: Int,
        typeRaw: Int,
        repeatingWeekdays: [Int],
        dueDate: Date,
        notificationActivated: Bool,
        deletedAt: Date = Date(),
        records: [HabitRecordSD]
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
