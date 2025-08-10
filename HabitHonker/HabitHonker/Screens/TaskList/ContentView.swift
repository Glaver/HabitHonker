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
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            VStack (spacing: -10) {
                List {
                    ForEach(items) { item in
//                        NavigationLink(value: Route.detailHabit) {
                            HabitCell(item: item)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if let i = items.firstIndex(where: { $0.id == item.id }) {
                                            let deleted = items.remove(at: i)
                                            items.append(deleted)
                                        }
                                    } label: {
                                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                                        Image(systemName: "checkmark")
                                    }
                                    .tint(.clear)
                                }
//                        }
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
            .listStyle(.insetGrouped)
            .navigationTitle("Thrusday 16, July")
            .navigationBarTitleDisplayMode(.large)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        path.append(Route.addNewHabit)
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(.black)
                            .padding()
                            .glassEffect()
                    }
                }
            }
            
            // Map each Route to a destination view
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detailHabit:
                    AddNewHabitView()
                case .addNewHabit:
                    AddNewHabitView()
                }
            }
            // Refactor: background on change custom
            .background(Image("Wallpaper")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all))
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
