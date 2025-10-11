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
        let A = max(1, to255(a)) // avoid 0 -> invisible
        return String(format: "#%02X%02X%02X%02X", to255(r), to255(g), to255(b), A)
#else
        return nil
#endif
    }
    
    static func color(from hex: String?) -> Color? {
        guard let hex else { return nil }
        // Try RGBA
        if let rgba = rgbaFromHex(hex) {
            let a = (rgba.a == 0) ? 1 : rgba.a
            return Color(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: a)
        }
        // Fallback ARGB (#AARRGGBB)
        if let argb = argbFromHex(hex) {
            let a = (argb.a == 0) ? 1 : argb.a
            return Color(.sRGB, red: argb.r, green: argb.g, blue: argb.b, opacity: a)
        }
        return nil
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
    
    private static func argbFromHex(_ hex: String) -> (a: CGFloat, r: CGFloat, g: CGFloat, b: CGFloat)? {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 8, let v = UInt32(h, radix: 16) else { return nil }
        let a = CGFloat((v & 0xFF00_0000) >> 24) / 255.0
        let r = CGFloat((v & 0x00FF_0000) >> 16) / 255.0
        let g = CGFloat((v & 0x0000_FF00) >> 8)  / 255.0
        let b = CGFloat( v & 0x0000_00FF)       / 255.0
        return (a,r,g,b)
    }
    // MARK: SD -> Domain
    static func toDomain(_ sd: HabitSD) -> HabitModel {
        let priority = PriorityEisenhower(rawValue: sd.priorityRaw) ?? .importantAndUrgent
        let type     = HabitType(rawValue: sd.typeRaw) ?? .repeating
        let weekdays = Set(sd.repeatingWeekdays.compactMap(Weekday.init(rawValue:)))
        
        let domainRecords: [HabitModel.HabitRecord] = (sd.records ?? []).map {
            HabitModel.HabitRecord(id: $0.id, date: $0.date, count: $0.count)
        }
        
        return HabitModel(
            id: sd.id,
            icon: sd.icon,
            iconColor: color(from: sd.iconColorHex) ?? .orange,
            title: sd.title,
            description: sd.descriptionText,
            tags: sd.tags,
            priority: priority,
            type: type,
            repeating: weekdays,
            dueDate: sd.dueDate,
            notificationActivated: sd.notificationActivated,
            record: domainRecords
        )
    }
    
    // MARK: Domain -> SD (create new)
    static func makeSD(from domain: HabitModel) -> HabitSD {
        let sdRecords: [HabitRecordSD] = domain.record.map { r in
            let rec = HabitRecordSD()
            rec.id = r.id
            rec.date = r.date
            rec.count = r.count
            return rec
        }
        
        let sd = HabitSD(
            id: domain.id,
            icon: domain.icon,
            iconColorHex: hex(from: domain.iconColor),
            title: domain.title,
            descriptionText: domain.description,
            tags: domain.tags,
            priorityRaw: domain.priority.rawValue,
            typeRaw: domain.type.rawValue,
            repeatingWeekdays: domain.repeating.map(\.rawValue),
            dueDate: domain.dueDate,
            notificationActivated: domain.isNotificationActivated,
            records: sdRecords
        )
        
        sd.records?.forEach { $0.habit = sd }
        return sd
    }
    
    // MARK: Update existing SD with domain values
    static func apply(_ domain: HabitModel, to sd: HabitSD) {
        sd.icon = domain.icon
        sd.iconColorHex = hex(from: domain.iconColor)
        sd.title = domain.title
        sd.descriptionText = domain.description
        sd.tags = domain.tags
        sd.priorityRaw = domain.priority.rawValue
        sd.typeRaw = domain.type.rawValue
        sd.repeatingWeekdays = domain.repeating.map(\.rawValue)
        sd.dueDate = domain.dueDate
        sd.notificationActivated = domain.isNotificationActivated
        
        let newRecords: [HabitRecordSD] = domain.record.map { r in
            let rec = HabitRecordSD()
            rec.id = r.id
            rec.date = r.date
            rec.count = r.count
            return rec
        }
        sd.records = newRecords
        sd.records?.forEach { $0.habit = sd }
    }
    
    // MARK: Domain -> DeletedHabitSD (archive)
    static func makeDeletedSD(from domain: HabitModel) -> DeletedHabitSD {
        let deleted = DeletedHabitSD(
                id: domain.id,
                icon: domain.icon,
                iconColorHex: hex(from: domain.iconColor) ?? "#000000FF",
                title: domain.title,
                descriptionText: domain.description,
                tags: domain.tags,
                priorityRaw: domain.priority.rawValue,
                typeRaw: domain.type.rawValue,
                repeatingWeekdays: domain.repeating.map(\.rawValue),
                dueDate: domain.dueDate,
                notificationActivated: domain.isNotificationActivated,
                deletedAt: Date()
            )

            let recs: [HabitRecordSD] = domain.record.map { r in
                let sd = HabitRecordSD()
                sd.id   = r.id
                sd.date = r.date
                sd.count = r.count
                sd.deletedHabit = deleted
                return sd
            }

            deleted.records = recs
            return deleted
    }
    
    // MARK: DeletedHabitSD -> Domain
    static func deletedToDomain(_ sd: DeletedHabitSD) -> HabitModel {
        let priority = PriorityEisenhower(rawValue: sd.priorityRaw) ?? .importantAndUrgent
        let type     = HabitType(rawValue: sd.typeRaw) ?? .dueDate
        let weekdays = Set(sd.repeatingWeekdays.compactMap(Weekday.init(rawValue:)))
        
        let domainRecords: [HabitModel.HabitRecord] = (sd.records ?? []).map {
            HabitModel.HabitRecord(id: $0.id, date: $0.date, count: $0.count)
        }
        
        return HabitModel(
            id: sd.id,
            icon: sd.icon,
            iconColor: color(from: sd.iconColorHex) ?? .orange,
            title: sd.title,
            description: sd.descriptionText,
            tags: sd.tags,
            priority: priority,
            type: type,
            repeating: weekdays,
            dueDate: sd.dueDate,
            notificationActivated: sd.notificationActivated,
            record: domainRecords
        )
    }
}
