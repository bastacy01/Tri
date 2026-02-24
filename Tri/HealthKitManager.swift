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
        anchorDataProvider: @escaping () -> Data?,
        onUpdate: @escaping ([Workout], [String], Data?, Date) -> Void
    ) {
        let workoutType = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completion, _ in
            Task { @MainActor in
                guard let self else {
                    completion()
                    return
                }
                let now = Date()
                let (workouts, deletedIdentifiers, anchorData) = await self.fetchNewWorkouts(anchorData: anchorDataProvider())
                onUpdate(workouts, deletedIdentifiers, anchorData, now)
                completion()
            }
        }
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    }

    func fetchNewWorkouts(anchorData: Data?) async -> ([Workout], [String], Data?) {
        await withCheckedContinuation { continuation in
            let workoutType = HKObjectType.workoutType()
            let anchor = self.deserializeAnchor(from: anchorData)
            let query = HKAnchoredObjectQuery(
                type: workoutType,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, deletedObjects, newAnchor, _ in
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
                        source: .healthKit,
                        sourceIdentifier: workout.uuid.uuidString
                    )
                } ?? []
                let deletedIdentifiers = deletedObjects?.map { $0.uuid.uuidString } ?? []
                continuation.resume(returning: (workouts, deletedIdentifiers, self.serializeAnchor(newAnchor)))
            }
            self.healthStore.execute(query)
        }
    }

    private func serializeAnchor(_ anchor: HKQueryAnchor?) -> Data? {
        guard let anchor else { return nil }
        return try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
    }

    private func deserializeAnchor(from data: Data?) -> HKQueryAnchor? {
        guard let data, !data.isEmpty else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
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
