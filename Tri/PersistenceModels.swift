//
//  PersistenceModels.swift
//  Tri
//
//  Created by Codex on 2/24/26.
//

import Foundation
import SwiftData

@Model
final class WorkoutEntity {
    @Attribute(.unique) var id: UUID
    var ownerUID: String
    var sourceRaw: String
    var sourceIdentifier: String?
    var typeRaw: String
    var distance: Double
    var duration: Double
    var calories: Double
    var date: Date
    var createdAt: Date
    var isHidden: Bool

    init(
        id: UUID = UUID(),
        ownerUID: String,
        sourceRaw: String,
        sourceIdentifier: String? = nil,
        typeRaw: String,
        distance: Double,
        duration: Double,
        calories: Double,
        date: Date,
        createdAt: Date = Date(),
        isHidden: Bool = false
    ) {
        self.id = id
        self.ownerUID = ownerUID
        self.sourceRaw = sourceRaw
        self.sourceIdentifier = sourceIdentifier
        self.typeRaw = typeRaw
        self.distance = distance
        self.duration = duration
        self.calories = calories
        self.date = date
        self.createdAt = createdAt
        self.isHidden = isHidden
    }
}

@Model
final class UserProfileEntity {
    @Attribute(.unique) var ownerUID: String
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
    var hasOnboarded: Bool

    init(ownerUID: String) {
        self.ownerUID = ownerUID
        self.favoriteWorkoutRaw = WorkoutType.swim.rawValue
        self.dailyCaloriesGoal = 1000
        self.weeklySwimGoal = 1000
        self.weeklyBikeGoal = 10
        self.weeklyRunGoal = 5
        self.streakIncludeSwim = true
        self.streakIncludeBike = true
        self.streakIncludeRun = true
        self.healthKitSyncEnabled = false
        self.userEmail = "user@triapp.com"
        self.hasOnboarded = false
    }
}

@Model
final class SyncStateEntity {
    @Attribute(.unique) var ownerUID: String
    var healthKitAnchorData: Data?
    var healthKitStartDate: Date?
    var healthKitLastFetchDate: Date?

    init(ownerUID: String) {
        self.ownerUID = ownerUID
    }
}

