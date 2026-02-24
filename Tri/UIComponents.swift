//
//  UIComponents.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI

struct RingView: View {
    let progress: Double
    let lineWidth: CGFloat
    let size: CGFloat
    let tint: Color
    let background: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(background, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress <= 0 ? 0 : min(progress, 1))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: size, height: size)
    }
}

struct LiquidTabBar: View {
    @Binding var selectedTab: Tab
    @Binding var showAddWorkout: Bool
    private let barWidth: CGFloat = 365

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            tabCapsule
                .frame(maxWidth: .infinity)

            if selectedTab == .home {
                Button {
                    showAddWorkout = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Color.black)
                        .frame(width: 58, height: 58)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 5)
                        )
                }
                .buttonStyle(.plain)
                .offset(x: -6, y: -68)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var tabCapsule: some View {
        HStack {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .offset(y: tab == .home ? -1.5 : 0)
                    }
                    .foregroundStyle(selectedTab == tab ? Color.black : Color.black.opacity(0.45))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: barWidth)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 8)
        )
    }
}

struct WorkoutCardView: View {
    let card: WorkoutCard
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.distance)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                Text(card.type.rawValue)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.6))

                Spacer()

                HStack {
                    Spacer()
                    ZStack {
                        RingView(progress: card.progress, lineWidth: 6, size: 64, tint: .black, background: Color.black.opacity(0.12))
                        Image(systemName: card.type.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.black)
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RecentWorkoutRow: View {
    let workout: RecentWorkout

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Image(systemName: workout.type.systemImage)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.black)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(workout.type.rawValue)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.6))
                Text(workout.distance)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                Text(workout.duration)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 4) {
                    Text(workout.calories)
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: "flame.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Color.black.opacity(0.7))

                Spacer()

                Text(workout.date)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.5))
            }
            .frame(maxHeight: .infinity, alignment: .topTrailing)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        )
    }
}

struct StreaksSheet: View {
    let currentStreak: Int
    let longestStreak: Int
    let weeklyStreak: Int
    let includedTypes: [WorkoutType]

    var body: some View {
        VStack(spacing: 16) {
//            Capsule()
//                .fill(Color.black.opacity(0.2))
//                .frame(width: 50, height: 6)
//                .padding(.top, 8)

            Spacer()

            VStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 66, weight: .bold))
                    .foregroundStyle(Color.orange.gradient)

                Text("\(currentStreak)")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                
                Text("day streak")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.6))
            }

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Text("Longest streak")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("\(longestStreak) days")
                        .font(.system(size: 16, weight: .bold))
                }

                HStack(spacing: 8) {
                    Image(systemName: "figure.run")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black)
                    Text("Workout streak")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Text("\(weeklyStreak) weeks")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()
        }
        .padding(.top, 20)
    }
}

struct AddWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: WorkoutType = .swim
    @State private var distance = ""
    @State private var duration = ""
    @State private var calories = ""
    let onSave: (Workout) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Workout")
                .font(.system(size: 24, weight: .bold, design: .serif))

            Picker("Type", selection: $selectedType) {
                ForEach(WorkoutType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 12) {
                TextField("Distance (\(selectedType.unitLabel))", text: $distance)
                    .keyboardType(.decimalPad)
                TextField("Duration (minutes)", text: $duration)
                    .keyboardType(.numberPad)
                TextField("Calories (cal)", text: $calories)
                    .keyboardType(.numberPad)
            }
            .textFieldStyle(.roundedBorder)

            Button {
                onSave(parseWorkout())
                dismiss()
            } label: {
                Text("Save Workout")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(canSave ? Color.black : Color.gray.opacity(0.45))
                    )
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)

            Spacer()
        }
        .padding(24)
    }

    private func parseWorkout() -> Workout {
        let distanceValue = Double(distance.filter { "0123456789.".contains($0) }) ?? 0
        let caloriesValue = Double(calories.filter { "0123456789.".contains($0) }) ?? 0
        let durationValue = parseDuration(duration)
        return Workout(
            type: selectedType,
            distance: distanceValue,
            duration: durationValue,
            calories: caloriesValue,
            date: Date(),
            source: .manual
        )
    }

    private func parseDuration(_ text: String) -> TimeInterval {
        let parts = text.split(separator: ":").map { Double($0) ?? 0 }
        if parts.count == 3 {
            return parts[0] * 3600 + parts[1] * 60 + parts[2]
        }
        if parts.count == 2 {
            return parts[0] * 60 + parts[1]
        }
        if let minutes = parts.first {
            return minutes * 60
        }
        return 0
    }

    private var canSave: Bool {
        !distance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !duration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !calories.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct WorkoutGoalSheet: View {
    let type: WorkoutType
    let progress: Double
    let weeklyGoal: Double
    let weekTotal: Double

    var body: some View {
        VStack(spacing: 46) {
//            Capsule()
//                .fill(Color.black.opacity(0.2))
//                .frame(width: 50, height: 6)
//                .padding(.top, 8)
            
            Spacer()
            
            Text("\(type.rawValue) Weekly Goal")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .overlay(alignment: .bottom) {
                    if weeklyGoal > 0, weekTotal >= weeklyGoal {
                        Text("Completed!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.6))
                            .offset(y: 20)
                    }
                }

            ZStack {
                RingView(progress: progress, lineWidth: 9, size: 100, tint: .black, background: Color.black.opacity(0.12))
                Image(systemName: type.systemImage)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.black)
            }

            VStack(spacing: 10) {
                Text("\(Int(weekTotal)) \(type.unitLabel) this week")
                    .font(.system(size: 18, weight: .semibold))
                Text("Goal: \(Int(weeklyGoal)) \(type.unitLabel)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.5))
            }

            Spacer()
        }
        .padding(.top, 24)
    }
}

struct WorkoutDetailSheet: View {
    let workout: Workout
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: workout.type.systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(Color.black)

                VStack(alignment: .leading, spacing: 6) {
                    Text(workout.type.rawValue)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                    Text(formattedDate(workout.date))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.5))
                }

                Spacer()
            }
            VStack {
                Text("Workout Details")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 16) {
                    detailBlock(title: "Time", value: workout.durationString)
                    detailBlock(title: "Distance", value: workout.distanceString)
                    detailBlock(title: "Calories", value: "\(workout.caloriesString) cal")
                }
            }
            .padding(.top, 18)

            Spacer()

            Button {
                onDelete()
            } label: {
                Text("Delete Workout")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter.string(from: date)
    }

    private func detailBlock(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.5))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .serif))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.04))
        )
    }
}
