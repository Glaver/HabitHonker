//
//  SelectHabitsView.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import SwiftUI

// MARK: - Screen

struct SelectHabitsView: View {
    @StateObject private var viewModel: SelectHabitsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorSchema
    
    var sectionBackgroundColor: Color {
        colorSchema == .dark ? Color(UIColor.secondarySystemBackground) : Color(UIColor.systemBackground)
    }
    
    init(viewModel: SelectHabitsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Select maximum \(viewModel.selectionLimit) habits to show")
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                        .padding(.top, -20)
                    
                    if !viewModel.activeHabits.isEmpty {
                        HabitListCard(
                            habits: viewModel.activeHabits,
                            isAtLimit: viewModel.selectedCount >= viewModel.selectionLimit,
                            onTap: { viewModel.toggle($0) },
                            backgroundColor: sectionBackgroundColor
                        )
                    }
                    
                    if !viewModel.deletedHabits.isEmpty {
                        Text("Deleted habits")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                        
                        HabitListCard(
                            habits: viewModel.deletedHabits,
                            isAtLimit: viewModel.selectedCount >= viewModel.selectionLimit,
                            onTap: { viewModel.toggle($0) },
                            backgroundColor: sectionBackgroundColor
                        )
                    }
                }
                .padding(.top, 8)
            }
            if viewModel.isSelectionChanged {
                VStack {
                    Spacer()
                    Button(action: {
                        Task {
                            await viewModel.persistPreset()
                        }
                        dismiss()
                    }) {
                        Text("Save")
                            .frame(maxWidth: .infinity, minHeight: 54)   // fills width + height
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)                     // text color
                            .background(.blue.opacity(0.6))              // background inside label
                            .clipShape(Capsule())                        // rounded corners / capsule
                            .glassEffect(.regular, in: Capsule())
                            .shadow(color: .blue.opacity(0.7), radius: 5, x: 2, y: 2)
                    }
                    
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 20)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Select habits")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGray6))
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            Task {
                await viewModel.load()
            }
        }
    }
}

// MARK: - Row

private struct HabitListCard: View {
    let habits: [Habit]
    let isAtLimit: Bool
    let onTap: (UUID) -> Void
    let backgroundColor: Color
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                HabitRow(
                    habit: habit,
                    isAtLimit: isAtLimit
                )
                .contentShape(Rectangle())
                .onTapGesture { onTap(habit.id) }
                
                if index < habits.count - 1 {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

struct HabitRow: View {
    @Environment(\.colorScheme) var scheme
    let habit: Habit
    let isAtLimit: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Leading colored icon in a rounded square
            GlassEffectContainer {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(habit.isEnabled ? habit.color.opacity(Color.opacityForSheme(scheme)) : Color(.systemGroupedBackground))//.opacity(habit.isEnabled ? 0.18 : 0.10))//
                        .frame(width: 42, height: 42)
                        .zIndex(1)
                    
                    Image(habit.systemImage)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .scaledToFit()
                        .foregroundColor(.primary.opacity(1))
                        .zIndex(2)
                        .padding(.vertical, 10)
                }
            }
            .padding(.leading, 12)
            
            // Title
            Text(habit.name)
                .foregroundStyle(habit.isEnabled ? .primary : .secondary)
                .opacity(habit.isEnabled ? 1 : 0.5)
            
            Spacer()
            
            // Trailing selection indicator
            SelectionCheck(isOn: habit.isSelected, disabled: !habit.isSelected && isAtLimit || !habit.isEnabled)
                .padding(.trailing, 12)
        }
        .frame(height: 56)
        .background(
            // Tap feedback highlight for enabled rows
            (habit.isEnabled ? Color.clear : Color.clear)
        )
        .overlay((!habit.isEnabled || (!habit.isSelected && isAtLimit))
                 ? Rectangle()
            .fill(Color.black.opacity(0.02))
            .allowsHitTesting(false)
                 : nil
        )
    }
}

struct SelectionCheck: View {
    let isOn: Bool
    let disabled: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(disabled ? Color(.systemGray4) : Color(.systemGray3), lineWidth: 2)
                .frame(width: 24, height: 24)
            
            if isOn {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isOn)
        .opacity(disabled && !isOn ? 0.5 : 1)
    }
}

// MARK: - Preview

//#Preview {
//    SelectHabitsView()
//}
