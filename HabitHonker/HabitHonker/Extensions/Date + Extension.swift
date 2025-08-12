//
//  Date + Extension.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/11/25.
//
import Foundation

extension Date {
    func getTimeFrom() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "h:mm a"
        return dateFormatter.string(from: self)
    }
}
