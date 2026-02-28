//
//  ContentView.swift
//  Tri
//
//  Created by Ben Stacy on 2/8/26.
//

import SwiftUI
import FirebaseAuth
import SwiftData
import StoreKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = WorkoutStore()
    @StateObject private var settings = UserSettings()
    @State private var selectedTab: Tab = .home
    @State private var showAddWorkout = false
    @State private var isAuthenticated = Auth.auth().currentUser != nil
    @State private var authStateHandle: AuthStateDidChangeListenerHandle?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(white: 0.98),
                    Color(white: 0.96),
                    Color(white: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if settings.hasOnboarded && settings.hasActiveSubscription && isAuthenticated {
                mainContent
            } else {
                OnboardingFlowView()
            }
        }
        .environmentObject(store)
        .environmentObject(settings)
        .onAppear {
            if !store.isRepositoryConfigured {
                store.configureRepository(SwiftDataWorkoutRepository(context: modelContext))
            }
            settings.configureRepository(context: modelContext)
            syncSubscriptionStateFromEntitlements()
            startHealthKitIfEnabled()
            if authStateHandle == nil {
                authStateHandle = Auth.auth().addStateDidChangeListener { _, user in
                    isAuthenticated = (user != nil)
                    selectedTab = .home
                    if let email = user?.email {
                        settings.userEmail = email
                    }
                    settings.reloadFromStorage(ownerUID: user?.uid)
                    syncSubscriptionStateFromEntitlements()
                    store.reloadFromStorage()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                selectedTab = .home
                syncSubscriptionStateFromEntitlements()
            }
        }
    }

    private var mainContent: some View {
        ZStack {
            switch selectedTab {
            case .home:
                HomeView()
            case .calendar:
                CalendarView()
            case .statistics:
                StatisticsView()
            case .profile:
                ProfileView()
            }
        }
        .overlay(alignment: .bottom) {
            LiquidTabBar(selectedTab: $selectedTab, showAddWorkout: $showAddWorkout)
        }
        .sheet(isPresented: $showAddWorkout) {
            AddWorkoutSheet { workout in
                store.addManualWorkout(workout)
            }
            .presentationDetents([.large])
//            .presentationDetents([.height(505)])
            .presentationDragIndicator(.visible)
        }
    }

    private func startHealthKitIfEnabled() {
#if canImport(HealthKit)
        guard settings.healthKitSyncEnabled else { return }
        let ownerUID = Auth.auth().currentUser?.uid ?? "local"
        let syncRepository = SyncStateRepository(context: modelContext)
        Task { @MainActor in
            do {
                try await HealthKitManager.shared.requestAuthorization()
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
            }
        }
#endif
    }

    private func syncSubscriptionStateFromEntitlements() {
        guard isAuthenticated else { return }
        Task { @MainActor in
            var activeProductID: String?
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else { continue }
                if transaction.productID == "pro_monthly" || transaction.productID == "pro_yearly" {
                    activeProductID = transaction.productID
                    break
                }
            }
            settings.hasActiveSubscription = (activeProductID != nil)
            settings.subscriptionProductID = activeProductID
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
