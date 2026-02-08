//
//  HealthKitManager.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import Foundation

#if canImport(HealthKit)
import HealthKit

@MainActor
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let healthStore = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let workoutType = HKObjectType.workoutType()
        try await healthStore.requestAuthorization(toShare: [], read: Set([workoutType]))
    }

    func startObservingNewWorkouts(
        startDateProvider: @escaping () -> Date,
        onUpdate: @escaping ([Workout], Date) -> Void
    ) {
        let workoutType = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completion, _ in
            Task { @MainActor in
                guard let self else {
                    completion()
                    return
                }
                let now = Date()
                let workouts = await self.fetchWorkouts(since: startDateProvider())
                onUpdate(workouts, now)
                completion()
            }
        }
        healthStore.execute(query)
    }

    func fetchWorkouts(since startDate: Date) async -> [Workout] {
        await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: 50, sortDescriptors: [sort]) { _, samples, _ in
                let workouts: [Workout] = (samples as? [HKWorkout])?.compactMap { workout in
                    guard let type = WorkoutTypeMapper.map(activityType: workout.workoutActivityType) else {
                        return nil
                    }
                    let distance: Double = workout.totalDistance?.doubleValue(for: type == .swim ? .yard() : .mile()) ?? 0
                    return Workout(
                        type: type,
                        distance: distance,
                        duration: workout.duration,
                        calories: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0,
                        date: workout.endDate,
                        source: .healthKit
                    )
                } ?? []
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
    }
}

enum WorkoutTypeMapper {
    static func map(activityType: HKWorkoutActivityType) -> WorkoutType? {
        switch activityType {
        case .swimming:
            return .swim
        case .cycling:
            return .bike
        case .running:
            return .run
        default:
            return nil
        }
    }
}
#endif
