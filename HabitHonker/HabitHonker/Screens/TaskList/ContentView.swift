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
    @State private var path = NavigationPath()
    
    let makeViewModel: () -> HabitListViewModel
    @StateObject private var viewModel: HabitListViewModel
    
    init(makeViewModel: @escaping () -> HabitListViewModel) {
        _viewModel = StateObject(wrappedValue: makeViewModel())
        self.makeViewModel = makeViewModel
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            VStack (spacing: -10) {
                List {
                    ForEach(viewModel.items) { item in
                        HabitCell(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                path.append(Route.detailHabit(item.id))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .confirm) {
                                    Task {
                                        // Mark as completed
//                                        var updatedItem = item
//                                        updatedItem.completeHabitNow()
//                                        viewModel.setEditingItem(updatedItem)
//                                        await viewModel.saveCurrent()
                                    }
                                } label: {
                                    ZStack{
                                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                                            .glassEffect()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task {
//                                        await viewModel.deleteItem(withId: item.id)
                                    }
                                } label: {
                                    ZStack{
                                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                                            .glassEffect()
                                        Image(systemName: "trash")
                                    }
                                }
                                .tint(.red)
                            }
                    }
                    .onDelete(perform: deleteItems)
                    .onMove(perform: move)
                    .listRowBackground(Color.clear)
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.clear)
                }
                .onAppear { viewModel.onAppear() }
                .scrollContentBackground(.hidden)
                
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Thursday 16, July")
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
                case .detailHabit(let id):
                    if let found = viewModel.items.first(where: { $0.id == id }) {
                        AddNewHabitView(item: found,
                                        saveAction: { item in
                            Task {
                                viewModel.setEditingItem(item)
                                await viewModel.saveCurrent()
                            }
                        },
                                        saveButton: {
                            SaveButton() {
                                print("should be saved here")
                            }
                        })
                    } else {
                        AddNewHabitView(item: ListHabitItem.mock(),
                                        saveAction: { item in
                            Task {
                                viewModel.setEditingItem(item)
                                await viewModel.saveCurrent()
                            }
                        },
                                        saveButton: {
                            SaveButton() {
                            }
                        })
                    }
                case .addNewHabit:
                    AddNewHabitView(item: ListHabitItem.mock(),
                                    saveAction: { item in
                        Task {
                            viewModel.setEditingItem(item)
                            await viewModel.saveCurrent()
                        }
                    },
                                    saveButton: {
                        SaveButton() {
                            print("hoy hoy")
                        }
                    })
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
        Task {
            await viewModel.delete(at: offsets)
        }
    }
    
    private func move(from source: IndexSet, to destination: Int) {
        // Note: This would need to be implemented in the repository if you want to persist order
        // For now, just update the local array
        var items = viewModel.items
        items.move(fromOffsets: source, toOffset: destination)
    }
}

#Preview {
    // 1) Make an in-memory SwiftData container for previews
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: HabitSD.self, HabitRecordSD.self,
            configurations: config
        )

        // 2) Build a repo for the VM factory
        let repo = HabitsRepositorySwiftData(container: container)

        // 3) Pass the factory closure + attach the container to the view tree
    ContentView(makeViewModel: {
            HabitListViewModel(repo: repo)
        })
        .modelContainer(container)
}
