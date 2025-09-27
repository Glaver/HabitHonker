//
//  BackgroundStorage.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/23/25.
//

import UIKit

enum BackgroundStorage {
    private static var url: URL {
        let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return doc.appendingPathComponent("background.jpg")
    }

    static func save(_ data: Data) {
        try? data.write(to: url, options: .atomic)
    }

    static func load() -> Data? {
        try? Data(contentsOf: url)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}

/// Optional: prevent giant photos from eating memory.
/// Downscales if either side exceeds `maxDimension` (keeps aspect ratio).
enum ImageOptimizer {
    static func downscaleIfNeeded(data: Data, maxDimension: CGFloat) -> Data {
        guard let img = UIImage(data: data) else { return data }
        let w = img.size.width, h = img.size.height
        let maxSide = max(w, h)
        guard maxSide > maxDimension else { return data }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: floor(w * scale), height: floor(h * scale))

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }

        // JPEG at 0.9 keeps quality; switch to pngData() if you need lossless
        return resized.jpegData(compressionQuality: 0.9) ?? data
    }
}

