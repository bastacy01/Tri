//
//  CalendarView.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var selectedDate = Date()
    @State private var scope: WorkoutScope = .day
    @State private var isCalendarVisible = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Calendar")
                    .font(.system(size: 26, weight: .bold, design: .serif))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isCalendarVisible.toggle()
                    }
                } label: {
                    Image(systemName: isCalendarVisible ? "calendar.badge.minus" : "calendar.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .frame(width: 36, height: 36)
//                        .background(
//                            Circle()
//                                .fill(Color.white)
//                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
//                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            if isCalendarVisible {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .tint(.black)
                .padding(.horizontal, 16)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                ))
            }
//            .overlay(alignment: .topTrailing) {
//                Button {
//                    selectedDate = Date()
//                } label: {
//                    Text("Today")
//                        .font(.system(size: 12, weight: .semibold, design: .serif))
//                        .foregroundStyle(Color.black)
//                        .padding(.horizontal, 10)
//                        .padding(.vertical, 6)
//                        .background(
//                            Capsule(style: .continuous)
//                                .fill(Color.white)
//                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
//                        )
//                }
//                .buttonStyle(.plain)
//                .padding(.trailing, 6)
//            }

            HStack(spacing: 12) {
                Text("Workouts")
                    .font(.system(size: 20, weight: .bold, design: .serif))

                Spacer()

                Picker("Scope", selection: $scope) {
                    ForEach(WorkoutScope.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 110)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .scaleEffect(0.9)
                .frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, -5)
            .offset(y: isCalendarVisible ? 0 : 16)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    let workouts = workoutsForSelection
                    if workouts.isEmpty {
                        Text("No workouts logged for this day.")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.5))
                            .padding(.vertical, 24)
                    } else {
                        ForEach(workouts) { workout in
                            RecentWorkoutRow(
                                workout: RecentWorkout(
                                    type: workout.type,
                                    distance: workout.distanceString,
                                    duration: workout.durationString,
                                    calories: workout.caloriesString,
                                    date: formattedDate(workout.date)
                                )
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 110)
            }
            .padding(.top, isCalendarVisible ? 0 : 16)
        }
    }

    private var workoutsForSelection: [Workout] {
        switch scope {
        case .day:
            return store.workouts(on: selectedDate)
        case .week:
            guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
            return store.workouts
                .filter { $0.date >= interval.start && $0.date < interval.end }
                .sorted { $0.date > $1.date }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter.string(from: date)
    }
}

private enum WorkoutScope: CaseIterable {
    case day
    case week

    var label: String {
        switch self {
        case .day:
            return "D"
        case .week:
            return "W"
        }
    }
}
