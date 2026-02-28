//
//  OnboardingFlowView.swift
//  Tri
//
//  Created by Codex on 2/8/26.
//

import SwiftUI
import AuthenticationServices
import CryptoKit
import StoreKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Security
#if canImport(UIKit)
import UIKit
#endif

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var settings: UserSettings
    @EnvironmentObject private var store: WorkoutStore
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
    @State private var showDeleteAccountConfirm = false
    @State private var showDeleteAccountErrorAlert = false
    @State private var deleteAccountErrorMessage = "Unable to delete your account right now."
    @State private var authErrorMessage: String?
    @State private var currentNonce: String?
    @State private var isCompactPaywall = false
    private var isReauthOnly: Bool { settings.hasOnboarded && settings.hasActiveSubscription }
    private var requiresPaywallAfterSignIn: Bool { settings.hasOnboarded && !settings.hasActiveSubscription }
    private var showPaywallOnlyScreen: Bool { requiresPaywallAfterSignIn && hasCompletedSignIn }

    var body: some View {
        VStack {
            if showPaywallOnlyScreen {
                paywallScreen
            } else {
                TabView(selection: $step) {
                    signInStep
                        .tag(0)
                    if !isReauthOnly {
                        healthConnectStep
                            .tag(1)
                        favoriteStep
                            .tag(2)
                        caloriesGoalStep
                            .tag(3)
                        weeklyGoalsStep
                            .tag(4)
                        paywallStep
                            .tag(5)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                if !isReauthOnly {
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { index in
                            Capsule()
                                .fill(index == step ? Color.black : Color.black.opacity(0.15))
                                .frame(width: index == step ? 24 : 8, height: 6)
                        }
                    }
                    .padding(.vertical, 10)
                }

                if !isReauthOnly && step < 5 {
                    Button {
                        advance()
                    } label: {
                        Text("Continue")
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
            }
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
            if requiresPaywallAfterSignIn {
                if newValue != 0 {
                    step = 0
                }
                return
            }
            if isReauthOnly {
                if newValue != 0 {
                    step = 0
                }
                return
            }
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
                HStack(spacing: 8) {
                    Image("googleIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 13, height: 13)
                        .offset(x: 10)
                    Text("Sign in with Google")
                        .font(.system(size: 19, weight: .medium))
                        .offset(x: 7)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black)
                )
            }
            .foregroundStyle(Color.white)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .foregroundStyle(Color.black)
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
        VStack(spacing: 26) {
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
        VStack(spacing: 26) {
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
        VStack(spacing: 24) {
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
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private var paywallStep: some View {
        paywallScreen
    }

    private var paywallScreen: some View {
        PaywallView(isCompact: isCompactPaywall, ids: Self.productIDs, points: Self.points) {
            paywallHeaderView
        } links: {
            paywallLinksView
        } loadingView: {
            ProgressView()
        }
        .tint(Color.primary)
        .interactiveDismissDisabled()
        .onInAppPurchaseStart { product in
            print("Purchasing \(product.displayName)")
        }
        .onInAppPurchaseCompletion { product, result in
            handlePurchaseCompletion(productID: product.id, result: result)
        }
        .subscriptionStatusTask(for: Self.subscriptionGroupID) { _ in
            // Add your App Store subscription group ID in `subscriptionGroupID`.
        }
    }

    @ViewBuilder
    private var paywallHeaderView: some View {
        VStack(spacing: 15)  {
            VStack(alignment: .leading, spacing: 0) {
                Text("Tri")
                    .font(.title.bold())

                Text("Triathletes")
                    .font(.caption.bold())
                    .foregroundStyle(.background)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.primary, in: .capsule)
//                    .offset(x: 5)
            }
            .lineLimit(1)
            .padding(.top, 10)
            
            ZStack {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 100, height: 100)
                Text("T.")
                    .font(.system(size: 65, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 25)
//            Image(systemName: "flame.fill")
//                .font(.system(size: 60))
//                .foregroundStyle(.background)
//                .frame(width: 100, height: 100)
//                .background(Color.primary, in: .rect(cornerRadius: 25))
//                .padding(.vertical, 25)
        }
    }

    @ViewBuilder
    private var paywallLinksView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 5) {
                Link("Terms of Service", destination: URL(string: "https://example.com/terms")!)

                Text("&")

                Link("Privacy Policy", destination: URL(string: "https://example.com/privacy-policy")!)
                Text("&")
                Button("Delete Account") {
                    showDeleteAccountConfirm = true
                }
                .foregroundStyle(.red)
            }
            .font(.caption)
            .foregroundStyle(.gray)
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
        guard step == 4 else { return }
        settings.favoriteWorkout = favorite
        settings.dailyCaloriesGoal = dailyGoal
        settings.weeklySwimGoal = swimGoal
        settings.weeklyBikeGoal = bikeGoal
        settings.weeklyRunGoal = runGoal
        step = 5
        maxUnlockedStep = max(maxUnlockedStep, 5)
    }

    private var canContinueOnCurrentStep: Bool {
        switch step {
        case 0:
            return hasCompletedSignIn
        case 1:
            return healthChoice != nil
        case 5:
            return false
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

    private func handlePurchaseCompletion(productID: String, result: Result<Product.PurchaseResult, Error>) {
        switch result {
        case .success(let purchaseResult):
            switch purchaseResult {
            case .success(let verification):
                switch verification {
                case .verified:
                    unlockSubscribedUser(subscriptionProductID: productID)
                case .unverified:
                    break
                }
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        case .failure:
            break
        }
    }

    private func unlockSubscribedUser(subscriptionProductID: String? = nil) {
        settings.hasActiveSubscription = true
        if let subscriptionProductID {
            settings.subscriptionProductID = subscriptionProductID
        }
        settings.hasOnboarded = true
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
                    deleteAccountErrorMessage = "For security, please sign in again before deleting your account."
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
            // Ignore sign-out failures for deleted users.
        }
        store.clearAll()
        settings.hasOnboarded = false
        settings.hasActiveSubscription = false
        settings.subscriptionProductID = nil
        settings.userEmail = "user@triapp.com"
        settings.healthKitSyncEnabled = false
        let syncRepository = SyncStateRepository(context: modelContext)
        try? syncRepository.clear(ownerUID: ownerUID)
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

    private static let subscriptionGroupID = "DFAC819C"

    /// Your IAP IDs
    private static let productIDs: [String] = [
        "pro_monthly",
        "pro_yearly"
    ]

    /// Your IAP points
    private static let points: [PaywallPoint] = [
        .init(symbol: "figure.pool.swim", content: "Swim"),
        .init(symbol: "figure.outdoor.cycle", content: "Bike"),
        .init(symbol: "figure.run", content: "Run"),
        .init(symbol: "chart.line.uptrend.xyaxis", content: "Track your progress")
    ]
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
