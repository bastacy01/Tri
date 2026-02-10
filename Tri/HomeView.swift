//
//  HomeView.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var store: WorkoutStore
    @State private var showStreaks = false
    @State private var showGoalSheet: WorkoutType?

    private let calendar = Calendar.current

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                weekRings
                caloriesCard
                workoutCardsRow
                recentWorkoutsSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 120)
            .padding(.top, 16)
        }
        .sheet(isPresented: $showStreaks) {
            StreaksSheet(
                currentStreak: currentStreak,
                longestStreak: longestStreak,
                includedTypes: includedTypes
            )
            .presentationDetents([.height(315)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $showGoalSheet) { type in
            WorkoutGoalSheet(
                type: type,
                progress: weeklyProgress(for: type),
                weeklyGoal: weeklyGoal(for: type),
                weekTotal: store.totalDistance(for: type, inWeekContaining: Date())
            )
            .presentationDetents([.height(315)])
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.black)
                        .frame(width: 40, height: 40)
                    Text("T.")
                        .font(.system(size: 26, weight: .medium, design: .serif))
                        .foregroundStyle(.white)
                }
                Text("Tri")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
            }

            Spacer()

            Button {
                showStreaks = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Color.black)
                    Text("\(currentStreak)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.black)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(.white)
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var weekRings: some View {
        HStack(spacing: 10) {
            ForEach(weekDayRings) { day in
                VStack(spacing: 8) {
                    Text(day.day)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black)
                    ZStack {
                        RingView(progress: day.progress, lineWidth: 3, size: 44, tint: .black, background: Color.black.opacity(0.08))
                        Text(day.date)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.65))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var caloriesCard: some View {
        let todayCalories = store.totalCalories(on: Date())
        let progress = settings.dailyCaloriesGoal == 0 ? 0 : todayCalories / settings.dailyCaloriesGoal
        return HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(todayCalories))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("/\(Int(settings.dailyCaloriesGoal))")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.45))
                }
                Text("Calories Burned")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.5))
            }

            Spacer()

            ZStack {
                RingView(progress: progress, lineWidth: 8, size: 72, tint: .black, background: Color.black.opacity(0.12))
                Image(systemName: "flame.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.black)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white)
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        )
    }

    private var workoutCardsRow: some View {
        HStack(spacing: 14) {
            ForEach(workoutCards) { card in
                WorkoutCardView(card: card) {
                    showGoalSheet = card.type
                }
            }
        }
    }

    private var recentWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Workouts")
                .font(.system(size: 20, weight: .bold, design: .serif))

            ForEach(recentWorkouts) { workout in
                RecentWorkoutRow(workout: workout)
            }
        }
    }

    private var weekDayRings: [DayRing] {
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            let day = formatter.string(from: date)
            let dayNumber = calendar.component(.day, from: date)
            let calories = store.totalCalories(on: date)
            let progress = settings.dailyCaloriesGoal == 0 ? 0 : calories / settings.dailyCaloriesGoal
            return DayRing(day: day, date: "\(dayNumber)", progress: progress)
        }
    }

    private var workoutCards: [WorkoutCard] {
        WorkoutType.allCases.map { type in
            let distance = store.totalDistance(for: type, inWeekContaining: Date())
            let weeklyGoal = weeklyGoal(for: type)
            let progress = weeklyGoal == 0 ? 0 : distance / weeklyGoal
            return WorkoutCard(type: type, distance: "\(formatDistance(distance, type: type))", progress: progress)
        }
    }

    private var recentWorkouts: [RecentWorkout] {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return store.workouts.prefix(3).map {
            RecentWorkout(
                type: $0.type,
                distance: $0.distanceString,
                duration: $0.durationString,
                calories: $0.caloriesString,
                date: formatter.string(from: $0.date)
            )
        }
    }

    private func weeklyGoal(for type: WorkoutType) -> Double {
        switch type {
        case .swim:
            return settings.weeklySwimGoal
        case .bike:
            return settings.weeklyBikeGoal
        case .run:
            return settings.weeklyRunGoal
        }
    }

    private func weeklyProgress(for type: WorkoutType) -> Double {
        let total = store.totalDistance(for: type, inWeekContaining: Date())
        let goal = weeklyGoal(for: type)
        return goal == 0 ? 0 : total / goal
    }

    private var currentStreak: Int {
        streakCounts().current
    }

    private var longestStreak: Int {
        streakCounts().longest
    }

    private func streakCounts() -> (current: Int, longest: Int) {
        let weeks = lastNWeeks(52)
        guard !weeks.isEmpty else { return (0, 0) }

        var longest = 0
        var running = 0
        for weekStart in weeks {
            if isWeekCompleted(weekStart: weekStart) {
                running += 1
                longest = max(longest, running)
            } else {
                running = 0
            }
        }

        var current = 0
        for weekStart in weeks.reversed() {
            if isWeekCompleted(weekStart: weekStart) {
                current += 1
            } else {
                break
            }
        }
        return (current, longest)
    }

    private var includedTypes: [WorkoutType] {
        var result: [WorkoutType] = []
        if settings.streakIncludeSwim { result.append(.swim) }
        if settings.streakIncludeBike { result.append(.bike) }
        if settings.streakIncludeRun { result.append(.run) }
        return result
    }

    private func isWeekCompleted(weekStart: Date) -> Bool {
        let types = includedTypes
        guard !types.isEmpty else { return false }
        for type in types {
            let total = store.totalDistance(for: type, inWeekContaining: weekStart)
            let goal = weeklyGoal(for: type)
            if total < goal {
                return false
            }
        }
        return true
    }

    private func lastNWeeks(_ count: Int) -> [Date] {
        let rawWeeks = (0..<count).compactMap { offset in
            calendar.date(byAdding: .weekOfYear, value: -offset, to: Date())
        }
        let starts = rawWeeks.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start }
        return Array(Set(starts)).sorted()
    }

    private func formatDistance(_ value: Double, type: WorkoutType) -> String {
        let formatted = value >= 100 ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return "\(formatted) \(type.unitLabel)"
    }
}
