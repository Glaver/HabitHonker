//
//  HabitEventCenter.swift
//  HabitHonker
//

import Combine

final class HabitEventCenter: HabitEventsPublishing {
    private let subject = PassthroughSubject<HabitEvent, Never>()

    var events: AnyPublisher<HabitEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func send(_ event: HabitEvent) {
        subject.send(event)
    }
}
