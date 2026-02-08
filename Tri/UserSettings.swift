//
//  UserSettings.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI
import Combine

@MainActor
final class UserSettings: ObservableObject {
    @AppStorage("hasOnboarded") var hasOnboarded: Bool = false
    @AppStorage("favoriteWorkoutRaw") var favoriteWorkoutRaw: String = WorkoutType.swim.rawValue
    @AppStorage("dailyCaloriesGoal") var dailyCaloriesGoal: Double = 1000
    @AppStorage("weeklySwimGoal") var weeklySwimGoal: Double = 5000
    @AppStorage("weeklyBikeGoal") var weeklyBikeGoal: Double = 60
    @AppStorage("weeklyRunGoal") var weeklyRunGoal: Double = 12
    @AppStorage("streakIncludeSwim") var streakIncludeSwim: Bool = true
    @AppStorage("streakIncludeBike") var streakIncludeBike: Bool = true
    @AppStorage("streakIncludeRun") var streakIncludeRun: Bool = true
    @AppStorage("healthKitSyncEnabled") var healthKitSyncEnabled: Bool = false
    @AppStorage("healthKitSyncStart") var healthKitSyncStart: Double = 0
    @AppStorage("healthKitLastFetch") var healthKitLastFetch: Double = 0

    var favoriteWorkout: WorkoutType {
        get { WorkoutType(rawValue: favoriteWorkoutRaw) ?? .swim }
        set { favoriteWorkoutRaw = newValue.rawValue }
    }

    var healthKitStartDate: Date? {
        get { healthKitSyncStart > 0 ? Date(timeIntervalSince1970: healthKitSyncStart) : nil }
        set { healthKitSyncStart = newValue?.timeIntervalSince1970 ?? 0 }
    }

    var healthKitLastFetchDate: Date? {
        get { healthKitLastFetch > 0 ? Date(timeIntervalSince1970: healthKitLastFetch) : nil }
        set { healthKitLastFetch = newValue?.timeIntervalSince1970 ?? 0 }
    }

    var goalSnapshot: GoalSnapshot {
        GoalSnapshot(
            caloriesGoal: dailyCaloriesGoal,
            weeklySwimGoal: weeklySwimGoal,
            weeklyBikeGoal: weeklyBikeGoal,
            weeklyRunGoal: weeklyRunGoal
        )
    }
}
