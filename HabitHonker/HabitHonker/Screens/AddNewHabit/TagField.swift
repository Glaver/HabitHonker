//
//  TagField.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/13/25.
//

import SwiftUI

struct TagField: View {
    @Binding var tags: [String]
    @State private var newTag: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            // Existing tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(10)
                            
                            Button(action: {
                                withAnimation {
                                    tags.removeAll { $0 == tag }
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .padding(.vertical, 5)
            }
            
            // Input field for new tags
            HStack {
                TextField("Add tag...", text: $newTag, onCommit: addTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: addTag) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
                .disabled(newTag.isEmpty)
            }
        }
    }
    
    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        withAnimation {
            tags.append(trimmed)
        }
        newTag = ""
    }
}

// Example usage
struct ContentView: View {
    @State private var tags: [String] = ["Swift", "iOS"]
    
    var body: some View {
        TagField(tags: $tags)
            .padding()
    }
}
