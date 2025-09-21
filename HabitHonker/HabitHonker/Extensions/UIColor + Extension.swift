////
////  UIColor + Extension.swift
////  HabitHonker
////
////  Created by Vladyslav on 9/20/25.
////
//
//import SwiftUI
//
//extension UIColor {
//    convenience init(color: Color) {
//        // Try to get CGColor directly
//        if let cgColor = color.cgColor {
//            self.init(cgColor: cgColor)
//            return
//        }
//
//        // Fallback: resolve via UIKit (works on iOS 14+)
//        let uiColor = UIColor(color)
//        self.init(cgColor: uiColor.cgColor)
//    }
//
//    var hexString: String? {
//        guard let components = cgColor.components else { return nil }
//        let r = Int(components[0] * 255)
//        let g = Int(components[1] * 255)
//        let b = Int(components[2] * 255)
//        return String(format: "#%02X%02X%02X", r, g, b)
//    }
//
//    convenience init?(hex: String) {
//        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
//        if hexSanitized.hasPrefix("#") { hexSanitized.removeFirst() }
//
//        var rgb: UInt64 = 0
//        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
//
//        self.init(
//            red: CGFloat((rgb & 0xFF0000) >> 16) / 255,
//            green: CGFloat((rgb & 0x00FF00) >> 8) / 255,
//            blue: CGFloat(rgb & 0x0000FF) / 255,
//            alpha: 1.0
//        )
//    }
//}
//
