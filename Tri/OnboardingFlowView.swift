//
//  OnboardingFlowView.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI
import AuthenticationServices

struct OnboardingFlowView: View {
    @EnvironmentObject private var settings: UserSettings
    @State private var step = 0
    @State private var dailyGoal = 1000.0
    @State private var swimGoal = 5000.0
    @State private var bikeGoal = 60.0
    @State private var runGoal = 12.0
    @State private var favorite: WorkoutType = .swim

    var body: some View {
        VStack {
            TabView(selection: $step) {
                signInStep
                    .tag(0)
                favoriteStep
                    .tag(1)
                caloriesGoalStep
                    .tag(2)
                weeklyGoalsStep
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.black : Color.black.opacity(0.15))
                        .frame(width: index == step ? 24 : 8, height: 6)
                }
            }
            .padding(.vertical, 10)

            Button {
                advance()
            } label: {
                Text(step == 3 ? "Finish" : "Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black)
                    )
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .onAppear {
            dailyGoal = settings.dailyCaloriesGoal
            swimGoal = settings.weeklySwimGoal
            bikeGoal = settings.weeklyBikeGoal
            runGoal = settings.weeklyRunGoal
            favorite = settings.favoriteWorkout
        }
    }

    private var signInStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Welcome to Tri")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Sign in to sync workouts and personalize your goals.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            SignInWithAppleButton(.signIn) { _ in
                // Placeholder for Apple sign-in.
            } onCompletion: { _ in
                // Placeholder for Apple sign-in.
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .padding(.horizontal, 40)

            Button {
                // Placeholder for Google sign-in.
            } label: {
                HStack {
                    Image(systemName: "globe")
                    Text("Continue with Google")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.15), lineWidth: 1)
                )
            }
            .foregroundStyle(Color.black)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var favoriteStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Pick a favorite")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("Just for fun, which workout do you love most?")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            HStack(spacing: 16) {
                ForEach(WorkoutType.allCases) { type in
                    Button {
                        favorite = type
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: type.systemImage)
                                .font(.system(size: 26, weight: .semibold))
                            Text(type.rawValue)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(width: 92, height: 110)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(favorite == type ? Color.black : Color.white)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        )
                        .foregroundStyle(favorite == type ? .white : .black)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
    }

    private var caloriesGoalStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("Daily burn goal")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("Set a calories target to keep your streak alive.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                Text("\(Int(dailyGoal)) cal")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Slider(value: $dailyGoal, in: 200...2500, step: 50)
                    .tint(.black)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var weeklyGoalsStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Weekly distance goals")
                .font(.system(size: 26, weight: .bold, design: .rounded))
            Text("Your home rings will track these totals.")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(spacing: 12) {
                GoalStepper(label: "Swim (yd)", value: $swimGoal, range: 500...20000, step: 25)
                GoalStepper(label: "Bike (mi)", value: $bikeGoal, range: 5...300, step: 5)
                GoalStepper(label: "Run (mi)", value: $runGoal, range: 2...100, step: 1)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func advance() {
        if step < 3 {
            step += 1
            return
        }
        settings.favoriteWorkout = favorite
        settings.dailyCaloriesGoal = dailyGoal
        settings.weeklySwimGoal = swimGoal
        settings.weeklyBikeGoal = bikeGoal
        settings.weeklyRunGoal = runGoal
        settings.hasOnboarded = true
    }
}

private struct GoalStepper: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            Button {
                value = max(range.lowerBound, value - step)
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
            }
            Text("\(Int(value))")
                .font(.system(size: 16, weight: .bold))
                .contentTransition(.numericText())
                .frame(width: 60)
            Button {
                value = min(range.upperBound, value + step)
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
            }
        }
    }
}
