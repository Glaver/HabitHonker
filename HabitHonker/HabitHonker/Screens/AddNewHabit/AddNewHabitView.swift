//
//  AddNewHabit.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/8/25.
//

import SwiftUI
import SwiftData

struct AddNewHabitView: View {
    
    var body: some View {

            List {
                Text("New Habit")
                Text("Description")
            }
    }
}


#Preview {
    AddNewHabitView()
        .modelContainer(for: Item.self, inMemory: true)
}
