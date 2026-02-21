//
//  OnboardingFlowView.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Security
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingFlowView: View {
    @EnvironmentObject private var settings: UserSettings
    @State private var step = 0
    @State private var maxUnlockedStep = 0
    @State private var minimumAllowedStep = 0
    @State private var dailyGoal = 1000.0
    @State private var swimGoal = 1000.0
    @State private var bikeGoal = 10.0
    @State private var runGoal = 5.0
    @State private var favorite: WorkoutType = .swim
    @State private var hasCompletedSignIn = false
    @State private var healthChoice: Bool?
    @State private var showSkipConfirmation = false
    @State private var authErrorMessage: String?
    @State private var currentNonce: String?

    var body: some View {
        VStack {
            TabView(selection: $step) {
                signInStep
                    .tag(0)
                healthConnectStep
                    .tag(1)
                favoriteStep
                    .tag(2)
                caloriesGoalStep
                    .tag(3)
                weeklyGoalsStep
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.black : Color.black.opacity(0.15))
                        .frame(width: index == step ? 24 : 8, height: 6)
                }
            }
            .padding(.vertical, 10)

            Button {
                advance()
            } label: {
                Text(step == 4 ? "Finish" : "Continue")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(canContinueOnCurrentStep ? Color.black : Color.gray.opacity(0.45))
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
            hasCompletedSignIn = Auth.auth().currentUser != nil
            healthChoice = nil
            step = 0
            maxUnlockedStep = 0
            minimumAllowedStep = 0
        }
        .onChange(of: step) { _, newValue in
            if newValue < minimumAllowedStep {
                step = minimumAllowedStep
                return
            }
            if newValue > maxUnlockedStep {
                step = maxUnlockedStep
            }
        }
        .alert("Skip Apple Health Sync?", isPresented: $showSkipConfirmation) {
            Button("Back", role: .cancel) {}
            Button("Confirm") {
                healthChoice = false
                settings.healthKitSyncEnabled = false
            }
        } message: {
            Text("Smartwatch workouts will not sync to Tri. You can still add workouts manually.")
        }
        .alert("Sign In Failed", isPresented: Binding(
            get: { authErrorMessage != nil },
            set: { if !$0 { authErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authErrorMessage ?? "Please try again.")
        }
    }

    private var signInStep: some View {
        VStack(spacing: 15) {
            Spacer()
            VStack(spacing: 5) {
                Text("Tri")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                Text("Triathletes")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                Text("Swim. Bike. Run. Track your progress.")
                    .font(.system(size: 12, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 14)

            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.email]
                request.nonce = sha256(nonce)
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 40)

            Button {
                signInWithGoogle()
            } label: {
                HStack {
                    Image(systemName: "globe")
                    Text("Sign up with Google")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black)
                )
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 40)
            .disabled(FirebaseApp.app()?.options.clientID == nil)

            Spacer()
        }
    }

    private var healthConnectStep: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 10) {
                Text("Connect Apple Health")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                Text("Tri syncs workouts recorded on Apple Watch")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                Button {
                    healthChoice = true
                    settings.healthKitSyncEnabled = true
                    requestHealthAccess()
                } label: {
                    Text("Connect Apple Health")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(healthChoice == true ? Color.black : Color.white)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        )
                        .foregroundStyle(healthChoice == true ? Color.white : Color.black)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
                .padding(.top, 20)
            }

            Spacer()

            Button {
                showSkipConfirmation = true
            } label: {
                (
                    Text("Skip for now")
                        .foregroundStyle(Color.black)
                    +
                    Text(" (manual entry only)")
                        .foregroundStyle(Color.black.opacity(0.6))
                )
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
    }

    private var favoriteStep: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 4) {
                Text("Pick a favorite")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                Text("Which workout do you love most?")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            HStack(spacing: 16) {
                ForEach(WorkoutType.allCases) { type in
                    Button {
                        favorite = type
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: type.systemImage)
                                .font(.system(size: 26, weight: .semibold))
                            Text(type.rawValue)
                                .font(.system(size: 16, weight: .semibold, design: .serif))
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
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 4) {
                Text("Daily burn goal")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                Text("Set a calories target to keep your streak alive.")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                Text("\(Int(dailyGoal)) cal")
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .contentTransition(.numericText())
                Slider(value: $dailyGoal, in: 200...2500, step: 50)
                    .tint(.black)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var weeklyGoalsStep: some View {
        VStack(spacing: 22) {
            Spacer()
            VStack(spacing: 4) {
                Text("Weekly distance goals")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                Text("Your home rings will track these totals.")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                GoalStepper(label: "Swim (yd)", value: $swimGoal, range: 25...20000, step: 25)
                GoalStepper(label: "Bike (mi)", value: $bikeGoal, range: 1...300, step: 1)
                GoalStepper(label: "Run (mi)", value: $runGoal, range: 1...100, step: 1)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func advance() {
        if step < 4 {
            step += 1
            maxUnlockedStep = max(maxUnlockedStep, step)
            if step >= 2 {
                minimumAllowedStep = 2
            }
            return
        }
        settings.favoriteWorkout = favorite
        settings.dailyCaloriesGoal = dailyGoal
        settings.weeklySwimGoal = swimGoal
        settings.weeklyBikeGoal = bikeGoal
        settings.weeklyRunGoal = runGoal
        settings.hasOnboarded = true
    }

    private var canContinueOnCurrentStep: Bool {
        switch step {
        case 0:
            return hasCompletedSignIn
        case 1:
            return healthChoice != nil
        default:
            return true
        }
    }

    private func requestHealthAccess() {
#if canImport(HealthKit)
        Task { @MainActor in
            do {
                try await HealthKitManager.shared.requestAuthorization()
            } catch {
                settings.healthKitSyncEnabled = false
                healthChoice = false
            }
        }
#endif
    }

    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            authErrorMessage = "Missing Firebase client ID configuration."
            return
        }
        guard let rootViewController = topViewController() else {
            authErrorMessage = "Unable to present Google sign-in."
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        Task { @MainActor in
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
                guard let idToken = result.user.idToken?.tokenString else {
                    authErrorMessage = "Google sign-in did not return an ID token."
                    return
                }
                let credential = GoogleAuthProvider.credential(
                    withIDToken: idToken,
                    accessToken: result.user.accessToken.tokenString
                )
                let authResult = try await Auth.auth().signIn(with: credential)
                settings.userEmail = authResult.user.email ?? settings.userEmail
                hasCompletedSignIn = true
            } catch {
                authErrorMessage = error.localizedDescription
            }
        }
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            authErrorMessage = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                authErrorMessage = "Apple sign-in response is invalid."
                return
            }

            let firebaseCredential = OAuthProvider.credential(
                providerID: .apple,
                idToken: token,
                rawNonce: nonce
            )

            Task { @MainActor in
                do {
                    let authResult = try await Auth.auth().signIn(with: firebaseCredential)
                    if let email = credential.email ?? authResult.user.email {
                        settings.userEmail = email
                    }
                    hasCompletedSignIn = true
                } catch {
                    authErrorMessage = error.localizedDescription
                }
            }
        }
    }

    private func topViewController() -> UIViewController? {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        return deepestPresentedController(from: root)
    }

    private func deepestPresentedController(from root: UIViewController) -> UIViewController {
        var current = root
        while let presented = current.presentedViewController {
            current = presented
        }
        return current
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0..<length {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status == errSecSuccess {
                result.append(charset[Int(random) % charset.count])
            } else {
                result.append("0")
            }
        }
        return result
    }
}

private struct GoalStepper: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    @State private var repeatTimer: Timer?

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
                    .foregroundStyle(Color.black)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.25).onEnded { _ in
                    startRepeating(isIncrement: false)
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0).onEnded { _ in
                    stopRepeating()
                }
            )
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
                    .foregroundStyle(Color.black)
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.25).onEnded { _ in
                    startRepeating(isIncrement: true)
                }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0).onEnded { _ in
                    stopRepeating()
                }
            )
        }
        .onDisappear {
            stopRepeating()
        }
    }

    private func startRepeating(isIncrement: Bool) {
        stopRepeating()
        var ticks = 0
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
            ticks += 1
            let multiplier: Double
            if ticks > 12 {
                multiplier = 4
            } else if ticks > 6 {
                multiplier = 2
            } else {
                multiplier = 1
            }
            let delta = step * multiplier
            if isIncrement {
                value = min(range.upperBound, value + delta)
            } else {
                value = max(range.lowerBound, value - delta)
            }
        }
        RunLoop.main.add(repeatTimer!, forMode: .common)
    }

    private func stopRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = nil
    }
}

struct OnboardingFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFlowView()
            .environmentObject(UserSettings())
            .environmentObject(WorkoutStore())
    }
}
