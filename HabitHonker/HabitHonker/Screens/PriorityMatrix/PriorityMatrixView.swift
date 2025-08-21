//
//  PriorityMatrixView.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/20/25.
//

import SwiftUI
import UniformTypeIdentifiers


// MARK: - Drag payload (safe for Transferable; avoids Color/complex fields)
struct HabitDragPayload: Identifiable, Hashable, Codable, Transferable {
    let id: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

// MARK: - Priority Matrix

struct PriorityMatrixView: View {
    // Bind your source of truth (VM/State). Moves update this array in-place.
//    @Binding var habits: [HabitModel]
    @State private var habits: [HabitModel] = HabitModel.mock()
    /// Optional hook if you want to persist moves to a repo
    var onMove: ((HabitModel, HabitModel.PriorityEisenhower) -> Void)?

    init(onMove: ((HabitModel, HabitModel.PriorityEisenhower) -> Void)? = nil) {
        self.onMove = onMove
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Text("Change priority")
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                HStack {
                    header(for: .importantAndUrgent, alignRight: false)
                    Spacer()
                    header(for: .urgentButNotImportant, alignRight: true)
                }
                .padding(.horizontal, 8)
            }
            // 2x2 matrix
            GeometryReader { proxy in
                let rowSpacing: CGFloat = 12
                let rowHeight = (proxy.size.height - rowSpacing) / 2  // 2 rows

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)],
                          spacing: rowSpacing) {
                    quadrant(.importantAndUrgent,  rowHeight: rowHeight)
                    quadrant(.urgentButNotImportant, rowHeight: rowHeight)
                    quadrant(.importantButNotUrgent, rowHeight: rowHeight)
                    quadrant(.notUrgentAndNotImportant, rowHeight: rowHeight)
                }
                .frame(width: proxy.size.width, height: proxy.size.height) // fill the reader
                .overlay(dividers)
            }
            
            HStack {
                header(for: .importantButNotUrgent, alignRight: false)
                Spacer(minLength: 12)
                header(for: .notUrgentAndNotImportant, alignRight: true)
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 10)
    }
        
    // MARK: - Quadrant column

    private func quadrant(_ priority: HabitModel.PriorityEisenhower,
                          rowHeight: CGFloat) -> some View {
        let chips = habits.filter { $0.priority == priority }
        let chipAlignment: Alignment = {
            // choose how chips line up horizontally
            switch priority {
            case .importantAndUrgent, .importantButNotUrgent: return .trailing
            case .urgentButNotImportant, .notUrgentAndNotImportant: return .leading
            }
        }()

        return VStack(alignment: .leading, spacing: 10) {
            ForEach(chips) { habit in
                HabitMatrixCapsuleView(habit: habit, tint: priority.color)
                    .draggable(HabitDragPayload(id: habit.id))
                    .frame(maxWidth: .infinity, alignment: chipAlignment)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight, alignment: alignmentForCapsule(priority))
        .background(.gray.opacity(0.01))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .dropDestination(for: HabitDragPayload.self) { payloads, _ in
            withAnimation(.spring) {
                for payload in payloads { moveHabit(withId: payload.id, to: priority) }
            }
            return true
        }
    }




    // MARK: - Headers

    @ViewBuilder
    private func header(for priority: HabitModel.PriorityEisenhower, alignRight: Bool) -> some View {
        let priorityText = priority.text.components(separatedBy: "/ ")
        VStack(alignment: alignRight ? .trailing : .leading, spacing: 2) {
            Text(priorityText[0]).font(.callout.weight(.semibold)).foregroundStyle(priority.color)
            Text(priorityText[1]).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers
    private func alignmentForCapsule(_ priority: HabitModel.PriorityEisenhower) -> Alignment {
        switch priority {
        case .importantAndUrgent:        return .bottomTrailing
        case .importantButNotUrgent:     return .topTrailing
        case .urgentButNotImportant:     return .bottomLeading
        case .notUrgentAndNotImportant:  return .topLeading
        }
    }
    
    private func alignmentForHabitCapsule(_ priority: HabitModel.PriorityEisenhower) -> HorizontalAlignment {
        switch priority {
        case .importantAndUrgent:        return .trailing
        case .importantButNotUrgent:     return .trailing
        case .urgentButNotImportant:     return .leading
        case .notUrgentAndNotImportant:  return .leading
        }
    }

    private var dividers: some View {
        GeometryReader { geo in
            let midX = geo.size.width / 2
            let midY = geo.size.height / 2
            Path { p in
                p.move(to: .init(x: midX, y: 0))
                p.addLine(to: .init(x: midX, y: geo.size.height))
                p.move(to: .init(x: 0, y: midY))
                p.addLine(to: .init(x: geo.size.width, y: midY))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
            .foregroundStyle(.quaternary)
        }
        .allowsHitTesting(false)
    }

    private func moveHabit(withId id: UUID, to newPriority: HabitModel.PriorityEisenhower) {
        guard let idx = habits.firstIndex(where: { $0.id == id }) else { return }
        habits[idx].priority = newPriority
        onMove?(habits[idx], newPriority)
    }
}

// MARK: - Chip (uses your HabitModel + colors)

private struct HabitMatrixCapsuleView: View {
    let habit: HabitModel
    let tint: Color

    var body: some View {
        HStack(spacing: 5) {
            if let icon = habit.icon, !icon.isEmpty {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .opacity(0.9)
            } else {
                Image(systemName: "diamond.fill")
                    .imageScale(.small)
                    .opacity(0.9)
            }
            Text(habit.title)
                .lineLimit(2)
                .font(.caption2.weight(.semibold))
                
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.18))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(tint.opacity(0.35), lineWidth: 1)
        )
        .contentShape(Capsule())
    }
}

// MARK: - Preview / Example usage

struct PriorityMatrixView_Previews: PreviewProvider {
    static var previews: some View {
        PriorityMatrixView()
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
