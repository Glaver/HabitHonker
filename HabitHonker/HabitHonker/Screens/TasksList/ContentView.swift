//
//  ContentView.swift
//  HabitHonker
//
//  Created by Vladyslav on 7/30/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var items: [ListHabitItem] = ListHabitItem.mock()

    var body: some View {
        List {
            ForEach(items) { item in
                HabitCell(item: item)
            }
        }
    }

//    private func addItem() {
//        withAnimation {
//            let newItem = Item(timestamp: Date())
//            modelContext.insert(newItem)
//        }
//    }
//
//    private func deleteItems(offsets: IndexSet) {
//        withAnimation {
//            for index in offsets {
//                modelContext.delete(items[index])
//            }
//        }
//    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

struct HabitCell: View {
    let item: ListHabitItem
    
    var body: some View {
        HStack {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(item.iconColor ?? Color.clear)
                //.fill(LinearGradient(gradient: Gradient(colors: [item.iconColor]),
                      //                   startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                
                Image(systemName: item.icon)
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.headline)
                Text(item.priority.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 5)
            
            Spacer()
            
            //if let remindTime = "item.notificationActivated" {
                Text("remindTime")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            //}
            if item.type == .repeating {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.gray)
                    .padding(.leading, 5)
            }
            
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}
