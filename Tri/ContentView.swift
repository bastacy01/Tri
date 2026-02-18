//
//  ContentView.swift
//  Tri
//
//  Created by Ben Stacy on 2/8/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = WorkoutStore()
    @StateObject private var settings = UserSettings()
    @State private var selectedTab: Tab = .home
    @State private var showAddWorkout = false

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

            if settings.hasOnboarded {
                mainContent
            } else {
                OnboardingFlowView()
            }
        }
        .environmentObject(store)
        .environmentObject(settings)
        .onAppear {
            store.loadMockData()
            startHealthKitIfEnabled()
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
//            .presentationDetents([.large])
            .presentationDetents([.height(505)])
            .presentationDragIndicator(.visible)
        }
    }

    private func startHealthKitIfEnabled() {
#if canImport(HealthKit)
        guard settings.healthKitSyncEnabled else { return }
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
#endif
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
