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
//                        .background(.ultraThinMaterial)
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
