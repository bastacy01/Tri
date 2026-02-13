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
    @State private var showAccountMenu = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Profile")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                    Spacer()
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            showAccountMenu.toggle()
                        }
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .topTrailing) {
                        if showAccountMenu {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(settings.userEmail)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white)
                                    .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 6)
                            )
                            .frame(maxWidth: 260, alignment: .trailing)
                            .fixedSize(horizontal: true, vertical: false)
                            .offset(y: 36)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(.top, 12)

                goalsSection
                streakSection
                logoutSection
                cancelSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .scrollDisabled(true)
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Goals")
                .font(.system(size: 20, weight: .bold, design: .serif))

            VStack(spacing: 12) {
                goalRow(title: "Daily Calories", value: $settings.dailyCaloriesGoal, range: 200...2500, step: 50, suffix: "cal")
                goalRow(title: "Weekly Swim", value: $settings.weeklySwimGoal, range: 25...20000, step: 25, suffix: "yd")
                goalRow(title: "Weekly Bike", value: $settings.weeklyBikeGoal, range: 1...300, step: 1, suffix: "mi")
                goalRow(title: "Weekly Run", value: $settings.weeklyRunGoal, range: 1...100, step: 1, suffix: "mi")
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

    private var logoutSection: some View {
        Button {
            // Placeholder for sign-out logic.
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Log Out")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
        }
        .foregroundStyle(Color.black)
    }

    private var cancelSection: some View {
        Button {
            // Placeholder for cancel subscription.
        } label: {
            HStack {
                Image(systemName: "xmark.circle")
                Text("Cancel Subscription")
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
        }
        .foregroundStyle(Color.red)
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
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Color.black)
            }
            Text("\(Int(value.wrappedValue)) \(suffix)")
                .font(.system(size: 16, weight: .bold))
                .contentTransition(.numericText())
                .frame(width: 90)
            Button {
                value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Color.black)
            }
        }
    }

    private func enableHealthKitSync() {
#if canImport(HealthKit)
        Task { @MainActor in
            do {
                try await HealthKitManager.shared.requestAuthorization()
                let startDate = settings.healthKitStartDate ?? Date()
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
