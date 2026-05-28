//
//  HabitEventsPublishing.swift
//  HabitHonker
//

import Combine

enum HabitEvent {
    case created
    case updated
    case deleted
    case completed
    case priorityChanged
    case restored
}

protocol HabitEventsPublishing: AnyObject {
    var events: AnyPublisher<HabitEvent, Never> { get }
    func send(_ event: HabitEvent)
}
