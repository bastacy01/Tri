//
//  WorkoutStore.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI
import Combine

@MainActor
final class WorkoutStore: ObservableObject {
    @Published private(set) var workouts: [Workout] = []

    func loadMockData() {
        guard workouts.isEmpty else { return }
        workouts = [
            Workout(type: .swim, distance: 1450, duration: 2349, calories: 240, date: Date().addingTimeInterval(-86400), source: .manual),
            Workout(type: .bike, distance: 20, duration: 3898, calories: 1000, date: Date().addingTimeInterval(-172800), source: .manual),
            Workout(type: .run, distance: 2.6, duration: 1471, calories: 320, date: Date().addingTimeInterval(-259200), source: .manual)
        ]
    }

    func addManualWorkout(_ workout: Workout) {
        workouts.insert(workout, at: 0)
    }

    func mergeHealthKitWorkouts(_ newWorkouts: [Workout]) {
        let existingIDs = Set(workouts.map { $0.id })
        let unique = newWorkouts.filter { !existingIDs.contains($0.id) }
        workouts.insert(contentsOf: unique, at: 0)
    }

    func workouts(on date: Date, calendar: Calendar = .current) -> [Workout] {
        workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func totalCalories(on date: Date, calendar: Calendar = .current) -> Double {
        workouts(on: date, calendar: calendar).reduce(0) { $0 + $1.calories }
    }

    func totalDistance(for type: WorkoutType, inWeekContaining date: Date, calendar: Calendar = .current) -> Double {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return workouts.filter {
            $0.type == type && $0.date >= weekInterval.start && $0.date < weekInterval.end
        }
        .reduce(0) { $0 + $1.distance }
    }

    func workouts(inMonthEnding date: Date, monthsBack: Int, calendar: Calendar = .current) -> [Workout] {
        guard let start = calendar.date(byAdding: .month, value: -monthsBack, to: date) else { return [] }
        return workouts.filter { $0.date >= start && $0.date <= date }
    }
}
