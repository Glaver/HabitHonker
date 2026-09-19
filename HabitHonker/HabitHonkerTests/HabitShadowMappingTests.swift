import SwiftUI
import XCTest
@testable import HabitHonker

final class HabitShadowMappingTests: XCTestCase {
    func testRepeatingHabitMapsToRepeatingBehaviorSchedule() {
        let habit = makeHabit(
            type: .repeating,
            repeating: [.monday, .wednesday, .friday]
        )

        XCTAssertEqual(
            HabitShadowMapper.behaviorSchedule(from: habit),
            .repeating(weekdays: [.monday, .wednesday, .friday])
        )
    }

    func testDueDateHabitMapsToOneTimeBehaviorSchedule() {
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let habit = makeHabit(type: .dueDate, dueDate: dueDate)

        XCTAssertEqual(
            HabitShadowMapper.behaviorSchedule(from: habit),
            .oneTime(dueDate: dueDate)
        )
    }

    func testPriorityEisenhowerMapsAllCasesToBehaviorPriority() {
        XCTAssertEqual(
            HabitShadowMapper.behaviorPriority(from: .importantAndUrgent),
            .importantAndUrgent
        )
        XCTAssertEqual(
            HabitShadowMapper.behaviorPriority(from: .urgentButNotImportant),
            .urgentButNotImportant
        )
        XCTAssertEqual(
            HabitShadowMapper.behaviorPriority(from: .importantButNotUrgent),
            .importantButNotUrgent
        )
        XCTAssertEqual(
            HabitShadowMapper.behaviorPriority(from: .notUrgentAndNotImportant),
            .notUrgentAndNotImportant
        )
    }

    func testNotificationEnabledHabitMapsToReminderConfig() {
        let deliveryTime = Date(timeIntervalSince1970: 1_800_000_001)
        let habit = makeHabit(dueDate: deliveryTime, notificationActivated: true)

        XCTAssertEqual(
            HabitShadowMapper.reminderConfig(from: habit),
            TargetReminderConfig(isEnabled: true, deliveryTime: deliveryTime)
        )
    }

    func testNotificationDisabledHabitMapsToDisabledReminderConfig() {
        let habit = makeHabit(
            dueDate: Date(timeIntervalSince1970: 1_800_000_001),
            notificationActivated: false
        )

        XCTAssertEqual(
            HabitShadowMapper.reminderConfig(from: habit),
            TargetReminderConfig(isEnabled: false, deliveryTime: nil)
        )
    }

    func testHabitRecordMapsToCompletionBehaviorEvent() {
        let targetID = BehaviorTargetID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let recordID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let completedAt = Date(timeIntervalSince1970: 1_800_000_002)
        let record = HabitModel.HabitRecord(id: recordID, date: completedAt, count: 3)

        let event = HabitShadowMapper.completionEvent(from: record, targetID: targetID)

        XCTAssertEqual(event.id, recordID)
        XCTAssertEqual(event.targetID, targetID)
        XCTAssertEqual(event.occurredAt, completedAt)
        XCTAssertEqual(event.kind, .completed(count: 3))
    }

    func testDeletedHabitArchiveRowMapsToArchivedBehaviorEvent() {
        let habitID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let eventID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let deletedAt = Date(timeIntervalSince1970: 1_800_000_003)
        let deletedHabit = DeletedHabitSD(
            id: habitID,
            title: "Archived habit",
            deletedAt: deletedAt
        )

        let event = HabitShadowMapper.archivedEvent(from: deletedHabit, eventID: eventID)

        XCTAssertEqual(event.id, eventID)
        XCTAssertEqual(event.targetID, BehaviorTargetID(habitID))
        XCTAssertEqual(event.occurredAt, deletedAt)
        XCTAssertEqual(event.kind, .archived)
    }

    func testShadowMappingPreservesRealisticHabitFields() {
        let habitID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let reminderTime = Date(timeIntervalSince1970: 1_800_000_004)
        let habit = makeHabit(
            id: habitID,
            icon: "alarm",
            title: "Train for 5K",
            description: "Run before work",
            tags: ["health", "morning"],
            priority: .importantButNotUrgent,
            type: .repeating,
            repeating: [.tuesday, .thursday, .saturday],
            dueDate: reminderTime,
            notificationActivated: true
        )

        let target = HabitShadowMapper.behaviorTarget(from: habit)

        XCTAssertEqual(target.id, BehaviorTargetID(habitID))
        XCTAssertEqual(target.iconName, "alarm")
        XCTAssertEqual(target.title, "Train for 5K")
        XCTAssertEqual(target.description, "Run before work")
        XCTAssertEqual(target.tags, ["health", "morning"])
        XCTAssertEqual(target.priority, .importantButNotUrgent)
        XCTAssertEqual(
            target.schedule,
            .repeating(weekdays: [.tuesday, .thursday, .saturday])
        )
        XCTAssertEqual(
            target.reminderConfig,
            TargetReminderConfig(isEnabled: true, deliveryTime: reminderTime)
        )
    }

    private func makeHabit(
        id: UUID = UUID(),
        icon: String? = "empty_icon",
        title: String = "Read",
        description: String = "",
        tags: [String] = [],
        priority: PriorityEisenhower = .importantAndUrgent,
        type: HabitType = .repeating,
        repeating: Set<Weekday> = Weekday.allSet,
        dueDate: Date = Date(timeIntervalSince1970: 1_800_000_000),
        notificationActivated: Bool = false,
        record: [HabitModel.HabitRecord] = []
    ) -> HabitModel {
        HabitModel(
            id: id,
            icon: icon,
            iconColor: .red,
            title: title,
            description: description,
            tags: tags,
            priority: priority,
            type: type,
            repeating: repeating,
            dueDate: dueDate,
            notificationActivated: notificationActivated,
            record: record
        )
    }
}
