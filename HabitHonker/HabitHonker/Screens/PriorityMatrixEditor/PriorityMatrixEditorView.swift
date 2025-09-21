//
//  PriorityMatrixEditorView.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/19/25.
//

import SwiftUI

// MARK: - Screen

struct PriorityMatrixEditorView: View {
    //    @State private var selectedColor: Color = .clear // Default color
    @AppStorage(PriorityThemeKeys.colors) private var colorsBlob: Data = defaultColorsBlob
    @AppStorage(PriorityThemeKeys.titles) private var titlesBlob: Data = defaultTitlesBlob
    
    // Local drafts (so you can edit and it writes immediately)
    @State private var colors: [Color] = decodeColors(defaultColorsBlob)
    @State private var titles: [String] = decodeTitles(defaultTitlesBlob)
    
//    let viewModel: PriorityMatrixEditorViewModel
    
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
                        ColorPicker("Pick a color", selection: colorBinding(index), supportsOpacity: true)
                            .labelsHidden()
                            .scaleEffect(1.3)                // visually larger well
                            .frame(width: 36, height: 36)    // bigger tap target
                            .padding()
                    }
                    .position(c)
                }
                
                ForEach(pillForColorButton.indices, id: \.self) { index in
                    let c = pillForColorButton[index]
                    HabitMatrixCapsuleView.habitExample(with: colors[index])
                    .position(c)
                }
            }
            
            VStack {
                HStack {
                    VStack (alignment: .leading) {
                        PriorityNameView(position: .topLeft)
                    }
                    Spacer()
                    VStack (alignment: .trailing) {
                        PriorityNameView(position: .topRight)
                    }
                }
                Spacer()
                HStack {
                    PriorityNameView(position: .bottomLeft)

                    Spacer()
                    PriorityNameView(position: .bottomRight)
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .navigationTitle("Customazie color and title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            colors = decodeColors(colorsBlob)
            titles = decodeTitles(titlesBlob)
        }
    }
}

private extension PriorityMatrixEditorView {
    // MARK: - Bindings
    func colorBinding(_ index: Int) -> Binding<Color> {
        Binding(
            get: { colors[index] },
            set: { new in
                colors[index] = new
                colorsBlob = encodeColors(colors)   // write to AppStorage
            }
        )
    }
    func titleBinding(_ prio: PriorityEisenhower) -> Binding<String> {
        Binding(
            get: { titles[prio.index] },
            set: { new in
                titles[prio.index] = new
                titlesBlob = encodeTitles(titles)   // write to AppStorage
            }
        )
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
    
    var body: some View {
        VStack (alignment: position.alignment) {
            Text("Priority name✏️")
                .foregroundStyle(.secondary)
                .font(.caption2)
                .padding(.leading, 10)
            TextField(position.placeholder, text: .constant(""))
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
