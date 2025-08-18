//
//  HabitMapper.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/12/25.
//
import Foundation
import SwiftUI

enum HabitMapper {
    // MARK: SwiftUI.Color <-> Hex
    static func hex(from color: Color?) -> String? {
        guard let color else { return nil }
        #if canImport(UIKit)
        // Simple best-effort conversion; customize if you have a Color extension
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        func to255(_ x: CGFloat) -> Int { Int(round(x * 255)) }
        return String(format: "#%02X%02X%02X%02X", to255(r), to255(g), to255(b), to255(a))
        #else
        return nil
        #endif
    }

    static func color(from hex: String?) -> Color? {
        guard let hex, let rgba = rgbaFromHex(hex) else { return nil }
        return Color(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }

    private static func rgbaFromHex(_ hex: String) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 8, let v = UInt32(h, radix: 16) else { return nil }
        let r = CGFloat((v & 0xFF00_0000) >> 24) / 255.0
        let g = CGFloat((v & 0x00FF_0000) >> 16) / 255.0
        let b = CGFloat((v & 0x0000_FF00) >> 8)  / 255.0
        let a = CGFloat( v & 0x0000_00FF)       / 255.0
        return (r,g,b,a)
    }

    // MARK: SD -> Domain
    static func toDomain(_ sd: HabitSD) -> ListHabitItem {
        let priority = ListHabitItem.PriorityEisenhower(rawValue: sd.priorityRaw)
            ?? .importantAndUrgent
        let type = ListHabitItem.HabitType(rawValue: sd.typeRaw)
            ?? .dueDate

        let weekdays = Set(sd.repeatingWeekdays.compactMap(Weekday.init(rawValue: )))

        var item = ListHabitItem(
            id: sd.id,
            icon: sd.icon,
            iconColor: color(from: sd.iconColorHex),
            title: sd.title,
            description: sd.descriptionText,
            priority: priority,
            type: type,
            repeating: weekdays,
            dueDate: sd.dueDate,
            notificationActivated: sd.notificationActivated,
            record: sd.records.compactMap { record in
                guard let id = record.id, let date = record.date, let count = record.count else {
                    return nil
                }
                return ListHabitItem.HabitRecord(id: id, date: date, count: count)
            }
        )
        return item
    }

    // MARK: Domain -> SD (create new)
    static func makeSD(from domain: ListHabitItem) -> HabitSD {
        HabitSD(
            id: domain.id,
            icon: domain.icon,
            iconColorHex: hex(from: domain.iconColor),
            title: domain.title,
            descriptionText: domain.description,
            priorityRaw: domain.priority.rawValue,
            typeRaw: domain.type.rawValue,
            repeatingWeekdays: domain.repeating.map(\.rawValue),
            dueDate: domain.dueDate,
            notificationActivated: domain.isNotificationActivated,
            records: domain.record.map { record in
                let habitRecord = HabitRecordSD()
                habitRecord.id = record.id
                habitRecord.date = record.date
                habitRecord.count = record.count
                return habitRecord
            }
        )
    }

    // MARK: Update existing SD with domain values
    static func apply(_ domain: ListHabitItem, to sd: HabitSD) {
        sd.icon = domain.icon
        sd.iconColorHex = hex(from: domain.iconColor)
        sd.title = domain.title
        sd.descriptionText = domain.description
        sd.priorityRaw = domain.priority.rawValue
        sd.typeRaw = domain.type.rawValue
        sd.repeatingWeekdays = domain.repeating.map(\.rawValue)
        sd.dueDate = domain.dueDate
        sd.notificationActivated = domain.isNotificationActivated
        // Replace records (simple strategy; optimize as needed)
        sd.records = domain.record.map { record in
            let habitRecord = HabitRecordSD()
            habitRecord.id = record.id
            habitRecord.date = record.date
            habitRecord.count = record.count
            return habitRecord
        }
    }
    
    // MARK: Domain -> DeletedHabitSD (for archiving deleted habits)
    static func makeDeletedSD(from domain: ListHabitItem) -> DeletedHabitSD {
        DeletedHabitSD(
            id: domain.id,
            icon: domain.icon,
            iconColorHex: hex(from: domain.iconColor),
            title: domain.title,
            descriptionText: domain.description,
            priorityRaw: domain.priority.rawValue,
            typeRaw: domain.type.rawValue,
            repeatingWeekdays: domain.repeating.map(\.rawValue),
            dueDate: domain.dueDate,
            notificationActivated: domain.isNotificationActivated,
            deletedAt: Date(),
            records: domain.record.map { record in
                let habitRecord = HabitRecordSD()
                habitRecord.id = record.id
                habitRecord.date = record.date
                habitRecord.count = record.count
                return habitRecord
            }
        )
    }
    
    // MARK: DeletedHabitSD -> Domain
    static func deletedToDomain(_ sd: DeletedHabitSD) -> ListHabitItem {
        let priority = ListHabitItem.PriorityEisenhower(rawValue: sd.priorityRaw)
            ?? .importantAndUrgent
        let type = ListHabitItem.HabitType(rawValue: sd.typeRaw)
            ?? .dueDate

        let weekdays = Set(sd.repeatingWeekdays.compactMap(Weekday.init(rawValue: )))

        var item = ListHabitItem(
            id: sd.id,
            icon: sd.icon,
            iconColor: color(from: sd.iconColorHex),
            title: sd.title,
            description: sd.descriptionText,
            priority: priority,
            type: type,
            repeating: weekdays,
            dueDate: sd.dueDate,
            notificationActivated: sd.notificationActivated,
            record: sd.records.compactMap { record in
                guard let id = record.id, let date = record.date, let count = record.count else {
                    return nil
                }
                return ListHabitItem.HabitRecord(id: id, date: date, count: count)
            }
        )
        return item
    }
}
