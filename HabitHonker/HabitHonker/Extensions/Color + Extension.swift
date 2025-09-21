//
//  Color + Extension.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/10/25.
//
import SwiftUI
// MARK: Don't even think about to write me comments here. THis all will be refactored when I will understand how many colors we need and how i need to change them    
extension Color {
    static let goldenGooseYellow = Color(red: 255/255, green: 200/255, blue: 50/255)   // #FFC832
    static let honkerRed         = Color(red: 214/255, green: 40/255,  blue: 40/255)   // #D62828
    static let warmFeatherBeige  = Color(red: 244/255, green: 227/255, blue: 178/255)  // #F4E3B2
    static let charcoalWingGray  = Color(red: 231/255, green: 191/255, blue: 85/255)   // #3B3B3B
    
    static let purplion = Color(red: 21/255, green: 121/255, blue: 126/255)   // #15797E
    static let fourth = Color(red: 39/255, green: 51/255,  blue: 143/255)   // #27338F
    static let orangone = Color(red: 208/255, green: 160/255, blue: 33/255)  // #D0A021
    static let yellowone = Color(red: 208/255,  green: 114/255,  blue: 33/255)   // #D07221
    
    static let pinky = Color(red: 255/255,  green: 153/255,  blue: 220/255) // #ff99dc
    static let navy = Color(red: 13/255,  green: 13/255,  blue: 85/255) // #0d0d55
    static let neon = Color(red: 217/255,  green: 241/255,  blue: 3/255) // #d9f103
    static let lilac = Color(red: 210/255,  green: 199/255,  blue: 255/255) // #D2c7ff
    
    static func opacityForSheme(_ sheme: ColorScheme) -> Double {
        if sheme == .dark {
            return 0.85
        } else {
            return 0.5
        }
    }
}
