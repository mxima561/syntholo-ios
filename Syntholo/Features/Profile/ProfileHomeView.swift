import SwiftUI

/// Profile is still mostly a placeholder, but sign-out has to exist: without
/// it a tester cannot reach the sign-in flow again without deleting the app.
struct ProfileHomeView: View {
    let coordinator: OnboardingCoordinator

    @State private var email: String?
    @State private var isSigningOut = false
    @State private var signOutError: AuthError?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Signed in as") {
                        Text(email ?? "—")
                            .foregroundStyle(SyntholoColor.ink)
                    }
                    .accessibilityIdentifier("profile.account-email")
                } header: {
                    sectionHeader("Account")
                }

                Section {
                    Button {
                        signOut()
                    } label: {
                        HStack {
                            Text(isSigningOut ? "Signing out…" : "Sign out")
                                .foregroundStyle(SyntholoColor.destructive)
                            if isSigningOut {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSigningOut)
                    .accessibilityIdentifier("profile.sign-out")
                } footer: {
                    if let signOutError, signOutError.shouldPresentMessage {
                        Text(signOutError.message)
                            .foregroundStyle(SyntholoColor.destructive)
                            .accessibilityIdentifier("profile.sign-out-error")
                    } else {
                        Text("You'll keep your saved progress and can sign back in with the same account.")
                            .foregroundStyle(SyntholoColor.ink)
                    }
                }

                Section {
                    Text("Preferences, downloads, and account management arrive in a later slice.")
                        .foregroundStyle(SyntholoColor.ink)
                } header: {
                    sectionHeader("Coming soon")
                }
            }
            .navigationTitle("Profile")
        }
        .task {
            email = await coordinator.currentAccountEmail()
        }
    }

    // SwiftUI's default section header is a light gray that only "nearly
    // passes" the contrast audit on the grouped background.
    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(SyntholoColor.ink)
    }

    private func signOut() {
        guard !isSigningOut else {
            return
        }

        isSigningOut = true
        signOutError = nil
        Task { @MainActor in
            defer { isSigningOut = false }
            do {
                try await coordinator.signOut()
            } catch {
                // Stay on Profile: the account is still signed in.
                signOutError = AuthError.map(error)
            }
        }
    }
}
