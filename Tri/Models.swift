//
//  Models.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import Foundation

enum WorkoutType: String, CaseIterable, Identifiable {
    case swim = "Swim"
    case bike = "Bike"
    case run = "Run"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .swim:
            return "figure.pool.swim"
        case .bike:
            return "figure.outdoor.cycle"
        case .run:
            return "figure.run"
        }
    }

    var unitLabel: String {
        switch self {
        case .swim:
            return "yd"
        case .bike, .run:
            return "mi"
        }
    }
}

struct Workout: Identifiable {
    let id = UUID()
    let type: WorkoutType
    let distance: Double
    let duration: TimeInterval
    let calories: Double
    let date: Date
    let source: WorkoutSource

    var distanceString: String {
        let value = distance >= 100 ? String(format: "%.0f", distance) : String(format: "%.1f", distance)
        return "\(value) \(type.unitLabel)"
    }

    var durationString: String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var caloriesString: String {
        let value = calories >= 1000 ? String(format: "%.0f", calories) : String(format: "%.0f", calories)
        return value
    }
}

enum WorkoutSource: String {
    case healthKit
    case manual
}

struct DayRing: Identifiable {
    let id = UUID()
    let day: String
    let date: String
    let progress: Double
}

struct WorkoutCard: Identifiable {
    let id = UUID()
    let type: WorkoutType
    let distance: String
    let progress: Double
}

struct RecentWorkout: Identifiable {
    let id = UUID()
    let type: WorkoutType
    let distance: String
    let duration: String
    let calories: String
    let date: String
}

struct GoalSnapshot {
    let caloriesGoal: Double
    let weeklySwimGoal: Double
    let weeklyBikeGoal: Double
    let weeklyRunGoal: Double
}
