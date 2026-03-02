//
//  WorkoutRepository.swift
//  Tri
//
//  Created by Codex on 2/24/26.
//

import Foundation
import SwiftData

enum WorkoutRepositoryError: LocalizedError {
    case insertedWorkoutMissing(savedID: UUID, ownerUID: String, totalEntityCount: Int, ownerEntityCount: Int)

    var errorDescription: String? {
        switch self {
        case .insertedWorkoutMissing(let savedID, let ownerUID, let totalEntityCount, let ownerEntityCount):
            return "Saved workout \(savedID.uuidString) was not found after save for owner '\(ownerUID)'. totalEntities=\(totalEntityCount), ownerEntities=\(ownerEntityCount)."
        }
    }
}

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
    private let storageURL: URL

    private struct PersistedWorkoutRecord: Codable {
        let id: UUID
        let ownerUID: String
        let sourceRaw: String
        let sourceIdentifier: String?
        let typeRaw: String
        let distance: Double
        let duration: TimeInterval
        let calories: Double
        let date: Date
        let createdAt: Date
        var isHidden: Bool
    }

    init(context: ModelContext) {
        self.context = context
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        self.storageURL = documentsDirectory.appendingPathComponent("tri_workouts.json")
    }

    func fetchVisibleWorkouts(ownerUID: String) throws -> [Workout] {
        let ownerUID = normalizeOwnerUID(ownerUID)
        return try loadRecords()
            .filter { $0.ownerUID == ownerUID && $0.isHidden == false }
            .sorted { $0.date > $1.date }
            .compactMap(mapToWorkout)
    }

    func addManualWorkout(_ workout: Workout, ownerUID: String) throws {
        let ownerUID = normalizeOwnerUID(ownerUID)
        var records = try loadRecords()
        records.removeAll { $0.id == workout.id && $0.ownerUID == ownerUID }
        records.append(
            PersistedWorkoutRecord(
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
        )
        try saveRecords(records)
    }

    func upsertHealthKitWorkouts(_ workouts: [HealthKitWorkoutPayload], ownerUID: String) throws {
        let ownerUID = normalizeOwnerUID(ownerUID)
        var records = try loadRecords()
        for payload in workouts {
            if records.contains(where: { $0.ownerUID == ownerUID && $0.sourceIdentifier == payload.sourceIdentifier }) {
                continue
            }
            records.append(
                PersistedWorkoutRecord(
                    id: UUID(),
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
            )
        }
        try saveRecords(records)
    }

    func hideWorkout(id: UUID, ownerUID: String) throws {
        let ownerUID = normalizeOwnerUID(ownerUID)
        var records = try loadRecords()
        guard let index = records.firstIndex(where: { $0.id == id && $0.ownerUID == ownerUID }) else { return }
        if records[index].sourceRaw == WorkoutSource.healthKit.rawValue {
            records[index].isHidden = true
        } else {
            records.remove(at: index)
        }
        try saveRecords(records)
    }

    func hideHealthKitWorkout(sourceIdentifier: String, ownerUID: String) throws {
        let ownerUID = normalizeOwnerUID(ownerUID)
        var records = try loadRecords()
        guard let index = records.firstIndex(where: {
            $0.ownerUID == ownerUID && $0.sourceIdentifier == sourceIdentifier
        }) else { return }
        records[index].isHidden = true
        try saveRecords(records)
    }

    func clearAll(ownerUID: String) throws {
        let ownerUID = normalizeOwnerUID(ownerUID)
        var records = try loadRecords()
        records.removeAll { $0.ownerUID == ownerUID }
        try saveRecords(records)
    }

    private func normalizeOwnerUID(_ ownerUID: String) -> String {
        let trimmed = ownerUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = trimmed.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return allowed.isEmpty ? "local" : allowed
    }

    private func loadRecords() throws -> [PersistedWorkoutRecord] {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return [] }
        let data = try Data(contentsOf: storageURL)
        if data.isEmpty { return [] }
        return (try? JSONDecoder().decode([PersistedWorkoutRecord].self, from: data)) ?? []
    }

    private func saveRecords(_ records: [PersistedWorkoutRecord]) throws {
        let data = try JSONEncoder().encode(records)
        try data.write(to: storageURL, options: .atomic)
    }

    private func mapToWorkout(_ record: PersistedWorkoutRecord) -> Workout? {
        guard let type = WorkoutType(rawValue: record.typeRaw) else { return nil }
        let source = WorkoutSource(rawValue: record.sourceRaw) ?? .manual
        return Workout(
            id: record.id,
            type: type,
            distance: record.distance,
            duration: record.duration,
            calories: record.calories,
            date: record.date,
            source: source,
            sourceIdentifier: record.sourceIdentifier
        )
    }
}
