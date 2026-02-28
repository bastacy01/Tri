//
//  UserSettings.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI
import Combine
import SwiftData
import FirebaseAuth

@MainActor
final class UserSettings: ObservableObject {
    @AppStorage("hasOnboarded") private var legacyHasOnboarded: Bool = false
    @AppStorage("hasActiveSubscription") private var legacyHasActiveSubscription: Bool = false
    @AppStorage("subscriptionProductID") private var legacySubscriptionProductID: String = ""
    @AppStorage("favoriteWorkoutRaw") private var legacyFavoriteWorkoutRaw: String = WorkoutType.swim.rawValue
    @AppStorage("dailyCaloriesGoal") private var legacyDailyCaloriesGoal: Double = 1000
    @AppStorage("weeklySwimGoal") private var legacyWeeklySwimGoal: Double = 1000
    @AppStorage("weeklyBikeGoal") private var legacyWeeklyBikeGoal: Double = 10
    @AppStorage("weeklyRunGoal") private var legacyWeeklyRunGoal: Double = 5
    @AppStorage("streakIncludeSwim") private var legacyStreakIncludeSwim: Bool = true
    @AppStorage("streakIncludeBike") private var legacyStreakIncludeBike: Bool = true
    @AppStorage("streakIncludeRun") private var legacyStreakIncludeRun: Bool = true
    @AppStorage("healthKitSyncEnabled") private var legacyHealthKitSyncEnabled: Bool = true
    @AppStorage("userEmail") private var legacyUserEmail: String = "user@triapp.com"

    @Published var hasOnboarded: Bool = false { didSet { persistProfileIfNeeded() } }
    @Published var hasActiveSubscription: Bool = false { didSet { persistProfileIfNeeded() } }
    @Published var subscriptionProductID: String? = nil { didSet { persistProfileIfNeeded() } }
    @Published var favoriteWorkoutRaw: String = WorkoutType.swim.rawValue { didSet { persistProfileIfNeeded() } }
    @Published var dailyCaloriesGoal: Double = 1000 { didSet { persistProfileIfNeeded() } }
    @Published var weeklySwimGoal: Double = 1000 { didSet { persistProfileIfNeeded() } }
    @Published var weeklyBikeGoal: Double = 10 { didSet { persistProfileIfNeeded() } }
    @Published var weeklyRunGoal: Double = 5 { didSet { persistProfileIfNeeded() } }
    @Published var streakIncludeSwim: Bool = true { didSet { persistProfileIfNeeded() } }
    @Published var streakIncludeBike: Bool = true { didSet { persistProfileIfNeeded() } }
    @Published var streakIncludeRun: Bool = true { didSet { persistProfileIfNeeded() } }
    @Published var healthKitSyncEnabled: Bool = true { didSet { persistProfileIfNeeded() } }
    @Published var userEmail: String = "user@triapp.com" { didSet { persistProfileIfNeeded() } }

    private var repository: UserProfileRepository?
    private var isHydrating = false

    var favoriteWorkout: WorkoutType {
        get { WorkoutType(rawValue: favoriteWorkoutRaw) ?? .swim }
        set { favoriteWorkoutRaw = newValue.rawValue }
    }

    func configureRepository(context: ModelContext) {
        repository = UserProfileRepository(context: context)
        reloadFromStorage()
    }

    func reloadFromStorage(ownerUID: String? = nil) {
        guard let repository else { return }
        let uid = ownerUID ?? Auth.auth().currentUser?.uid ?? "local"
        do {
            let loaded = try repository.load(ownerUID: uid, seed: legacySeed)
            apply(loaded)
            persistLegacySnapshot(from: loaded)
        } catch {
            apply(legacySeed)
        }
    }

    var goalSnapshot: GoalSnapshot {
        GoalSnapshot(
            caloriesGoal: dailyCaloriesGoal,
            weeklySwimGoal: weeklySwimGoal,
            weeklyBikeGoal: weeklyBikeGoal,
            weeklyRunGoal: weeklyRunGoal
        )
    }

    private var legacySeed: UserProfileState {
        UserProfileState(
            hasOnboarded: legacyHasOnboarded,
            hasActiveSubscription: legacyHasActiveSubscription,
            subscriptionProductID: legacySubscriptionProductID.isEmpty ? nil : legacySubscriptionProductID,
            favoriteWorkoutRaw: legacyFavoriteWorkoutRaw,
            dailyCaloriesGoal: legacyDailyCaloriesGoal,
            weeklySwimGoal: legacyWeeklySwimGoal,
            weeklyBikeGoal: legacyWeeklyBikeGoal,
            weeklyRunGoal: legacyWeeklyRunGoal,
            streakIncludeSwim: legacyStreakIncludeSwim,
            streakIncludeBike: legacyStreakIncludeBike,
            streakIncludeRun: legacyStreakIncludeRun,
            healthKitSyncEnabled: legacyHealthKitSyncEnabled,
            userEmail: legacyUserEmail
        )
    }

    private var currentState: UserProfileState {
        UserProfileState(
            hasOnboarded: hasOnboarded,
            hasActiveSubscription: hasActiveSubscription,
            subscriptionProductID: subscriptionProductID,
            favoriteWorkoutRaw: favoriteWorkoutRaw,
            dailyCaloriesGoal: dailyCaloriesGoal,
            weeklySwimGoal: weeklySwimGoal,
            weeklyBikeGoal: weeklyBikeGoal,
            weeklyRunGoal: weeklyRunGoal,
            streakIncludeSwim: streakIncludeSwim,
            streakIncludeBike: streakIncludeBike,
            streakIncludeRun: streakIncludeRun,
            healthKitSyncEnabled: healthKitSyncEnabled,
            userEmail: userEmail
        )
    }

    private func apply(_ state: UserProfileState) {
        isHydrating = true
        hasOnboarded = state.hasOnboarded
        hasActiveSubscription = state.hasActiveSubscription
        subscriptionProductID = state.subscriptionProductID
        favoriteWorkoutRaw = state.favoriteWorkoutRaw
        dailyCaloriesGoal = state.dailyCaloriesGoal
        weeklySwimGoal = state.weeklySwimGoal
        weeklyBikeGoal = state.weeklyBikeGoal
        weeklyRunGoal = state.weeklyRunGoal
        streakIncludeSwim = state.streakIncludeSwim
        streakIncludeBike = state.streakIncludeBike
        streakIncludeRun = state.streakIncludeRun
        healthKitSyncEnabled = state.healthKitSyncEnabled
        userEmail = state.userEmail
        isHydrating = false
    }

    private func persistProfileIfNeeded() {
        guard !isHydrating, let repository else { return }
        let uid = Auth.auth().currentUser?.uid ?? "local"
        let state = currentState
        do {
            try repository.save(ownerUID: uid, state: state)
            persistLegacySnapshot(from: state)
        } catch {
            // No-op: keep UI/state responsive.
        }
    }

    private func persistLegacySnapshot(from state: UserProfileState) {
        legacyHasOnboarded = state.hasOnboarded
        legacyHasActiveSubscription = state.hasActiveSubscription
        legacySubscriptionProductID = state.subscriptionProductID ?? ""
        legacyFavoriteWorkoutRaw = state.favoriteWorkoutRaw
        legacyDailyCaloriesGoal = state.dailyCaloriesGoal
        legacyWeeklySwimGoal = state.weeklySwimGoal
        legacyWeeklyBikeGoal = state.weeklyBikeGoal
        legacyWeeklyRunGoal = state.weeklyRunGoal
        legacyStreakIncludeSwim = state.streakIncludeSwim
        legacyStreakIncludeBike = state.streakIncludeBike
        legacyStreakIncludeRun = state.streakIncludeRun
        legacyHealthKitSyncEnabled = state.healthKitSyncEnabled
        legacyUserEmail = state.userEmail
    }
}
