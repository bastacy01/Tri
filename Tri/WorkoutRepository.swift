//
//  WorkoutRepository.swift
//  Tri
//
//  Created by Codex on 2/24/26.
//

import Foundation
import SwiftData

struct HealthKitWorkoutPayload {
    let sourceIdentifier: String
    let type: WorkoutType
    let distance: Double
    let duration: TimeInterval
    let calories: Double
    let date: Date
}

protocol WorkoutRepository {
    func fetchVisibleWorkouts(ownerUID: String) throws -> [Workout]
    func addManualWorkout(_ workout: Workout, ownerUID: String) throws
    func upsertHealthKitWorkouts(_ workouts: [HealthKitWorkoutPayload], ownerUID: String) throws
    func hideWorkout(id: UUID, ownerUID: String) throws
    func hideHealthKitWorkout(sourceIdentifier: String, ownerUID: String) throws
    func clearAll(ownerUID: String) throws
}

@MainActor
final class SwiftDataWorkoutRepository: WorkoutRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchVisibleWorkouts(ownerUID: String) throws -> [Workout] {
        var descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { entity in
                entity.ownerUID == ownerUID && entity.isHidden == false
            }
        )
        descriptor.sortBy = [SortDescriptor(\WorkoutEntity.date, order: .reverse)]
        return try context.fetch(descriptor).compactMap(mapToWorkout)
    }

    func addManualWorkout(_ workout: Workout, ownerUID: String) throws {
        let entity = WorkoutEntity(
            id: workout.id,
            ownerUID: ownerUID,
            sourceRaw: WorkoutSource.manual.rawValue,
            sourceIdentifier: workout.sourceIdentifier,
            typeRaw: workout.type.rawValue,
            distance: workout.distance,
            duration: workout.duration,
            calories: workout.calories,
            date: workout.date,
            createdAt: Date(),
            isHidden: false
        )
        context.insert(entity)
        try context.save()
    }

    func upsertHealthKitWorkouts(_ workouts: [HealthKitWorkoutPayload], ownerUID: String) throws {
        for payload in workouts {
            if try findBySourceIdentifier(payload.sourceIdentifier, ownerUID: ownerUID) != nil {
                continue
            }
            let entity = WorkoutEntity(
                ownerUID: ownerUID,
                sourceRaw: WorkoutSource.healthKit.rawValue,
                sourceIdentifier: payload.sourceIdentifier,
                typeRaw: payload.type.rawValue,
                distance: payload.distance,
                duration: payload.duration,
                calories: payload.calories,
                date: payload.date,
                createdAt: Date(),
                isHidden: false
            )
            context.insert(entity)
        }
        try context.save()
    }

    func hideWorkout(id: UUID, ownerUID: String) throws {
        var descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { entity in
                entity.id == id && entity.ownerUID == ownerUID
            }
        )
        descriptor.fetchLimit = 1
        guard let entity = try context.fetch(descriptor).first else { return }
        if entity.sourceRaw == WorkoutSource.healthKit.rawValue {
            entity.isHidden = true
        } else {
            context.delete(entity)
        }
        try context.save()
    }

    func hideHealthKitWorkout(sourceIdentifier: String, ownerUID: String) throws {
        guard let entity = try findBySourceIdentifier(sourceIdentifier, ownerUID: ownerUID) else { return }
        entity.isHidden = true
        try context.save()
    }

    func clearAll(ownerUID: String) throws {
        let descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { entity in
                entity.ownerUID == ownerUID
            }
        )
        let entities = try context.fetch(descriptor)
        entities.forEach { context.delete($0) }
        try context.save()
    }

    private func findBySourceIdentifier(_ sourceIdentifier: String, ownerUID: String) throws -> WorkoutEntity? {
        var descriptor = FetchDescriptor<WorkoutEntity>(
            predicate: #Predicate { entity in
                entity.ownerUID == ownerUID && entity.sourceIdentifier == sourceIdentifier
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func mapToWorkout(_ entity: WorkoutEntity) -> Workout? {
        guard let type = WorkoutType(rawValue: entity.typeRaw) else { return nil }
        let source = WorkoutSource(rawValue: entity.sourceRaw) ?? .manual
        return Workout(
            id: entity.id,
            type: type,
            distance: entity.distance,
            duration: entity.duration,
            calories: entity.calories,
            date: entity.date,
            source: source,
            sourceIdentifier: entity.sourceIdentifier
        )
    }
}
