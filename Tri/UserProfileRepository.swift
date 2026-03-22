//
//  UserProfileRepository.swift
//  Tri
//
//  Created by Codex on 2/24/26.
//

import Foundation
import SwiftData

struct UserProfileState {
    var hasOnboarded: Bool
    var hasActiveSubscription: Bool
    var subscriptionProductID: String?
    var favoriteWorkoutRaw: String
    var dailyCaloriesGoal: Double
    var weeklySwimGoal: Double
    var weeklyBikeGoal: Double
    var weeklyRunGoal: Double
    var streakIncludeSwim: Bool
    var streakIncludeBike: Bool
    var streakIncludeRun: Bool
    var healthKitSyncEnabled: Bool
    var userEmail: String
}

@MainActor
final class UserProfileRepository {
    private let context: ModelContext
    private let goalHistoryCoalesceWindow: TimeInterval = 5

    init(context: ModelContext) {
        self.context = context
    }

    func load(ownerUID: String, seed: UserProfileState) throws -> UserProfileState {
        if let entity = try fetchEntity(ownerUID: ownerUID) {
            return UserProfileState(
                hasOnboarded: entity.hasOnboarded,
                hasActiveSubscription: entity.hasActiveSubscription,
                subscriptionProductID: entity.subscriptionProductID,
                favoriteWorkoutRaw: entity.favoriteWorkoutRaw,
                dailyCaloriesGoal: entity.dailyCaloriesGoal,
                weeklySwimGoal: entity.weeklySwimGoal,
                weeklyBikeGoal: entity.weeklyBikeGoal,
                weeklyRunGoal: entity.weeklyRunGoal,
                streakIncludeSwim: entity.streakIncludeSwim,
                streakIncludeBike: entity.streakIncludeBike,
                streakIncludeRun: entity.streakIncludeRun,
                healthKitSyncEnabled: entity.healthKitSyncEnabled,
                userEmail: entity.userEmail
            )
        }

        let entity = UserProfileEntity(ownerUID: ownerUID)
        entity.hasOnboarded = seed.hasOnboarded
        entity.hasActiveSubscription = seed.hasActiveSubscription
        entity.subscriptionProductID = seed.subscriptionProductID
        entity.favoriteWorkoutRaw = seed.favoriteWorkoutRaw
        entity.dailyCaloriesGoal = seed.dailyCaloriesGoal
        entity.weeklySwimGoal = seed.weeklySwimGoal
        entity.weeklyBikeGoal = seed.weeklyBikeGoal
        entity.weeklyRunGoal = seed.weeklyRunGoal
        entity.streakIncludeSwim = seed.streakIncludeSwim
        entity.streakIncludeBike = seed.streakIncludeBike
        entity.streakIncludeRun = seed.streakIncludeRun
        entity.healthKitSyncEnabled = seed.healthKitSyncEnabled
        entity.userEmail = seed.userEmail
        context.insert(entity)
        try context.save()
        return seed
    }

    func save(ownerUID: String, state: UserProfileState) throws {
        let entity = try fetchEntity(ownerUID: ownerUID) ?? {
            let created = UserProfileEntity(ownerUID: ownerUID)
            context.insert(created)
            return created
        }()
        entity.hasOnboarded = state.hasOnboarded
        entity.hasActiveSubscription = state.hasActiveSubscription
        entity.subscriptionProductID = state.subscriptionProductID
        entity.favoriteWorkoutRaw = state.favoriteWorkoutRaw
        entity.dailyCaloriesGoal = state.dailyCaloriesGoal
        entity.weeklySwimGoal = state.weeklySwimGoal
        entity.weeklyBikeGoal = state.weeklyBikeGoal
        entity.weeklyRunGoal = state.weeklyRunGoal
        entity.streakIncludeSwim = state.streakIncludeSwim
        entity.streakIncludeBike = state.streakIncludeBike
        entity.streakIncludeRun = state.streakIncludeRun
        entity.healthKitSyncEnabled = state.healthKitSyncEnabled
        entity.userEmail = state.userEmail
        try context.save()
    }

    func fetchGoalHistory(ownerUID: String) throws -> [GoalHistoryEntry] {
        var descriptor = FetchDescriptor<GoalHistoryEntity>(
            predicate: #Predicate { $0.ownerUID == ownerUID }
        )
        descriptor.sortBy = [SortDescriptor(\.effectiveDate, order: .forward)]
        let entities = try context.fetch(descriptor)
        return entities.map {
            GoalHistoryEntry(
                effectiveDate: $0.effectiveDate,
                snapshot: GoalSnapshot(
                    caloriesGoal: $0.dailyCaloriesGoal,
                    weeklySwimGoal: $0.weeklySwimGoal,
                    weeklyBikeGoal: $0.weeklyBikeGoal,
                    weeklyRunGoal: $0.weeklyRunGoal
                )
            )
        }
    }

    func appendGoalHistory(ownerUID: String, snapshot: GoalSnapshot, effectiveDate: Date) throws {
        var descriptor = FetchDescriptor<GoalHistoryEntity>(
            predicate: #Predicate { $0.ownerUID == ownerUID }
        )
        descriptor.sortBy = [SortDescriptor(\.effectiveDate, order: .reverse)]
        descriptor.fetchLimit = 1
        let latest = try context.fetch(descriptor).first

        if let latest,
           effectiveDate.timeIntervalSince(latest.effectiveDate) < goalHistoryCoalesceWindow {
            latest.dailyCaloriesGoal = snapshot.caloriesGoal
            latest.weeklySwimGoal = snapshot.weeklySwimGoal
            latest.weeklyBikeGoal = snapshot.weeklyBikeGoal
            latest.weeklyRunGoal = snapshot.weeklyRunGoal
        } else {
            let entity = GoalHistoryEntity(
                ownerUID: ownerUID,
                effectiveDate: effectiveDate,
                dailyCaloriesGoal: snapshot.caloriesGoal,
                weeklySwimGoal: snapshot.weeklySwimGoal,
                weeklyBikeGoal: snapshot.weeklyBikeGoal,
                weeklyRunGoal: snapshot.weeklyRunGoal
            )
            context.insert(entity)
        }
        try context.save()
    }

    private func fetchEntity(ownerUID: String) throws -> UserProfileEntity? {
        var descriptor = FetchDescriptor<UserProfileEntity>(
            predicate: #Predicate { $0.ownerUID == ownerUID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
