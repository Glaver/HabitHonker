//
//  SelectHabitsView.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/6/25.
//

import SwiftUI

// MARK: - Screen

struct SelectHabitsView: View {
    @StateObject private var viewModel = SelectHabitsViewModel()
    
    
    var body: some View {
        
            ScrollView {
                VStack(spacing: 12) {
                    // Subtitle
                    Text("Select maximum \(viewModel.selectionLimit) habits to show")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    // Card container
                    VStack(spacing: 0) {
                        ForEach(viewModel.habits) { habit in
                            HabitRow(
                                habit: habit,
                                isAtLimit: viewModel.selectedCount >= viewModel.selectionLimit
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.toggle(habit.id) }

                            if habit.id != viewModel.habits.last?.id {
                                Divider().padding(.leading, 64)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        
            .onAppear {
//                Task {
//                    await viewModel
//                }
            }
    }
}

// MARK: - Row

struct HabitRow: View {
    let habit: Habit
    let isAtLimit: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Leading colored icon in a rounded square
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(habit.color.opacity(habit.isEnabled ? 0.18 : 0.10))
                    .frame(width: 40, height: 40)

                Image(systemName: habit.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(habit.color.opacity(habit.isEnabled ? 1 : 0.5))
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
        .overlay(
            (
                !habit.isEnabled || (!habit.isSelected && isAtLimit)
            )
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

// MARK: - Sample Data

enum SampleHabits {
    static func make() -> [Habit] {
        [
            Habit(name: "Meditation",         color: .blue,   systemImage: "cloud.fill", isEnabled: true,  isSelected: true),
            Habit(name: "Wash dishes",        color: .green,  systemImage: "drop.fill",  isEnabled: true,  isSelected: true),
            Habit(name: "Make 10 push ups",   color: .gray,   systemImage: "diamond",    isEnabled: false, isSelected: false),
            Habit(name: "Meeting with friend",color: .orange, systemImage: "person.2.fill", isEnabled: true, isSelected: true),
            Habit(name: "Work",               color: .red,    systemImage: "capsule.portrait.fill", isEnabled: true, isSelected: true),
            Habit(name: "Balance board",      color: .blue,   systemImage: "diamond",    isEnabled: true,  isSelected: true),
            Habit(name: "Morning water vs lime", color: .blue, systemImage: "diamond",   isEnabled: true),
            Habit(name: "Gym",                color: .gray,   systemImage: "diamond",    isEnabled: false),
            Habit(name: "Meditation",         color: .blue,   systemImage: "diamond",    isEnabled: true),
            Habit(name: "Reading books",      color: .red,    systemImage: "diamond",    isEnabled: true),
            Habit(name: "Balance board",      color: .red,    systemImage: "diamond",    isEnabled: true),
        ]
    }
}

// MARK: - Preview

#Preview {
    SelectHabitsView()
}
