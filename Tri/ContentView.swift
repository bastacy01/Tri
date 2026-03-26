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
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = WorkoutStore()
    @StateObject private var settings = UserSettings()
    @State private var selectedTab: Tab = .home
    @State private var showAddWorkout = false
    @State private var pendingManualWorkout: Workout?
    @State private var isAuthenticated = Auth.auth().currentUser != nil
    @State private var authStateHandle: AuthStateDidChangeListenerHandle?
    @State private var isAuthTransitioning = false
    private let useNativeTabBarForTesting = true

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

            if isAuthTransitioning {
                ProgressView()
            } else if settings.hasOnboarded && settings.hasActiveSubscription && isAuthenticated {
                mainContent
                    .onAppear {
                        print("[Tri] Showing Home. onboarded=\(settings.hasOnboarded) active=\(settings.hasActiveSubscription) auth=\(isAuthenticated)")
                    }
            } else {
                OnboardingFlowView()
                    .onAppear {
                        print("[Tri] Showing Onboarding. onboarded=\(settings.hasOnboarded) active=\(settings.hasActiveSubscription) auth=\(isAuthenticated)")
                    }
            }
        }
        .environmentObject(store)
        .environmentObject(settings)
        .onAppear {
            if !store.isRepositoryConfigured {
                store.configureRepository(SwiftDataWorkoutRepository(context: modelContext))
            }
            store.updateOwnerUID(resolvedOwnerUID(Auth.auth().currentUser?.uid))
            settings.configureRepository(context: modelContext)
            configureNativeTabBarAppearance()
            syncSubscriptionStateFromEntitlements()
            startHealthKitIfEnabled()
            if authStateHandle == nil {
                authStateHandle = Auth.auth().addStateDidChangeListener { _, user in
                    let wasAuthenticated = isAuthenticated
                    isAuthenticated = (user != nil)
                    print("[Tri] Auth state changed. isAuthenticated=\(isAuthenticated) uid=\(user?.uid ?? "nil")")
                    if !wasAuthenticated && isAuthenticated {
                        isAuthTransitioning = true
                    }
                    selectedTab = .home
                    let ownerUID = resolvedOwnerUID(user?.uid)
                    store.updateOwnerUID(ownerUID)
                    if let email = user?.email {
                        settings.userEmail = email
                    }
                    settings.reloadFromStorage(ownerUID: ownerUID)
                    print("[Tri] Reloaded settings. hasOnboarded=\(settings.hasOnboarded) hasActiveSubscription=\(settings.hasActiveSubscription)")
                    syncSubscriptionStateFromEntitlements()
                    if isAuthenticated {
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            isAuthTransitioning = false
                        }
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                selectedTab = .home
                syncSubscriptionStateFromEntitlements()
            }
        }
        .alert(
            "Workout Persistence Error",
            isPresented: Binding(
                get: { store.lastPersistenceError != nil },
                set: { isPresented in
                    if !isPresented {
                        store.clearPersistenceError()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                store.clearPersistenceError()
            }
        } message: {
            Text(store.lastPersistenceError ?? "Unknown persistence error.")
        }
    }

    private var mainContent: some View {
        Group {
            if useNativeTabBarForTesting {
                nativeTabMainContent
            } else {
                customTabMainContent
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if selectedTab == .home {
                addWorkoutOverlayButton
            }
        }
    }

    private var customTabMainContent: some View {
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
        .sheet(isPresented: $showAddWorkout, onDismiss: addPendingManualWorkoutIfNeeded) {
            AddWorkoutSheet { workout in
                pendingManualWorkout = workout
            }
            .presentationDetents([.large])
//            .presentationDetents([.height(505)])
            .presentationDragIndicator(.visible)
        }
    }

    private var nativeTabMainContent: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(Tab.home)
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.systemImage)
                }
                .background(Color(white: 0.97).ignoresSafeArea())

            CalendarView()
                .tag(Tab.calendar)
                .tabItem {
                    Label(Tab.calendar.rawValue, systemImage: Tab.calendar.systemImage)
                }

            StatisticsView()
                .tag(Tab.statistics)
                .tabItem {
                    Label(Tab.statistics.rawValue, systemImage: Tab.statistics.systemImage)
                }

            ProfileView()
                .tag(Tab.profile)
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.systemImage)
                }
        }
        .tint(.black)
        .toolbarBackground(Color(white: 0.97), for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .sheet(isPresented: $showAddWorkout, onDismiss: addPendingManualWorkoutIfNeeded) {
            AddWorkoutSheet { workout in
                pendingManualWorkout = workout
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func addPendingManualWorkoutIfNeeded() {
        guard let workout = pendingManualWorkout else { return }
        pendingManualWorkout = nil
        store.addManualWorkout(workout)
    }

    private var addWorkoutOverlayButton: some View {
        Button {
            showAddWorkout = true
        } label: {
            ZStack {
                nativeAddButtonBackground
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.black)
            }
            .frame(width: 58, height: 58)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, useNativeTabBarForTesting ? 20 : 16)
        .padding(.bottom, useNativeTabBarForTesting ? 66 : 12)
        .offset(x: useNativeTabBarForTesting ? 0 : -6, y: useNativeTabBarForTesting ? 0 : -54)
        .zIndex(2)
    }

    private func startHealthKitIfEnabled() {
#if canImport(HealthKit)
        guard settings.healthKitSyncEnabled else { return }
        let ownerUID = resolvedOwnerUID(Auth.auth().currentUser?.uid)
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

    private func resolvedOwnerUID(_ uid: String?) -> String {
        guard let uid else { return "local" }
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = trimmed.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        return allowed.isEmpty ? "local" : allowed
    }

    private func syncSubscriptionStateFromEntitlements() {
        guard isAuthenticated else { return }
        print("[Tri] Syncing subscriptions from entitlements...")
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
            if settings.hasActiveSubscription && !settings.hasOnboarded {
                settings.hasOnboarded = true
            }
            print("[Tri] Entitlement sync done. activeProductID=\(activeProductID ?? "nil") hasActiveSubscription=\(settings.hasActiveSubscription)")
        }
    }

    private func configureNativeTabBarAppearance() {
#if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.97, alpha: 1.0)
        let layouts = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]
        for layout in layouts {
            layout.normal.iconColor = .black
            layout.normal.titleTextAttributes = [.foregroundColor: UIColor.black]
            layout.selected.iconColor = .black
            layout.selected.titleTextAttributes = [.foregroundColor: UIColor.black]
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = .black
#endif
    }

    @ViewBuilder
    private var nativeAddButtonBackground: some View {
        if #available(iOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect()
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 5)
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.7), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 5)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
