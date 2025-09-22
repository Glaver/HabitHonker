//
//  ContentView.swift
//  HabitHonker
//
//  Created by Vladyslav on 7/30/25.
//

import SwiftUI
import SwiftData

struct HabitListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var scheme
    
    @State private var path = NavigationPath()
    @State private var isDeleting = false
    @State private var currentDate = Date()
    @State private var timer: Timer?
    
    @EnvironmentObject private var viewModel: HabitListViewModel
    
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 0)],
                    spacing: 16
                ) { // Weekday filter is here for future improvemmts ↓
                    ForEach(viewModel.items.filtered(by: currentDate), id: \.id) { item in
                        HabitCell(item: item, pillColor: viewModel.colors[item.priority.index])
                            .contentShape(Rectangle())
                            .onTapGesture {
                                path.append(Route.detailHabit(item.id))
                            }
                            .padding(.horizontal, 10)
                            .swipeActions {
                                Action(symbolImage: "checkmark", tint: .black, background: .white) { resetPosition in
                                    resetPosition.toggle()
                                    Task {
                                        await viewModel.habitCompleteWith(id: item.id)
                                    }
                                }
                            }
                    }
                    .padding(.horizontal, 10)
                }
            }
            .onAppear {
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
                    }
                }
            }
            // MARK: Navigation
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .detailHabit(let id):
                    let item = viewModel.items.first(where: { $0.id == id }) ?? HabitModel.mock()
                    HabitDetailView.editItemView(from: item,
                                                 priorityColors: viewModel.colors,
                                                 priorityTitles: viewModel.titles,
                                                 saveAction: { habit in
                        Task {
                            await viewModel.saveItem(habit)
                        }
                    },
                                                 deleteAction: { habit in
                        Task {
                            await viewModel.deleteItem(habit)
                        }
                    })
                    
                case .addNewHabit:
                    HabitDetailView.creatNewItemView(priorityColors: viewModel.colors,
                                                     priorityTitles: viewModel.titles,
                                                     saveAction: { habit in
                        Task {
                            await viewModel.saveItem(habit)
                        }
                    },
                                                     deleteAction: { habit in
                        Task {
                            await viewModel.deleteItem(habit)
                        }
                    })
                default: EmptyView()
                        .background(Color.blue)
                }
            }
            .background(Image("Wallpaper")// Refactor later: background on change custom
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    scheme == .dark ? Color.black.opacity(0.4) : Color.clear
                ))
        }
    }
    
    // MARK: - Timer Methods
    private func startDateTimer() {
        // Check every minute if the day has changed
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            let newDate = Date()
            
            // Check if the day has changed using Date extension
            if !currentDate.isSameDay(as: newDate) {
                currentDate = newDate
                // Reload the list to show tasks for the new day
                Task {
                    await viewModel.load()
                }
            }
        }
    }
    
    private func stopDateTimer() {
        timer?.invalidate()
        timer = nil
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
    HabitListView()
    .modelContainer(container)
}
