//
//  BackgroundService.swift
//  HabitHonker
//

import CoreGraphics
import Foundation

struct BackgroundService: BackgroundServiceProtocol {
    func loadBackgroundData() async -> Data? {
        await Task.detached(priority: .utility) {
            BackgroundStorage.load()
        }.value
    }

    func saveBackgroundData(_ data: Data) async {
        await Task.detached(priority: .utility) {
            BackgroundStorage.save(data)
        }.value
    }

    func optimizedBackgroundData(from data: Data, maxDimension: CGFloat = 3000) async -> Data {
        await Task.detached(priority: .userInitiated) {
            ImageOptimizer.downscaleIfNeeded(data: data, maxDimension: maxDimension)
        }.value
    }

    func clearBackground() async {
        await Task.detached(priority: .utility) {
            BackgroundStorage.clear()
        }.value
    }
}
