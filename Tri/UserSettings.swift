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
    @Published private(set) var goalHistory: [GoalHistoryEntry] = []

    private var repository: UserProfileRepository?
    private var isHydrating = false
    private var lastGoalSnapshot = GoalSnapshot(
        caloriesGoal: 1000,
        weeklySwimGoal: 1000,
        weeklyBikeGoal: 10,
        weeklyRunGoal: 5
    )

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
        let uid = normalizedOwnerUID(ownerUID ?? Auth.auth().currentUser?.uid)
        do {
            let loaded = try repository.load(ownerUID: uid, seed: legacySeed)
            var state = loaded
            let defaultDaily = 1000.0
            let defaultSwim = 1000.0
            let defaultBike = 10.0
            let defaultRun = 5.0
            let loadedIsDefaultGoals =
                loaded.dailyCaloriesGoal == defaultDaily &&
                loaded.weeklySwimGoal == defaultSwim &&
                loaded.weeklyBikeGoal == defaultBike &&
                loaded.weeklyRunGoal == defaultRun
            let legacyHasCustomGoals =
                legacyDailyCaloriesGoal != defaultDaily ||
                legacyWeeklySwimGoal != defaultSwim ||
                legacyWeeklyBikeGoal != defaultBike ||
                legacyWeeklyRunGoal != defaultRun

            if loadedIsDefaultGoals && legacyHasCustomGoals {
                state.dailyCaloriesGoal = legacyDailyCaloriesGoal
                state.weeklySwimGoal = legacyWeeklySwimGoal
                state.weeklyBikeGoal = legacyWeeklyBikeGoal
                state.weeklyRunGoal = legacyWeeklyRunGoal
                try? repository.save(ownerUID: uid, state: state)
            }

            apply(state)
            lastGoalSnapshot = goalSnapshot
            loadGoalHistory(ownerUID: uid, fallbackSnapshot: lastGoalSnapshot)
            persistLegacySnapshot(from: state)
            print("[Tri] UserSettings loaded for uid=\(uid) hasOnboarded=\(state.hasOnboarded) hasActiveSubscription=\(state.hasActiveSubscription)")
        } catch {
            apply(legacySeed)
            lastGoalSnapshot = goalSnapshot
            print("[Tri] UserSettings load failed for uid=\(uid). Using legacy seed. error=\(error.localizedDescription)")
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

    func goalSnapshot(for date: Date) -> GoalSnapshot {
        guard !goalHistory.isEmpty else { return goalSnapshot }
        let sorted = goalHistory.sorted { $0.effectiveDate < $1.effectiveDate }
        var chosen = sorted.first?.snapshot ?? goalSnapshot
        for entry in sorted where entry.effectiveDate <= date {
            chosen = entry.snapshot
        }
        return chosen
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
        let uid = normalizedOwnerUID(Auth.auth().currentUser?.uid)
        let state = currentState
        do {
            try repository.save(ownerUID: uid, state: state)
            persistLegacySnapshot(from: state)
            recordGoalHistoryIfNeeded(ownerUID: uid, repository: repository)
        } catch {
            // No-op: keep UI/state responsive.
        }
    }

    private func loadGoalHistory(ownerUID: String, fallbackSnapshot: GoalSnapshot) {
        guard let repository else { return }
        do {
            let history = try repository.fetchGoalHistory(ownerUID: ownerUID)
            if history.isEmpty {
                let baseline = GoalHistoryEntry(
                    effectiveDate: Date.distantPast,
                    snapshot: fallbackSnapshot
                )
                try repository.appendGoalHistory(ownerUID: ownerUID, snapshot: baseline.snapshot, effectiveDate: baseline.effectiveDate)
                goalHistory = [baseline]
            } else {
                goalHistory = history
            }
        } catch {
            goalHistory = [GoalHistoryEntry(effectiveDate: Date.distantPast, snapshot: fallbackSnapshot)]
        }
    }

    private func recordGoalHistoryIfNeeded(ownerUID: String, repository: UserProfileRepository) {
        let current = goalSnapshot
        guard current.caloriesGoal != lastGoalSnapshot.caloriesGoal ||
              current.weeklySwimGoal != lastGoalSnapshot.weeklySwimGoal ||
              current.weeklyBikeGoal != lastGoalSnapshot.weeklyBikeGoal ||
              current.weeklyRunGoal != lastGoalSnapshot.weeklyRunGoal else {
            return
        }

        do {
            if goalHistory.isEmpty {
                try repository.appendGoalHistory(
                    ownerUID: ownerUID,
                    snapshot: lastGoalSnapshot,
                    effectiveDate: Date.distantPast
                )
                goalHistory = [GoalHistoryEntry(effectiveDate: Date.distantPast, snapshot: lastGoalSnapshot)]
            }

            let now = Date()
            try repository.appendGoalHistory(ownerUID: ownerUID, snapshot: current, effectiveDate: now)
            if let lastIndex = goalHistory.indices.last,
               now.timeIntervalSince(goalHistory[lastIndex].effectiveDate) < 5 {
                goalHistory[lastIndex] = GoalHistoryEntry(effectiveDate: goalHistory[lastIndex].effectiveDate, snapshot: current)
            } else {
                goalHistory.append(GoalHistoryEntry(effectiveDate: now, snapshot: current))
                goalHistory.sort { $0.effectiveDate < $1.effectiveDate }
            }
            lastGoalSnapshot = current
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

    private func normalizedOwnerUID(_ uid: String?) -> String {
        guard let uid else { return "local" }
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = trimmed.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return allowed.isEmpty ? "local" : allowed
    }
}
