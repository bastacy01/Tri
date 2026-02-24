//
//  WorkoutStore.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI
import Combine
import FirebaseAuth

@MainActor
final class WorkoutStore: ObservableObject {
    @Published private(set) var workouts: [Workout] = []
    private var repository: WorkoutRepository?

    var isRepositoryConfigured: Bool {
        repository != nil
    }

    func configureRepository(_ repository: WorkoutRepository) {
        self.repository = repository
        reloadFromStorage()
    }

    func reloadFromStorage() {
        guard let repository else { return }
        do {
            workouts = try repository.fetchVisibleWorkouts(ownerUID: ownerUID)
        } catch {
            workouts = []
        }
    }

    func loadMockData() {
        guard repository == nil else { return }
        guard workouts.isEmpty else { return }
        workouts = [
            Workout(type: .swim, distance: 1450, duration: 2349, calories: 240, date: Date().addingTimeInterval(-86400), source: .manual),
            Workout(type: .bike, distance: 20, duration: 3898, calories: 1000, date: Date().addingTimeInterval(-172800), source: .manual),
            Workout(type: .run, distance: 2.6, duration: 1471, calories: 320, date: Date().addingTimeInterval(-259200), source: .manual)
        ]
    }

    func addManualWorkout(_ workout: Workout) {
        if let repository {
            do {
                try repository.addManualWorkout(workout, ownerUID: ownerUID)
                workouts = try repository.fetchVisibleWorkouts(ownerUID: ownerUID)
            } catch {
                // Keep UI responsive even if persistence fails.
                workouts.insert(workout, at: 0)
            }
            return
        }
        workouts.insert(workout, at: 0)
    }

    func mergeHealthKitWorkouts(_ newWorkouts: [Workout]) {
        applyHealthKitChanges(added: newWorkouts, deletedSourceIdentifiers: [])
    }

    func applyHealthKitChanges(added newWorkouts: [Workout], deletedSourceIdentifiers: [String]) {
        if let repository {
            do {
                let payloads = newWorkouts.map {
                    HealthKitWorkoutPayload(
                        sourceIdentifier: $0.sourceIdentifier ?? healthKitFingerprint(for: $0),
                        type: $0.type,
                        distance: $0.distance,
                        duration: $0.duration,
                        calories: $0.calories,
                        date: $0.date
                    )
                }
                try repository.upsertHealthKitWorkouts(payloads, ownerUID: ownerUID)
                for identifier in deletedSourceIdentifiers {
                    try repository.hideHealthKitWorkout(sourceIdentifier: identifier, ownerUID: ownerUID)
                }
                workouts = try repository.fetchVisibleWorkouts(ownerUID: ownerUID)
            } catch {
                let existingIDs = Set(workouts.map { $0.id })
                let unique = newWorkouts.filter { !existingIDs.contains($0.id) }
                workouts.insert(contentsOf: unique, at: 0)
                if !deletedSourceIdentifiers.isEmpty {
                    workouts.removeAll { workout in
                        guard let sourceIdentifier = workout.sourceIdentifier else { return false }
                        return deletedSourceIdentifiers.contains(sourceIdentifier)
                    }
                }
            }
            return
        }
        let existingIDs = Set(workouts.map { $0.id })
        let unique = newWorkouts.filter { !existingIDs.contains($0.id) }
        workouts.insert(contentsOf: unique, at: 0)
        if !deletedSourceIdentifiers.isEmpty {
            workouts.removeAll { workout in
                guard let sourceIdentifier = workout.sourceIdentifier else { return false }
                return deletedSourceIdentifiers.contains(sourceIdentifier)
            }
        }
    }

    func deleteWorkout(_ workout: Workout) {
        if let repository {
            do {
                try repository.hideWorkout(id: workout.id, ownerUID: ownerUID)
                workouts = try repository.fetchVisibleWorkouts(ownerUID: ownerUID)
            } catch {
                workouts.removeAll { $0.id == workout.id }
            }
            return
        }
        workouts.removeAll { $0.id == workout.id }
    }

    func clearAll() {
        if let repository {
            do {
                try repository.clearAll(ownerUID: ownerUID)
                workouts = []
            } catch {
                workouts.removeAll()
            }
            return
        }
        workouts.removeAll()
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

    private var ownerUID: String {
        Auth.auth().currentUser?.uid ?? "local"
    }

    private func healthKitFingerprint(for workout: Workout) -> String {
        "\(workout.type.rawValue)|\(workout.date.timeIntervalSince1970)|\(workout.distance)|\(workout.duration)"
    }
}
