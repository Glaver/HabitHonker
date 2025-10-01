//
//  PrimaryButton.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/19/25.
//

import SwiftUI

struct PrimaryButton: View {
    let title: String
    let color: Color
    let foregroundStyle: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: 54)
                .multilineTextAlignment(.center)
                .foregroundStyle(foregroundStyle)
                .font(.system(size: 17, weight: .bold))
                .background(color.opacity(0.6))
                .clipShape(Capsule())
                .glassEffect(.regular, in: Capsule())
//                .shadow(color: color.opacity(0.7), radius: 5, x: 2, y: 2)
        }
    }
}


extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
