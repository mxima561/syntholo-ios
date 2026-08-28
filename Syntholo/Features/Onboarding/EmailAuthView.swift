import SwiftUI

struct EmailAuthView: View {
    let authClient: any AuthClient
    let onAuthenticated: @MainActor (AuthenticatedUser) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var error: AuthError?

    private enum Field {
        case email
        case password
    }

    var body: some View {
        NavigationStack {
            OnboardingPage(
                eyebrow: "Account",
                progress: nil,
                title: "Create your account",
                introduction: "Use your email to save your route and progress.",
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
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit(submit)
                    }

                    Text("Use at least 8 characters.")
                        .font(.footnote)
                        .foregroundStyle(
                            OnboardingPalette.academicInk.opacity(0.76)
                        )

                    if let error, error.shouldPresentMessage {
                        Label {
                            Text(LocalizedStringKey(error.localizationKey))
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.circle")
                                .accessibilityHidden(true)
                        }
                        .font(.footnote)
                        .foregroundStyle(OnboardingPalette.correctionCoral)
                        .accessibilityIdentifier("email-auth.error")
                    }

                    PrimaryButton(
                        title: isSubmitting
                            ? "Creating account…"
                            : "Create account",
                        action: submit,
                        isEnabled: !isSubmitting
                    )
                    .accessibilityIdentifier("email-auth.submit")
                }
            }
            .navigationTitle("Email account")
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
        Task { @MainActor in
            do {
                let user = try await authClient.createEmailAccount(
                    email: email,
                    password: password
                )
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
}
