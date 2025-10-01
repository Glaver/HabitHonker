//
//  PriorityMatrixEditorView.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/19/25.
//

import SwiftUI

// MARK: - Screen

struct PriorityMatrixEditorView: View {
    @EnvironmentObject private var viewModel: HabitListViewModel   
    @Environment(\.dismiss) private var dismiss
    
    private var didLoad: Bool = false
    
    var body: some View {
        ZStack {
            GeometryReader { geo in
                let midX = geo.size.width / 2
                let midY = geo.size.height / 2
                Path { p in
                    // vertical
                    p.move(to: CGPoint(x: midX, y: 0))
                    p.addLine(to: CGPoint(x: midX, y: geo.size.height))
                    // horizontal
                    p.move(to: CGPoint(x: 0, y: midY))
                    p.addLine(to: CGPoint(x: geo.size.width, y: midY))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                .foregroundStyle(.separator.opacity(0.6))
                
                let centers: [CGPoint] = [
                    CGPoint(x: midX / 2, y: midY / 2),                     // top-left
                    CGPoint(x: midX + midX / 2, y: midY / 2),              // top-right
                    CGPoint(x: midX / 2, y: (midY + midY / 2) - 40),              // bottom-left
                    CGPoint(x: midX + midX / 2, y: (midY + midY / 2) - 40)        // bottom-right
                ]
                
                let pillForColorButton: [CGPoint] = [
                    CGPoint(x: (midX / 2), y: (midY / 2) + 65),                     // top-left
                    CGPoint(x: (midX + midX / 2), y: (midY / 2) + 65),              // top-right
                    CGPoint(x: (midX / 2), y: (midY + midY / 2) + 25),              // bottom-left
                    CGPoint(x: (midX + midX / 2), y: (midY + midY / 2) + 25)        // bottom-right
                ]
                
                ForEach(centers.indices, id: \.self) { index in
                    let c = centers[index]
                    
                    ZStack {
                        Circle()
                            .foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .glassEffect()
                        ColorPicker("Pick a color", selection: viewModel.draftColorBinding(index), supportsOpacity: true)
                            .labelsHidden()
                            .scaleEffect(1.3)                // visually larger well
                            .frame(width: 36, height: 36)    // bigger tap target
                            .padding()
                    }
                    .position(c)
                }
                
                ForEach(pillForColorButton.indices, id: \.self) { index in
                    let c = pillForColorButton[index]
                    HabitMatrixCapsuleView.habitExample(with: viewModel.colors[index])
                    .position(c)
                }
            }
            
            
            VStack {
                HStack {
                    VStack (alignment: .leading) {
                        PriorityNameView(position: .topLeft, text: viewModel.draftTitleBinding(.importantAndUrgent))
                    }
                    Spacer()
                    VStack (alignment: .trailing) {
                        PriorityNameView(position: .topRight, text: viewModel.draftTitleBinding(.urgentButNotImportant))
                    }
                }
                Spacer()
                HStack {
                    PriorityNameView(position: .bottomLeft, text: viewModel.draftTitleBinding(.importantButNotUrgent))

                    Spacer()
                    PriorityNameView(position: .bottomRight, text: viewModel.draftTitleBinding(.notUrgentAndNotImportant))
                }
            }
            
            ZStack {
                Circle()
                    .foregroundStyle(.blue)
                    .frame(width: 90, height: 90)
                    .glassEffect()
                    .onTapGesture {
                        viewModel.commitThemeChanges()
                        dismiss()
                    }
                Text("Save")
                    .foregroundColor(.white)
            }
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("Customazie color and title")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.startThemeEditing() }
        .toolbar(.hidden, for: .tabBar)
    }
}



struct PriorityNameView: View {
    enum Position {
        case topLeft, topRight, bottomLeft, bottomRight
        
        var padding: Edge.Set {
            switch self {
            case .topLeft, .bottomLeft:   return .leading
            case .topRight, .bottomRight: return .trailing
            }
        }
        
        var alignment: HorizontalAlignment {
            switch self {
            case .topLeft, .bottomLeft:   return .leading
            case .topRight, .bottomRight: return .trailing
            }
        }
        
        var placeholder: String {
            switch self {
            case .topLeft: return PriorityEisenhower.importantAndUrgent.text
            case .bottomLeft: return PriorityEisenhower.importantButNotUrgent.text
            case .topRight: return PriorityEisenhower.urgentButNotImportant.text
            case .bottomRight: return PriorityEisenhower.notUrgentAndNotImportant.text
            }
        }
    }
    
    let position: Position
    @Binding var text: String
    
    var body: some View {
        VStack (alignment: position.alignment) {
            Text("Priority name✏️")
                .foregroundStyle(.secondary)
                .font(.caption2)
                .padding(.leading, 10)
            TextField(position.placeholder, text: $text)
                .lineLimit(2)
                .frame(height: 40)
                .frame(maxWidth: 180)
                .textFieldStyle(.plain)
                .background(.clear)
                .cornerRadius(8)
                .padding(position.padding, 10)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
