import SwiftUI
import UIKit

struct AccountCreationView: View {
    let onAuthenticated: @MainActor (
        AuthenticatedUser,
        AuthenticationProvider
    ) -> Void
    let onContinueWithEmail: () -> Void

    @State private var appleCoordinator: AppleSignInCoordinator
    @State private var googleCoordinator: GoogleSignInCoordinator
    @State private var providerError: AuthError?
    @State private var isGoogleSignInRunning = false

    #if DEBUG
    private let uiTestAuthClient: (any AuthClient)?
    @State private var uiTestProviderAttemptMarker: String?
    #endif

    init(
        authClient: any AuthClient,
        googleConfiguration: GoogleSignInConfiguration = .current,
        onAuthenticated: @escaping @MainActor (
            AuthenticatedUser,
            AuthenticationProvider
        ) -> Void,
        onContinueWithEmail: @escaping () -> Void
    ) {
        self.onAuthenticated = onAuthenticated
        self.onContinueWithEmail = onContinueWithEmail
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        uiTestAuthClient = arguments.contains("--ui-testing")
            && (arguments.contains("--provider-fixture=success")
                || arguments.contains("--provider-fixture=cancelled"))
            ? authClient
            : nil
        #endif
        _appleCoordinator = State(
            initialValue: AppleSignInCoordinator(authClient: authClient)
        )
        _googleCoordinator = State(
            initialValue: GoogleSignInCoordinator(
                authClient: authClient,
                configuration: googleConfiguration
            )
        )
    }

    @ViewBuilder
    var body: some View {
        #if DEBUG
        if let uiTestProviderAttemptMarker {
            accountPage.accessibilityValue(uiTestProviderAttemptMarker)
        } else {
            accountPage
        }
        #else
        accountPage
        #endif
    }

    private var accountPage: some View {
        OnboardingPage(
            eyebrow: "Orientation · 6/6",
            progress: 6,
            title: "Save your learning route",
            introduction: "Create an account to keep your route and lesson progress.",
            accessibilityIdentifier: "onboarding.account"
        ) {
            VStack(spacing: Space.sm) {
                #if DEBUG
                if uiTestAuthClient != nil {
                    providerButton(
                        title: "Continue with Apple",
                        systemImage: "apple.logo",
                        action: { continueWithUITestProvider(.apple) }
                    )
                    .accessibilityIdentifier("onboarding.auth.apple.fixture")
                } else {
                    appleAuthenticationButton
                }
                #else
                appleAuthenticationButton
                #endif

                #if DEBUG
                if uiTestAuthClient != nil {
                    providerButton(
                        title: "Continue with Google",
                        systemImage: nil,
                        action: { continueWithUITestProvider(.google) },
                        isEnabled: !isGoogleSignInRunning
                    )
                } else {
                    googleAuthenticationButton
                }
                #else
                googleAuthenticationButton
                #endif

                providerButton(
                    title: "Continue with email",
                    systemImage: "envelope",
                    action: onContinueWithEmail
                )

                if let providerError, providerError.shouldPresentMessage {
                    Label {
                        Text(
                            LocalizedStringKey(providerError.localizationKey)
                        )
                        .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.circle")
                            .accessibilityHidden(true)
                    }
                    .font(.footnote)
                    .foregroundStyle(OnboardingPalette.correctionCoral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("onboarding.auth.error")
                }
            }

            Text("Your account stores your learning choices and progress.")
                .font(.footnote)
                .foregroundStyle(OnboardingPalette.academicInk.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var appleAuthenticationButton: some View {
        AppleAuthenticationButton(
            coordinator: appleCoordinator,
            onCompletion: { result in
                handleProviderCompletion(result, provider: .apple)
            }
        )
        .accessibilityLabel("Continue with Apple")
        .accessibilityIdentifier("onboarding.auth.apple.native")
    }

    private var googleAuthenticationButton: some View {
        providerButton(
            title: "Continue with Google",
            systemImage: nil,
            action: continueWithGoogle,
            isEnabled: !isGoogleSignInRunning
        )
    }

    private func providerButton(
        title: LocalizedStringKey,
        systemImage: String?,
        action: @escaping () -> Void,
        isEnabled: Bool = true
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Space.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                } else {
                    Color.clear
                        .frame(width: 24, height: 1)
                        .accessibilityHidden(true)
                }

                Text(title)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)

                Color.clear
                    .frame(width: 24, height: 1)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(OnboardingPalette.academicInk)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: Layout.minimumControlHeight)
            .background(OnboardingPalette.campusPaper)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(OnboardingPalette.academicInk.opacity(0.42), lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
    }

    private func continueWithGoogle() {
        guard !isGoogleSignInRunning else {
            return
        }

        providerError = nil
        isGoogleSignInRunning = true
        Task { @MainActor in
            defer { isGoogleSignInRunning = false }

            do {
                guard let viewController = presentingViewController else {
                    throw AuthError.providerUnavailable
                }
                let user = try await googleCoordinator.signIn(
                    presenting: viewController
                )
                handleProviderCompletion(.success(user), provider: .google)
            } catch {
                handleProviderCompletion(
                    .failure(AuthError.map(error)),
                    provider: .google
                )
            }
        }
    }

    #if DEBUG
    private func continueWithUITestProvider(
        _ provider: AuthenticationProvider
    ) {
        guard let uiTestAuthClient, !isGoogleSignInRunning else {
            return
        }

        providerError = nil
        isGoogleSignInRunning = true
        Task { @MainActor in
            defer { isGoogleSignInRunning = false }

            do {
                let user = switch provider {
                case .apple:
                    try await uiTestAuthClient.signInWithApple(
                        idToken: "ui-test-token",
                        rawNonce: "ui-test-nonce",
                        fullName: nil
                    )
                case .google:
                    try await uiTestAuthClient.signInWithGoogle(
                        idToken: "ui-test-token",
                        accessToken: "ui-test-access-token"
                    )
                case .password:
                    try await uiTestAuthClient.createEmailAccount(
                        email: "ui-test@example.invalid",
                        password: "ui-test-password"
                    )
                }
                handleProviderCompletion(.success(user), provider: provider)
            } catch {
                let authError = AuthError.map(error)
                if authError == .cancelled {
                    uiTestProviderAttemptMarker = "\(provider.rawValue):cancelled"
                }
                handleProviderCompletion(
                    .failure(authError),
                    provider: provider
                )
            }
        }
    }
    #endif

    private func handleProviderCompletion(
        _ result: Result<AuthenticatedUser, AuthError>,
        provider: AuthenticationProvider
    ) {
        switch result {
        case let .success(user):
            providerError = nil
            onAuthenticated(user, provider)
        case let .failure(error):
            providerError = error.shouldPresentMessage ? error : nil
        }
    }

    private var presentingViewController: UIViewController? {
        let rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController

        var presentedViewController = rootViewController
        while let next = presentedViewController?.presentedViewController {
            presentedViewController = next
        }
        return presentedViewController
    }
}
