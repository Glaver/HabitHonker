//
//  BackgroundServiceProtocol.swift
//  HabitHonker
//

import CoreGraphics
import Foundation

protocol BackgroundServiceProtocol {
    func loadBackgroundData() async -> Data?
    func saveBackgroundData(_ data: Data) async
    func optimizedBackgroundData(from data: Data, maxDimension: CGFloat) async -> Data
    func clearBackground() async
}
