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
    @Attribute(.unique) var id: UUID
    var icon: String?
    var iconColorHex: String?       // hex like "#FFA500FF"
    var title: String
    var descriptionText: String     // avoid name "description" to sidestep clashes
    var priorityRaw: Int
    var typeRaw: Int
    var repeatingWeekdays: [Int]    // e.g. [1,3,5]
    var dueDate: Date
    var notificationActivated: Bool
    @Relationship(deleteRule: .cascade) var records: [HabitRecordSD]

    init(
        id: UUID,
        icon: String?,
        iconColorHex: String?,
        title: String,
        descriptionText: String,
        priorityRaw: Int,
        typeRaw: Int,
        repeatingWeekdays: [Int],
        dueDate: Date,
        notificationActivated: Bool,
        records: [HabitRecordSD]
    ) {
        self.id = id
        self.icon = icon
        self.iconColorHex = iconColorHex
        self.title = title
        self.descriptionText = descriptionText
        self.priorityRaw = priorityRaw
        self.typeRaw = typeRaw
        self.repeatingWeekdays = repeatingWeekdays
        self.dueDate = dueDate
        self.notificationActivated = notificationActivated
        self.records = records
    }
}

@Model
final class HabitRecordSD {
    @Attribute(.unique) var id: UUID
    var date: Date
    var count: Int

    init(id: UUID, date: Date, count: Int) {
        self.id = id
        self.date = date
        self.count = count
    }
}
