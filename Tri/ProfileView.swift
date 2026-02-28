//
//  ProfileView.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI
import FirebaseAuth
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var store: WorkoutStore
    @State private var showSettingsSheet = false
    @State private var showHealthKitErrorAlert = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showDeleteAccountErrorAlert = false
    @State private var showCancelSubscriptionConfirm = false
    @State private var deleteAccountErrorMessage = "Unable to delete your account right now."

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Profile")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                    Spacer()
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(Color.black)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)

                goalsSection
                streakSection
//                    .padding(.top, 8)
                healthKitSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
        }
        .scrollDisabled(true)
        .sheet(isPresented: $showSettingsSheet) {
            settingsSheet
//                .presentationDetents([.height(320)])
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Health Access Required", isPresented: $showHealthKitErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tri couldn't connect to Apple Health. Please allow Health access in Settings to sync Apple Watch workouts.")
        }
        .alert("Log Out?", isPresented: $showLogoutConfirm) {
            Button("Back", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to log out of your Tri account?")
        }
        .alert("Delete Account?", isPresented: $showDeleteAccountConfirm) {
            Button("Back", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your Tri account? This action is permanent and all user data will be erased.")
        }
        .alert("Delete Account Failed", isPresented: $showDeleteAccountErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteAccountErrorMessage)
        }
        .alert("Manage Subscription", isPresented: $showCancelSubscriptionConfirm) {
            Button("Back", role: .cancel) {}
            Button("Open App Store") {
                openManageSubscription()
            }
        } message: {
            Text("Subscriptions are managed by Apple. You can cancel there, and Tri access continues until your current billing period ends.")
        }
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
                    .font(.system(size: 14, weight: .semibold, design: .serif))
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

    private var healthKitSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HealthKit")
                .font(.system(size: 20, weight: .bold, design: .serif))

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Sync Apple Watch Workouts", isOn: healthKitToggleBinding)
                    .tint(.black)

                Text("When enabled, Tri will add workouts done on Apple Watch to app.")
                    .font(.system(size: 13, weight: .semibold))
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

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold, design: .serif))

            HStack(spacing: 10) {
                Image(systemName: "envelope")
                    .font(.system(size: 15, weight: .semibold))
                Text("Email: \(settings.userEmail)")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            )

            HStack(spacing: 10) {
                Image(systemName: "creditcard")
                    .font(.system(size: 15, weight: .semibold))
                Text("Plan: \(subscriptionPlan)")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
            )

            if let privacyURL = URL(string: "https://example.com/privacy-policy") {
                Link(destination: privacyURL) {
                    HStack {
                        Image(systemName: "hand.raised")
                        Text("Privacy Policy")
                            .font(.system(size: 16, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                    )
                }
            }

            Spacer()

            Button {
                showSettingsSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showLogoutConfirm = true
                }
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

            Button {
                showCancelSubscriptionConfirm = true
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

            Button {
                showSettingsSheet = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showDeleteAccountConfirm = true
                }
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Account")
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
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    private var subscriptionPlan: String {
        switch settings.subscriptionProductID {
        case "pro_monthly":
            return "Tri Monthly ($4.99/month)"
        case "pro_yearly":
            return "Tri Yearly ($44.99/year)"
        default:
            return settings.hasActiveSubscription ? "Tri Membership (Active)" : "Not Subscribed"
        }
    }

    private var healthKitToggleBinding: Binding<Bool> {
        Binding(
            get: { settings.healthKitSyncEnabled },
            set: { newValue in
                if newValue {
                    enableHealthKitSync()
                } else {
                    settings.healthKitSyncEnabled = false
                }
            }
        )
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
        let ownerUID = Auth.auth().currentUser?.uid ?? "local"
        let syncRepository = SyncStateRepository(context: modelContext)
        Task { @MainActor in
            do {
                try await HealthKitManager.shared.requestAuthorization()
                settings.healthKitSyncEnabled = true
                var syncState = try syncRepository.load(ownerUID: ownerUID)
                if syncState.startDate == nil {
                    syncState.startDate = Date()
                }
                let (initialWorkouts, deletedInitial, initialAnchor) = await HealthKitManager.shared.fetchNewWorkouts(
                    anchorData: syncState.anchorData
                )
                if !initialWorkouts.isEmpty {
                    store.applyHealthKitChanges(added: initialWorkouts, deletedSourceIdentifiers: deletedInitial)
                }
                syncState.anchorData = initialAnchor
                syncState.lastFetchDate = Date()
                try syncRepository.save(ownerUID: ownerUID, state: syncState)

                HealthKitManager.shared.startObservingNewWorkouts(anchorDataProvider: {
                    (try? syncRepository.load(ownerUID: ownerUID).anchorData) ?? nil
                }) { workouts, deletedIdentifiers, anchorData, lastFetch in
                    store.applyHealthKitChanges(added: workouts, deletedSourceIdentifiers: deletedIdentifiers)
                    var updatedState = (try? syncRepository.load(ownerUID: ownerUID)) ?? HealthKitSyncState()
                    updatedState.anchorData = anchorData
                    updatedState.startDate = updatedState.startDate ?? Date()
                    updatedState.lastFetchDate = lastFetch
                    try? syncRepository.save(ownerUID: ownerUID, state: updatedState)
                }
            } catch {
                settings.healthKitSyncEnabled = false
                showHealthKitErrorAlert = true
            }
        }
#else
        settings.healthKitSyncEnabled = false
#endif
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            showSettingsSheet = false
        } catch {
            // Keep user in current session if sign-out fails.
        }
    }

    private func openManageSubscription() {
        guard let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") else { return }
        openURL(url)
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            finalizeAccountRemovalLocally(ownerUID: "local")
            return
        }
        let ownerUID = user.uid

        Task { @MainActor in
            do {
                try await user.delete()
                finalizeAccountRemovalLocally(ownerUID: ownerUID)
            } catch {
                let nsError = error as NSError
                if nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                    deleteAccountErrorMessage = "For security, please log out and sign in again before deleting your account."
                } else {
                    deleteAccountErrorMessage = error.localizedDescription
                }
                showDeleteAccountErrorAlert = true
            }
        }
    }

    private func finalizeAccountRemovalLocally(ownerUID: String) {
        do {
            try Auth.auth().signOut()
        } catch {
            // Ignore sign-out errors here; deleted users are usually signed out automatically.
        }
        store.clearAll()
        settings.hasOnboarded = false
        settings.userEmail = "user@triapp.com"
        settings.healthKitSyncEnabled = false
        let syncRepository = SyncStateRepository(context: modelContext)
        try? syncRepository.clear(ownerUID: ownerUID)
    }
}
