//
//  Loger.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/21/25.
//

// Logging.swift
import os

enum Log {
    static var isEnabled = true
    //Log.isEnabled = false
    static let habitBeastVM = Logger(subsystem: "com.habitHonker.app", category: "HabitListVM")
    static let repoSD = Logger(subsystem: "com.habitHonker.app", category: "RepoSwiftData")
    static let repoUD = Logger(subsystem: "com.habitHonker.app", category: "RepoUserDefaults")
    static let ux = Logger(subsystem: "com.habitHonker.app", category: "UX")
}

// Optional: quick timer helper for durations
@discardableResult
func measure<T>(_ name: StaticString, _ logger: Logger, _ block: () throws -> T) rethrows -> T {
    let t0 = DispatchTime.now()
    defer {
        let ns = DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds
        logger.log("⏱ \(name, privacy: .public) took \(ns) ns (~\(Double(ns)/1_000_000.0, privacy: .public) ms)")
    }
    return try block()
}


@inline(__always)
func elapsedMS(from t0: DispatchTime) -> Double {
    let ns = DispatchTime.now().uptimeNanoseconds - t0.uptimeNanoseconds
    return Double(ns) / 1_000_000.0
}

extension Logger {
    func debug(_ message: String) {
        guard Log.isEnabled else { return }
        self.log(level: .debug, "\(message, privacy: .public)")
    }
    func info(_ message: String) {
        guard Log.isEnabled else { return }
        self.log(level: .info, "\(message, privacy: .public)")
    }
    func error(_ message: String) {
        guard Log.isEnabled else { return }
        self.log(level: .error, "\(message, privacy: .public)")
    }
}
