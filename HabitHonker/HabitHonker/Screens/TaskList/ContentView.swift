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
    
    private var currentDayTitle: String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: currentDate)
        let day = calendar.component(.day, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        
        let weekdaySymbol = DateFormatter().weekdaySymbols[weekday - 1]
        let monthSymbol = DateFormatter().monthSymbols[month - 1]
        
        return "\(weekdaySymbol) \(day), \(monthSymbol)"
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
                                        var updatedItem = item
                                        updatedItem.completeHabitNow()
                                        viewModel.setEditingItem(updatedItem)
                                        await viewModel.saveCurrent()
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
                                        isDeleting = true
                                        await viewModel.deleteItem(withId: item.id)
                                        isDeleting = false
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
                    .listRowBackground(Color.clear)
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.clear)
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
                .scrollContentBackground(.hidden)
                .disabled(isDeleting) // Disable interactions during deletion
                
            }
            .listStyle(.insetGrouped)
            .navigationTitle(currentDayTitle)
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
    
    // MARK: - Timer Methods
    private func startDateTimer() {
        // Check every minute if the day has changed
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            let newDate = Date()
            let calendar = Calendar.current
            
            // Check if the day has changed
            if !calendar.isDate(currentDate, inSameDayAs: newDate) {
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
    
    // Note: deleteItems and move functions are no longer needed since we're using swipe actions
    // for deletion and the list is automatically sorted by completion status
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
