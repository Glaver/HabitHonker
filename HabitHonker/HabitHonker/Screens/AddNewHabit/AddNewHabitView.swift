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
                Text("Add New Habit")
                Text("Add New Habit")
            }
        }
    }
}


#Preview {
    AddNewHabitView()
        .modelContainer(for: Item.self, inMemory: true)
}
