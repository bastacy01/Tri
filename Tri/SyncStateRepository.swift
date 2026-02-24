//
//  SyncStateRepository.swift
//  Tri
//
//  Created by Codex on 2/24/26.
//

import Foundation
import SwiftData

struct HealthKitSyncState {
    var anchorData: Data?
    var startDate: Date?
    var lastFetchDate: Date?
}

@MainActor
final class SyncStateRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func load(ownerUID: String) throws -> HealthKitSyncState {
        if let entity = try fetchEntity(ownerUID: ownerUID) {
            return HealthKitSyncState(
                anchorData: entity.healthKitAnchorData,
                startDate: entity.healthKitStartDate,
                lastFetchDate: entity.healthKitLastFetchDate
            )
        }
        let entity = SyncStateEntity(ownerUID: ownerUID)
        context.insert(entity)
        try context.save()
        return HealthKitSyncState(anchorData: nil, startDate: nil, lastFetchDate: nil)
    }

    func save(ownerUID: String, state: HealthKitSyncState) throws {
        let entity = try fetchEntity(ownerUID: ownerUID) ?? {
            let created = SyncStateEntity(ownerUID: ownerUID)
            context.insert(created)
            return created
        }()
        entity.healthKitAnchorData = state.anchorData
        entity.healthKitStartDate = state.startDate
        entity.healthKitLastFetchDate = state.lastFetchDate
        try context.save()
    }

    func clear(ownerUID: String) throws {
        if let entity = try fetchEntity(ownerUID: ownerUID) {
            entity.healthKitAnchorData = nil
            entity.healthKitStartDate = nil
            entity.healthKitLastFetchDate = nil
            try context.save()
        }
    }

    private func fetchEntity(ownerUID: String) throws -> SyncStateEntity? {
        var descriptor = FetchDescriptor<SyncStateEntity>(
            predicate: #Predicate { $0.ownerUID == ownerUID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

