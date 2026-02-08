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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .padding(.horizontal, 20)
                .padding(.top, 12)

            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .tint(.black)
            .padding(.horizontal, 16)

            Text("Workouts")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .padding(.horizontal, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    let workouts = store.workouts(on: selectedDate)
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
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter.string(from: date)
    }
}
