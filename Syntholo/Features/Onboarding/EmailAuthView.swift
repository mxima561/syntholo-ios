import SwiftUI

/// Which side of the email flow this sheet is presenting. Creating an account
/// and signing back in share a layout, so they share a view rather than
/// drifting apart as two near-copies.
enum EmailAuthMode: Equatable {
    case createAccount
    case signIn

    var title: LocalizedStringKey {
        switch self {
        case .createAccount: "Create your account"
        case .signIn: "Welcome back"
        }
    }

    var introduction: LocalizedStringKey {
        switch self {
        case .createAccount:
            "Use your email to save your route and progress."
        case .signIn:
            "Sign in to pick up where you left off."
        }
    }

    var navigationTitle: LocalizedStringKey {
        switch self {
        case .createAccount: "Email account"
        case .signIn: "Sign in"
        }
    }

    var submitTitle: LocalizedStringResource {
        switch self {
        case .createAccount: "Create account"
        case .signIn: "Sign in"
        }
    }

    var submittingTitle: LocalizedStringResource {
        switch self {
        case .createAccount: "Creating account…"
        case .signIn: "Signing in…"
        }
    }

    var eyebrow: LocalizedStringKey {
        switch self {
        case .createAccount: "ACCOUNT"
        case .signIn: "SIGN IN"
        }
    }
}

struct EmailAuthView: View {
    let mode: EmailAuthMode
    let authClient: any AuthClient
    let onAuthenticated: @MainActor (AuthenticatedUser) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var isSendingReset = false
    @State private var didSendReset = false
    @State private var error: AuthError?

    init(
        mode: EmailAuthMode = .createAccount,
        authClient: any AuthClient,
        onAuthenticated: @escaping @MainActor (AuthenticatedUser) -> Void
    ) {
        self.mode = mode
        self.authClient = authClient
        self.onAuthenticated = onAuthenticated
    }

    private enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            OnboardingPage(
                eyebrow: mode.eyebrow,
                progress: nil,
                title: mode.title,
                introduction: mode.introduction,
                accessibilityIdentifier: "onboarding.email-auth"
            ) {
                VStack(alignment: .leading, spacing: Space.md) {
                    labeledField("Email address") {
                        TextField("Email address", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                    }

                    labeledField("Password") {
                        SecureField("Password", text: $password)
                            .textContentType(
                                mode == .createAccount
                                    ? .newPassword
                                    : .password
                            )
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(submit)
                    }

                    if mode == .createAccount {
                        Text("Use at least 8 characters.")
                            .font(.footnote)
                            .foregroundStyle(
                                OnboardingPalette.academicInk.opacity(0.76)
                            )
                    }

                    if let error, error.shouldPresentMessage {
                        notice(
                            Text(error.message),
                            systemImage: "exclamationmark.circle",
                            tint: OnboardingPalette.correctionCoral
                        )
                        .accessibilityIdentifier("email-auth.error")
                    }

                    if didSendReset {
                        notice(
                            Text(
                                "If that email has an account, a reset link is on its way."
                            ),
                            systemImage: "envelope.badge",
                            tint: OnboardingPalette.academicInk
                        )
                        .accessibilityIdentifier("email-auth.reset-sent")
                    }

                    PrimaryButton(
                        title: isSubmitting
                            ? mode.submittingTitle
                            : mode.submitTitle,
                        action: submit,
                        isEnabled: !isSubmitting
                    )
                    .accessibilityIdentifier("email-auth.submit")

                    if mode == .signIn {
                        Button(
                            isSendingReset
                                ? "Sending reset link…"
                                : "Forgot password?",
                            action: sendPasswordReset
                        )
                        .font(.body.weight(.semibold))
                        .foregroundStyle(OnboardingPalette.lectureBlue)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .disabled(isSendingReset || isSubmitting)
                        .accessibilityIdentifier("email-auth.forgot-password")
                    }
                }
            }
            .navigationTitle(mode.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Cancel")
                }
            }
        }
        .tint(OnboardingPalette.lectureBlue)
        .preferredColorScheme(.light)
    }

    private func notice(
        _ text: Text,
        systemImage: String,
        tint: Color
    ) -> some View {
        Label {
            text.fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(tint)
    }

    private func labeledField<Content: View>(
        _ label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Text(label)
                .font(.body.weight(.semibold))
                .foregroundStyle(OnboardingPalette.academicInk)

            content()
                .padding(.horizontal, 14)
                .frame(minHeight: Layout.minimumControlHeight)
                .background(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            OnboardingPalette.academicInk.opacity(0.34),
                            lineWidth: 1
                        )
                }
        }
    }

    private func submit() {
        guard !isSubmitting else {
            return
        }

        isSubmitting = true
        error = nil
        didSendReset = false
        Task { @MainActor in
            do {
                let user = switch mode {
                case .createAccount:
                    try await authClient.createEmailAccount(
                        email: email,
                        password: password
                    )
                case .signIn:
                    try await authClient.signInWithEmail(
                        email: email,
                        password: password
                    )
                }
                isSubmitting = false
                onAuthenticated(user)
            } catch {
                isSubmitting = false
                let mappedError = AuthError.map(error)
                self.error = mappedError.shouldPresentMessage
                    ? mappedError
                    : nil
            }
        }
    }

    private func sendPasswordReset() {
        guard !isSendingReset, !isSubmitting else {
            return
        }

        isSendingReset = true
        error = nil
        didSendReset = false
        Task { @MainActor in
            defer { isSendingReset = false }
            do {
                try await authClient.sendPasswordReset(email: email)
                // Deliberately unconditional: the client swallows "no such
                // user" so this confirmation cannot confirm an address exists.
                didSendReset = true
            } catch {
                let mappedError = AuthError.map(error)
                self.error = mappedError.shouldPresentMessage
                    ? mappedError
                    : nil
            }
        }
    }
}
