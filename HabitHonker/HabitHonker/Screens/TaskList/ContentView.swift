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
                    .font(.title)
                
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
                    HabitCell(item: item)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let i = items.firstIndex(where: { $0.id == item.id }) {
                                    let deleted = items.remove(at: i)
                                    items.append(deleted)
                                }
                            } label: {
                                Image(systemName: "checkmark")
//                                    .font(.system(size: 180))
//                                    .frame(width: 180, height: 180)
                            }
//                            .foregroundColor(.blue.opacity(0.8))
//                            .font(.system(size: 60, weight: .bold))
                            .tint(.clear)
                        }
                }
                .onDelete(perform: deleteItems)
                .listRowBackground(Color.clear)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
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
    
    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
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
                RoundedRectangle(cornerRadius: 26, style: .continuous)
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
                    Spacer()
                    
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
