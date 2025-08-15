//
//  HabitNotificationService.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/14/25.
//
import Foundation
import UserNotifications

// MARK: - Protocol
protocol HabitNotificationScheduling {
    func requestAuthorization() async throws
    func reschedule(for habit: ListHabitItem) async throws
    func cancel(for habitID: UUID) async
    func cancelAll() async
}

// MARK: - Implementation
final class HabitNotificationService: NSObject, HabitNotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    // Call once (app launch)
    func requestAuthorization() async throws {
        let ok = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        guard ok else {
            throw NSError(domain: "HabitNotif", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Notifications not allowed"])
        }
        // Optional: set delegate if you want foreground display / tap handling
        // await MainActor.run { self.center.delegate = self }
    }

    func reschedule(for habit: ListHabitItem) async throws {
        // Turned off? remove everything
        guard habit.isNotificationActivated else {
            await cancel(for: habit.id)
            return
        }

        // Always remove existing requests for this habit before (re)adding
        await cancel(for: habit.id)

        switch habit.type {
        case .dueDate:
            try await scheduleOneShot(habit)
        case .repeating:
            try await scheduleRepeatingByWeekdays(habit)
        }
    }

    func cancel(for habitID: UUID) async {
        await center.removePendingNotificationRequests(withIdentifiers: allIDs(for: habitID))
        await center.removeDeliveredNotifications(withIdentifiers: allIDs(for: habitID))
    }

    func cancelAll() async {
        await center.removeAllPendingNotificationRequests()
        await center.removeAllDeliveredNotifications()
    }
}

// MARK: - Private helpers
private extension HabitNotificationService {
    func scheduleOneShot(_ habit: ListHabitItem) async throws {
        // Skip if dueDate already passed (you could clamp instead)
        guard habit.dueDate > Date() else { return }

        let content = makeContent(for: habit)
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                    from: habit.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(
            identifier: id(for: habit.id, weekday: nil),
            content: content,
            trigger: trigger
        )
        try await center.add(req)
    }

    func scheduleRepeatingByWeekdays(_ habit: ListHabitItem) async throws {
        guard !habit.repeating.isEmpty else { return }

        // Extract only time-of-day from dueDate
        let time = Calendar.current.dateComponents([.hour, .minute], from: habit.dueDate)

        for day in habit.repeating {
            var comps = DateComponents()
            comps.weekday = day.rawValue          // 1=Sun ... 7=Sat
            comps.hour = time.hour
            comps.minute = time.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let req = UNNotificationRequest(
                identifier: id(for: habit.id, weekday: day),
                content: makeContent(for: habit, weekday: day),
                trigger: trigger
            )
            try await center.add(req)
        }
    }

    func makeContent(for habit: ListHabitItem, weekday: Weekday? = nil) -> UNMutableNotificationContent {
        let c = UNMutableNotificationContent()
        // Customize to your model
        c.title = "Habit Honks"
        // If you have title/description on the habit, use them:
        // c.title = habit.title
        // c.body = habit.description
        if let w = weekday {
            c.body = "It's \(w.text) time!"
        }
        c.sound = .default
        c.userInfo = ["habitID": habit.id.uuidString]
        return c
    }

    // One-shot: "habit.<id>"
    // Repeating (per weekday): "habit.<id>.wd.<n>"
    func id(for id: UUID, weekday: Weekday?) -> String {
        if let w = weekday { return "habit.\(id.uuidString).wd.\(w.rawValue)" }
        return "habit.\(id.uuidString)"
    }

    func allIDs(for id: UUID) -> [String] {
        // include base + all weekday variants to be safe
        let base = "habit.\(id.uuidString)"
        let weekdays = (1...7).map { "\(base).wd.\($0)" }
        return [base] + weekdays
    }
}
