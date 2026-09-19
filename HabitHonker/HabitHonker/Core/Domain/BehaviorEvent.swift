//
//  BehaviorEvent.swift
//  HabitHonker
//

import Foundation

struct BehaviorEvent: Identifiable, Equatable, Codable, Sendable {
    var id: UUID
    var targetID: BehaviorTargetID
    var occurredAt: Date
    var kind: BehaviorEventKind

    init(
        id: UUID = UUID(),
        targetID: BehaviorTargetID,
        occurredAt: Date,
        kind: BehaviorEventKind
    ) {
        self.id = id
        self.targetID = targetID
        self.occurredAt = occurredAt
        self.kind = kind
    }
}

enum BehaviorEventKind: Equatable, Codable, Sendable {
    case completed(count: Int)
    case archived
    case deleted
}
