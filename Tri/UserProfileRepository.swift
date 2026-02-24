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

    init(context: ModelContext) {
        self.context = context
    }

    func load(ownerUID: String, seed: UserProfileState) throws -> UserProfileState {
        if let entity = try fetchEntity(ownerUID: ownerUID) {
            return UserProfileState(
                hasOnboarded: entity.hasOnboarded,
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

    private func fetchEntity(ownerUID: String) throws -> UserProfileEntity? {
        var descriptor = FetchDescriptor<UserProfileEntity>(
            predicate: #Predicate { $0.ownerUID == ownerUID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

