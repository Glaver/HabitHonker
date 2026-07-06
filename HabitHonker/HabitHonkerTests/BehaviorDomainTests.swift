import Foundation
import XCTest
@testable import HabitHonker

final class BehaviorDomainTests: XCTestCase {
    func testBehaviorScheduleCanRepresentRepeatingWeekdays() {
        let weekdays: Set<BehaviorWeekday> = [.monday, .wednesday, .friday]
        let schedule = BehaviorSchedule.repeating(weekdays: weekdays)

        XCTAssertEqual(schedule, .repeating(weekdays: weekdays))
    }

    func testBehaviorScheduleCanRepresentOneTimeDueDate() {
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let schedule = BehaviorSchedule.oneTime(dueDate: dueDate)

        XCTAssertEqual(schedule, .oneTime(dueDate: dueDate))
    }

    func testBehaviorPriorityRepresentsCurrentEisenhowerConcepts() {
        XCTAssertEqual(BehaviorPriority.allCases.count, 4)

        XCTAssertTrue(BehaviorPriority.importantAndUrgent.isImportant)
        XCTAssertTrue(BehaviorPriority.importantAndUrgent.isUrgent)

        XCTAssertFalse(BehaviorPriority.urgentButNotImportant.isImportant)
        XCTAssertTrue(BehaviorPriority.urgentButNotImportant.isUrgent)

        XCTAssertTrue(BehaviorPriority.importantButNotUrgent.isImportant)
        XCTAssertFalse(BehaviorPriority.importantButNotUrgent.isUrgent)

        XCTAssertFalse(BehaviorPriority.notUrgentAndNotImportant.isImportant)
        XCTAssertFalse(BehaviorPriority.notUrgentAndNotImportant.isUrgent)
    }

    func testBehaviorEventCanRepresentCompletionAndArchiveDeleteEvents() {
        let targetID = BehaviorTargetID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let occurredAt = Date(timeIntervalSince1970: 1_800_000_001)

        let completion = BehaviorEvent(
            targetID: targetID,
            occurredAt: occurredAt,
            kind: .completed(count: 2)
        )
        let archive = BehaviorEvent(
            targetID: targetID,
            occurredAt: occurredAt,
            kind: .archived
        )
        let deletion = BehaviorEvent(
            targetID: targetID,
            occurredAt: occurredAt,
            kind: .deleted
        )

        XCTAssertEqual(completion.targetID, targetID)
        XCTAssertEqual(completion.kind, .completed(count: 2))
        XCTAssertEqual(archive.kind, .archived)
        XCTAssertEqual(deletion.kind, .deleted)
    }
}
