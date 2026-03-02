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
    @Published var lastPersistenceError: String?
    @Published var debugStatus: String = "Workout store idle."
    private var repository: WorkoutRepository?
    private var activeOwnerUID: String = "local"

    var isRepositoryConfigured: Bool {
        repository != nil
    }

    func configureRepository(_ repository: WorkoutRepository) {
        self.repository = repository
        updateDebugStatus("Repository configured for owner '\(activeOwnerUID)'.")
        reloadFromStorage()
    }

    func updateOwnerUID(_ uid: String?) {
        let resolved = normalizeOwnerUID(uid)
        guard resolved != activeOwnerUID else { return }
        activeOwnerUID = resolved
        updateDebugStatus("Switched owner to '\(activeOwnerUID)'. Reloading workouts.")
        reloadFromStorage()
    }

    func reloadFromStorage() {
        guard let repository else { return }
        do {
            workouts = try repository.fetchVisibleWorkouts(ownerUID: activeOwnerUID)
            updateDebugStatus("Reloaded \(workouts.count) workouts for owner '\(activeOwnerUID)'.")
        } catch {
            workouts = []
            reportPersistenceError(operation: "Reload workouts", error: error)
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
                updateDebugStatus("Saving manual workout \(workout.id.uuidString.prefix(8)) for owner '\(activeOwnerUID)'.")
                try repository.addManualWorkout(workout, ownerUID: activeOwnerUID)
                workouts = try repository.fetchVisibleWorkouts(ownerUID: activeOwnerUID)
                if workouts.contains(where: { $0.id == workout.id }) {
                    updateDebugStatus("Saved manual workout. Total workouts: \(workouts.count) for owner '\(activeOwnerUID)'.")
                } else {
                    let missingMessage = "Save manual workout completed but inserted workout was not returned for owner '\(activeOwnerUID)'. Total workouts: \(workouts.count)."
                    lastPersistenceError = missingMessage
                    updateDebugStatus(missingMessage)
                }
            } catch {
                reportPersistenceError(operation: "Save manual workout", error: error)
            }
            return
        }
        workouts.insert(workout, at: 0)
        updateDebugStatus("Saved manual workout in memory only (repository not configured). Total workouts: \(workouts.count).")
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
                try repository.upsertHealthKitWorkouts(payloads, ownerUID: activeOwnerUID)
                for identifier in deletedSourceIdentifiers {
                    try repository.hideHealthKitWorkout(sourceIdentifier: identifier, ownerUID: activeOwnerUID)
                }
                workouts = try repository.fetchVisibleWorkouts(ownerUID: activeOwnerUID)
                updateDebugStatus("Applied HealthKit updates. Total workouts: \(workouts.count) for owner '\(activeOwnerUID)'.")
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
                reportPersistenceError(operation: "Apply HealthKit updates", error: error)
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
        updateDebugStatus("Applied HealthKit updates in memory only. Total workouts: \(workouts.count).")
    }

    func deleteWorkout(_ workout: Workout) {
        if let repository {
            do {
                try repository.hideWorkout(id: workout.id, ownerUID: activeOwnerUID)
                workouts = try repository.fetchVisibleWorkouts(ownerUID: activeOwnerUID)
                updateDebugStatus("Deleted workout. Total workouts: \(workouts.count) for owner '\(activeOwnerUID)'.")
            } catch {
                workouts.removeAll { $0.id == workout.id }
                reportPersistenceError(operation: "Delete workout", error: error)
            }
            return
        }
        workouts.removeAll { $0.id == workout.id }
        updateDebugStatus("Deleted workout in memory only. Total workouts: \(workouts.count).")
    }

    func clearAll() {
        if let repository {
            do {
                try repository.clearAll(ownerUID: activeOwnerUID)
                workouts = []
                updateDebugStatus("Cleared workouts for owner '\(activeOwnerUID)'.")
            } catch {
                workouts.removeAll()
                reportPersistenceError(operation: "Clear workouts", error: error)
            }
            return
        }
        workouts.removeAll()
        updateDebugStatus("Cleared workouts in memory only.")
    }

    func clearPersistenceError() {
        lastPersistenceError = nil
    }

    var currentOwnerUID: String {
        activeOwnerUID
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

    private func healthKitFingerprint(for workout: Workout) -> String {
        "\(workout.type.rawValue)|\(workout.date.timeIntervalSince1970)|\(workout.distance)|\(workout.duration)"
    }

    private func normalizeOwnerUID(_ uid: String?) -> String {
        guard let uid else { return "local" }
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = trimmed.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return allowed.isEmpty ? "local" : allowed
    }

    private func reportPersistenceError(operation: String, error: Error) {
        let nsError = error as NSError
        let message = "\(operation) failed for owner '\(activeOwnerUID)'. \(nsError.localizedDescription) (domain: \(nsError.domain), code: \(nsError.code))"
        lastPersistenceError = message
        updateDebugStatus(message)
    }

    private func updateDebugStatus(_ message: String) {
        debugStatus = message
        print("WorkoutStore debug: \(message)")
    }
}
