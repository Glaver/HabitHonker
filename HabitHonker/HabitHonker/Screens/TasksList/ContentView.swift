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
        VStack (spacing: -10) {
            HStack {
                Text("Thrusday 16, July")
                    .font(.title3)
                
                Spacer()

                Button(action: {
                    print("Button tapped")
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.black)
                        .padding() // space around icon
                        .background(.ultraThinMaterial)
                    
                        .clipShape(Circle()) // makes it perfectly round
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.clear)
            
            List {
                ForEach(items) { item in
//                    Text("1")
                    HabitCell(item: item)
                        
                }
                .listRowBackground(Color.clear)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)   // iOS 15+
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.clear)
                
            }
            .scrollContentBackground(.hidden)
        }
        .background(Image("Wallpaper")
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all))
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
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(item.iconColor?.opacity(0.6) ?? Color.clear)
                    .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 1)
                    .frame(width: 56)
                
                Image(systemName: item.icon)
                    .foregroundColor(.white)
                    .font(.system(size: 20))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                        Spacer()
                        if item.type == .repeating {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.gray)
                                .padding(.trailing, 15)
                        }
                    }
                }
                Text(item.priority.text)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let remindTime = item.notificationActivated {
//                    Spacer()
                    
                    HStack {
                        Text("Remind me at")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                        Spacer()
                        ZStack {
                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                .fill(.white.opacity(0.6))
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 1)
                                .frame(width: 98, height: 31)
                            Text("8:00 AM")
                                .font(.subheadline)
                                .padding(.horizontal, 13)
                        }
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    
                }
            }
            .padding(.leading, 5)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(26)
        .listRowInsets(EdgeInsets(top: 10, leading: 5, bottom: 10, trailing: 5))
        .shadow(color: .black.opacity(0.15), radius: 3, x: 1, y: 1)
        .frame(maxWidth: .infinity) // fill full width
        .listRowInsets(EdgeInsets()) // remove extra padding
        .listRowSeparator(.hidden)   // hide divider

    }
}

