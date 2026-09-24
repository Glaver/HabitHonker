import Foundation
import SwiftData

/// Historical occurrence state, independent of an active HabitSD row. Unknown metadata
/// stays nil; no reward amounts live here. Raw task/eligibility values reuse Phase 1
/// enum raw values; priority uses BehaviorPriority. schemaVersion versions this payload.
@Model
final class TaskOccurrenceSD {
    var id: UUID = UUID()
    var logicalOccurrenceID: String = ""
    var targetID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    var scheduledLocalDateKey: String? = nil
    var scheduledAt: Date? = nil
    var dueAt: Date? = nil
    var schedulingTimeZoneIdentifier: String? = nil
    var schedulingCalendarIdentifier: String? = nil
    var taskTypeRawValue: String = ""
    var statusRawValue: String = ""
    var completedAt: Date? = nil
    var completionCount: Int = 0
    var scheduleRevisionID: String? = nil
    var priorityRawValue: Int? = nil
    var iconName: String? = nil
    var notificationEnabled: Bool? = nil
    var streakBefore: Int? = nil
    var streakAfter: Int? = nil
    var rewardEligibilityRawValue: String? = nil
    var legacyRecordID: UUID? = nil
    var provenanceRawValue: String = ""
    var predecessorOrAliasOccurrenceID: String? = nil
    var schemaVersion: Int = 1

    init(
        id: UUID = UUID(),
        logicalOccurrenceID: String,
        targetID: UUID,
        scheduledLocalDateKey: String? = nil,
        scheduledAt: Date? = nil,
        dueAt: Date? = nil,
        schedulingTimeZoneIdentifier: String? = nil,
        schedulingCalendarIdentifier: String? = nil,
        taskTypeRawValue: String,
        statusRawValue: String,
        completedAt: Date? = nil,
        completionCount: Int = 0,
        scheduleRevisionID: String? = nil,
        priorityRawValue: Int? = nil,
        iconName: String? = nil,
        notificationEnabled: Bool? = nil,
        streakBefore: Int? = nil,
        streakAfter: Int? = nil,
        rewardEligibilityRawValue: String? = nil,
        legacyRecordID: UUID? = nil,
        provenanceRawValue: String,
        predecessorOrAliasOccurrenceID: String? = nil,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.logicalOccurrenceID = logicalOccurrenceID
        self.targetID = targetID
        self.scheduledLocalDateKey = scheduledLocalDateKey
        self.scheduledAt = scheduledAt
        self.dueAt = dueAt
        self.schedulingTimeZoneIdentifier = schedulingTimeZoneIdentifier
        self.schedulingCalendarIdentifier = schedulingCalendarIdentifier
        self.taskTypeRawValue = taskTypeRawValue
        self.statusRawValue = statusRawValue
        self.completedAt = completedAt
        self.completionCount = completionCount
        self.scheduleRevisionID = scheduleRevisionID
        self.priorityRawValue = priorityRawValue
        self.iconName = iconName
        self.notificationEnabled = notificationEnabled
        self.streakBefore = streakBefore
        self.streakAfter = streakAfter
        self.rewardEligibilityRawValue = rewardEligibilityRawValue
        self.legacyRecordID = legacyRecordID
        self.provenanceRawValue = provenanceRawValue
        self.predecessorOrAliasOccurrenceID = predecessorOrAliasOccurrenceID
        self.schemaVersion = schemaVersion
    }
}

/// Frozen schedule metadata; no live edits write revisions in Phase 2.
/// Weekday bit 0 = Sunday (raw 1), ... bit 6 = Saturday (raw 7).
/// The mask is locale-independent; hour/minute use the stored calendar/timezone.
/// One-time schedules use dueAt. Nil metadata represents unknown historical facts.
@Model
final class BehaviorScheduleRevisionSD {
    var id: UUID = UUID()
    var logicalRevisionID: String = ""
    var targetID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    var effectiveFrom: Date = Date(timeIntervalSince1970: 0)
    var effectiveTo: Date? = nil
    var taskTypeRawValue: String = ""
    var selectedWeekdaysMask: Int = 0
    var scheduledHour: Int? = nil
    var scheduledMinute: Int? = nil
    var dueAt: Date? = nil
    var schedulingTimeZoneIdentifier: String? = nil
    var schedulingCalendarIdentifier: String? = nil
    var priorityRawValue: Int? = nil
    var iconName: String? = nil
    var notificationEnabled: Bool? = nil
    var schemaVersion: Int = 1

    init(
        id: UUID = UUID(),
        logicalRevisionID: String,
        targetID: UUID,
        effectiveFrom: Date,
        effectiveTo: Date? = nil,
        taskTypeRawValue: String,
        selectedWeekdaysMask: Int = 0,
        scheduledHour: Int? = nil,
        scheduledMinute: Int? = nil,
        dueAt: Date? = nil,
        schedulingTimeZoneIdentifier: String? = nil,
        schedulingCalendarIdentifier: String? = nil,
        priorityRawValue: Int? = nil,
        iconName: String? = nil,
        notificationEnabled: Bool? = nil,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.logicalRevisionID = logicalRevisionID
        self.targetID = targetID
        self.effectiveFrom = effectiveFrom
        self.effectiveTo = effectiveTo
        self.taskTypeRawValue = taskTypeRawValue
        self.selectedWeekdaysMask = selectedWeekdaysMask
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.dueAt = dueAt
        self.schedulingTimeZoneIdentifier = schedulingTimeZoneIdentifier
        self.schedulingCalendarIdentifier = schedulingCalendarIdentifier
        self.priorityRawValue = priorityRawValue
        self.iconName = iconName
        self.notificationEnabled = notificationEnabled
        self.schemaVersion = schemaVersion
    }
}

/// Durable normalized transition/receipt, unrelated to transient UI invalidations.
/// V1 kindRawValue uses "completed", "archived", "deleted", matching BehaviorEventKind;
/// completionCount preserves the associated count of .completed(count:).
/// Source/provenance are caller-supplied versioned evidence, never inferred here.
@Model
final class BehaviorEventSD {
    var id: UUID = UUID()
    var transitionID: String = ""
    var commandID: String? = nil
    var targetID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    var occurrenceID: String? = nil
    var timestamp: Date = Date(timeIntervalSince1970: 0)
    var kindRawValue: String = ""
    var completionCount: Int? = nil
    var predecessorTransitionID: String? = nil
    var sourceRawValue: String = ""
    var provenanceRawValue: String? = nil
    var schemaVersion: Int = 1

    init(
        id: UUID = UUID(),
        transitionID: String,
        commandID: String? = nil,
        targetID: UUID,
        occurrenceID: String? = nil,
        timestamp: Date,
        kindRawValue: String,
        completionCount: Int? = nil,
        predecessorTransitionID: String? = nil,
        sourceRawValue: String,
        provenanceRawValue: String? = nil,
        schemaVersion: Int = 1
    ) {
        self.id = id
        self.transitionID = transitionID
        self.commandID = commandID
        self.targetID = targetID
        self.occurrenceID = occurrenceID
        self.timestamp = timestamp
        self.kindRawValue = kindRawValue
        self.completionCount = completionCount
        self.predecessorTransitionID = predecessorTransitionID
        self.sourceRawValue = sourceRawValue
        self.provenanceRawValue = provenanceRawValue
        self.schemaVersion = schemaVersion
    }
}
