//
//  ProfileView.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var store: WorkoutStore
    @State private var showingSyncAlert = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Profile")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .padding(.top, 12)

                goalsSection
                streakSection
                healthKitSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goals")
                .font(.system(size: 20, weight: .bold, design: .serif))

            VStack(spacing: 12) {
                goalRow(title: "Daily Calories", value: $settings.dailyCaloriesGoal, range: 200...2500, step: 50, suffix: "cal")
                goalRow(title: "Weekly Swim", value: $settings.weeklySwimGoal, range: 500...20000, step: 250, suffix: "yd")
                goalRow(title: "Weekly Bike", value: $settings.weeklyBikeGoal, range: 5...300, step: 5, suffix: "mi")
                goalRow(title: "Weekly Run", value: $settings.weeklyRunGoal, range: 2...100, step: 1, suffix: "mi")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
        }
    }

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HealthKit")
                .font(.system(size: 20, weight: .bold, design: .serif))

            VStack(spacing: 12) {
                Toggle("Sync new workouts", isOn: $settings.healthKitSyncEnabled)
                    .tint(.black)
                    .onChange(of: settings.healthKitSyncEnabled) { _, value in
                        if value {
                            enableHealthKitSync()
                        }
                    }

                Text("When enabled, Tri will only pull workouts added after you turn this on.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.55))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
        }
    }

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Streak")
                .font(.system(size: 20, weight: .bold, design: .serif))

            VStack(alignment: .leading, spacing: 12) {
                Text("Choose which goals count toward your weekly streak.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.55))

                Toggle("Swim goal", isOn: $settings.streakIncludeSwim)
                    .tint(.black)
                Toggle("Bike goal", isOn: $settings.streakIncludeBike)
                    .tint(.black)
                Toggle("Run goal", isOn: $settings.streakIncludeRun)
                    .tint(.black)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
            )
        }
    }

    private func goalRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        suffix: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Button {
                value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.black.opacity(0.08)))
            }
            Text("\(Int(value.wrappedValue)) \(suffix)")
                .font(.system(size: 16, weight: .bold))
                .frame(width: 90)
            Button {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.black.opacity(0.08)))
            }
        }
    }

    private func enableHealthKitSync() {
#if canImport(HealthKit)
        Task { @MainActor in
            do {
                try await HealthKitManager.shared.requestAuthorization()
                let startDate = Date()
                settings.healthKitStartDate = startDate
                settings.healthKitLastFetchDate = startDate
                HealthKitManager.shared.startObservingNewWorkouts(startDateProvider: {
                    settings.healthKitLastFetchDate ?? startDate
                }) { workouts, lastFetch in
                    store.mergeHealthKitWorkouts(workouts)
                    settings.healthKitLastFetchDate = lastFetch
                }
            } catch {
                settings.healthKitSyncEnabled = false
            }
        }
#else
        settings.healthKitSyncEnabled = false
#endif
    }
}
