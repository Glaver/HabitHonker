//
//  BackgroundVIew.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/23/25.
//
import SwiftUI

struct BackgroundView: View {
    let imageData: Data?

    var body: some View {
        Group {
            if let data = imageData, let uiImg = UIImage(data: data) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                // fallback background (system color or gradient)
                LinearGradient(colors: [.indigo, .purple],
                               startPoint: .top,
                               endPoint: .bottom)
                    .ignoresSafeArea()
            }
        }
    }
}
