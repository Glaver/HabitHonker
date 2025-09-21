//
//  PriorityMatrixView.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/20/25.
//

import SwiftUI
import UniformTypeIdentifiers
import SwiftData


// MARK: - Drag payload (safe for Transferable; avoids Color/complex fields)
struct HabitDragPayload: Identifiable, Hashable, Codable, Transferable {
    let id: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

// MARK: - Priority Matrix
struct PriorityMatrixView: View {

    @EnvironmentObject var viewModel: HabitListViewModel
    
    var onMove: ((HabitModel, PriorityEisenhower) -> Void)?
    
    init(onMove: ((HabitModel, PriorityEisenhower) -> Void)? = nil) {
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
                    header(for: viewModel.titles[PriorityEisenhower.importantAndUrgent.index],
                           priorityColor: viewModel.colors[PriorityEisenhower.importantAndUrgent.index],
                           alignRight: false)
                    Spacer()
                    header(for: viewModel.titles[PriorityEisenhower.urgentButNotImportant.index],
                           priorityColor: viewModel.colors[PriorityEisenhower.urgentButNotImportant.index],
                           alignRight: true)
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
                header(for: viewModel.titles[PriorityEisenhower.importantButNotUrgent.index],
                       priorityColor: viewModel.colors[PriorityEisenhower.importantButNotUrgent.index],
                       alignRight: false)
                Spacer(minLength: 12)
                header(for: viewModel.titles[PriorityEisenhower.notUrgentAndNotImportant.index],
                       priorityColor: viewModel.colors[PriorityEisenhower.notUrgentAndNotImportant.index],
                       alignRight: true)
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 10)
    }
    
    // MARK: - Quadrant column
    
    private func quadrant(_ priority: PriorityEisenhower,
                          rowHeight: CGFloat) -> some View {
        let capsule = viewModel.items.filter { $0.priority == priority }
        
        let capsuleAlignment: Alignment = {
            // choose how chips line up horizontally
            switch priority {
            case .importantAndUrgent, .importantButNotUrgent: return .trailing
            case .urgentButNotImportant, .notUrgentAndNotImportant: return .leading
            }
        }()
        
        let pillColor: Color = {
            switch priority {
            case .importantAndUrgent:
                return viewModel.colors[PriorityEisenhower.importantAndUrgent.index]
            case .importantButNotUrgent:
                return viewModel.colors[PriorityEisenhower.importantButNotUrgent.index]
            case .urgentButNotImportant:
                return viewModel.colors[PriorityEisenhower.urgentButNotImportant.index]
            case .notUrgentAndNotImportant:
                return viewModel.colors[PriorityEisenhower.notUrgentAndNotImportant.index]
            }
        }()
        
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(capsule) { habit in
                HabitMatrixCapsuleView(habit: habit, tint: pillColor)
                    .draggable(HabitDragPayload(id: habit.id))
                    .frame(maxWidth: .infinity, alignment: capsuleAlignment)
                    .onTapGesture { // TODO: link on detail screen
                        print("Picked: \(habit.id)") // TODO: Link to details screen
//                        path.append(Route.detailHabit(habit.id))
                    }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: rowHeight, alignment: alignmentForCapsule(priority))
        .background(.gray.opacity(0.01))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .dropDestination(for: HabitDragPayload.self) { payloads, _ in
            withAnimation(.spring) {
                for payload in payloads { moveHabitWith(payload.id, to: priority) }
            }
            return true
        }
    }
    
    // MARK: - Headers
    
    @ViewBuilder
    private func header(for priority: PriorityEisenhower, alignRight: Bool) -> some View {
        let priorityText = priority.text.components(separatedBy: "/ ")
        VStack(alignment: alignRight ? .trailing : .leading, spacing: 2) {
            Text(priorityText[0]).font(.callout.weight(.semibold)).foregroundStyle(priority.color)
            Text(priorityText[1]).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
        }
    }
    
    private func header(for text: String, priorityColor: Color, alignRight: Bool) -> some View {
//        let priorityText = priority.text.components(separatedBy: "/ ")
//        VStack(alignment: alignRight ? .trailing : .leading, spacing: 2) {
            Text(text).font(.callout.weight(.semibold)).foregroundStyle(priorityColor)
//        }
    }
    
    // MARK: - Helpers
    private func alignmentForCapsule(_ priority: PriorityEisenhower) -> Alignment {
        switch priority {
        case .importantAndUrgent:        return .bottomTrailing
        case .importantButNotUrgent:     return .topTrailing
        case .urgentButNotImportant:     return .bottomLeading
        case .notUrgentAndNotImportant:  return .topLeading
        }
    }
    
    private func alignmentForHabitCapsule(_ priority: PriorityEisenhower) -> HorizontalAlignment {
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
    
    private func moveHabitWith(_ id: UUID, to newPriority: PriorityEisenhower) {
        Task {
            await viewModel.changePrirorityFor(id, to: newPriority)
        }
    }
}

// MARK: - Chip (uses your HabitModel + colors)

struct HabitMatrixCapsuleView: View {
    let habit: HabitModel
    let tint: Color?
    
    var body: some View {
        HStack(spacing: 5) {
            if let icon = habit.icon, !icon.isEmpty {
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "diamond.fill")
                    .scaledToFit()
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
            }
            Text(habit.title)
                .lineLimit(2)
                .foregroundStyle(.white)
                .font(.caption.weight(.semibold))
            
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill((tint ?? habit.priority.color).opacity(0.40))//18
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke((tint ?? habit.priority.color).opacity(0.35), lineWidth: 1)
        )
        .contentShape(Capsule())
    }
    
    static func habitExample(with color: Color) -> Self {
        .init(habit: HabitModel.habitExample(), tint: color)
    }
}

// MARK: - Preview / Example usage

struct PriorityMatrixView_Previews: PreviewProvider {
    static var previews: some View {
        let container = try! ModelContainer(
            for: Schema([HabitSD.self, HabitRecordSD.self, DeletedHabitSD.self]),
            configurations: .init(isStoredInMemoryOnly: true)
        )

        let repo = HabitsRepositorySwiftData(container: container)
        let vm = HabitListViewModel(repo: repo)

        // ✅ Inject mock habits into the preview view model

        return PriorityMatrixView()
            .environmentObject(vm)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
