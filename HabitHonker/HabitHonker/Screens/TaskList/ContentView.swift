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
    @State private var isDeleting = false
    @State private var currentDate = Date()
    
    let makeViewModel: () -> HabitListViewModel
    @StateObject private var viewModel: HabitListViewModel
    
    init(makeViewModel: @escaping () -> HabitListViewModel) {
        _viewModel = StateObject(wrappedValue: makeViewModel())
        self.makeViewModel = makeViewModel
    }
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 0)],
                    spacing: 16
                ) {
                    ForEach(viewModel.items) { item in
                        HabitCell(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                path.append(Route.detailHabit(item.id))
                            }
                            .padding(.horizontal, 10)
                            .swipeActions {
                                Action(symbolImage: "square.and.arrow.up.fill", tint: .white, background: .blue) { resetPosition in
                                    resetPosition.toggle()
                                }
                                Action(symbolImage: "square.and.arrow.down.fill", tint: .white, background: .purple) { resetPosition in
                                    resetPosition.toggle()
                                }
                                Action(symbolImage: "trash.fill", tint: .white, background: .red) { resetPosition in
                                    resetPosition.toggle()
                                }
                            }
                    }
                    .padding(.horizontal, 10)
                }
            }
            .onAppear {
                Task {
                    await viewModel.load(forDate: currentDate)
                }
                startDateTimer()
            }
            .onDisappear {
                stopDateTimer()
            }
            .disabled(isDeleting)
            .scrollContentBackground(.hidden)
            .navigationTitle(currentDate.currentDayTitle)
            .navigationBarTitleDisplayMode(.large)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        path.append(Route.addNewHabit)
                    } label: {
                        Image(systemName: "plus")
                            .padding()
                            .glassEffect()
                    }
                }
            }
            // MARK: Navigation
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detailHabit(let id):
                    if let found = viewModel.items.first(where: { $0.id == id }) {
                        AddNewHabitView(item: found,
                                        saveAction: { item in
                            Task {
                                viewModel.setEditingItem(item)
                                await viewModel.saveCurrent()
                                viewModel.updateHabitNotification()
                            }
                        },
                                        saveButton: {
                            SaveButton() {
                            }
                        })
                    } else {
                        AddNewHabitView(item: ListHabitItem.mock(),
                                        saveAction: { item in
                            Task {
                                viewModel.setEditingItem(item)
                                await viewModel.saveCurrent()
                                viewModel.updateHabitNotification()
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
                            viewModel.updateHabitNotification()
                        }
                    },
                                    saveButton: {
                        SaveButton() {
                        }
                    })
                }
            }
            .background(Image("Wallpaper")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all))
        }
        // Refactor later: background on change custom
        
    }
    
    
    // MARK: - Timer Methods
    private func startDateTimer() {
        // Check every minute if the day has changed
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            let newDate = Date()
            
            // Check if the day has changed using Date extension
            if !currentDate.isSameDay(as: newDate) {
                currentDate = newDate
                // Reload the list to show tasks for the new day
                Task {
                    await viewModel.load(forDate: currentDate)
                }
            }
        }
    }
    
    private func stopDateTimer() {
        // Timer cleanup if needed
    }
}

// MARK: Preview

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
