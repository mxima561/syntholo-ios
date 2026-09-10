import SwiftUI

struct WelcomeView: View {
    let isStartEnabled: Bool
    let onStart: () -> Void
    /// A returning learner reinstalling the app lands here, not on the account
    /// step, so sign-in has to be reachable from the very first screen.
    let onSignIn: () -> Void
    var notice: AuthError?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.md) {
                    Text("ORIENTATION · 1/6")
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .tracking(0.7)
                        .foregroundStyle(OnboardingPalette.lectureBlue)
                        .fixedSize(horizontal: false, vertical: true)

                    WelcomeCurriculumThread()

                    Text("Learn AI by building better judgment.")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(OnboardingPalette.academicInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Practice prompting, checking outputs, and responsible use before your first lesson.")
                        .font(.body)
                        .foregroundStyle(OnboardingPalette.academicInk.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Space.lg)

                VStack(spacing: Space.sm) {
                    if let notice, notice.shouldPresentMessage {
                        Label {
                            Text(notice.message)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "info.circle")
                                .accessibilityHidden(true)
                        }
                        .font(.footnote)
                        .foregroundStyle(OnboardingPalette.correctionCoral)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityIdentifier("onboarding.welcome.notice")
                    }

                    PrimaryButton(title: "Start learning", action: onStart)
                        .disabled(!isStartEnabled)
                        .accessibilityIdentifier("onboarding.start")

                    Button("I already have an account", action: onSignIn)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(OnboardingPalette.lectureBlue)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .accessibilityIdentifier("onboarding.sign-in")
                }
            }
            .frame(maxWidth: 560, minHeight: 620, alignment: .topLeading)
            .padding(.horizontal, Layout.pageInset)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.xl)
        }
        .background(OnboardingPalette.campusPaper)
        .accessibilityIdentifier("onboarding.welcome")
    }
}

private struct WelcomeCurriculumThread: View {
    var body: some View {
        HStack(spacing: 18) {
            Circle()
                .stroke(OnboardingPalette.academicInk, lineWidth: 2)
                .frame(width: 16, height: 16)

            Rectangle()
                .stroke(OnboardingPalette.academicInk, lineWidth: 2)
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(45))

            Rectangle()
                .stroke(OnboardingPalette.academicInk, lineWidth: 2)
                .frame(width: 16, height: 16)
        }
        .frame(minHeight: 44)
        .accessibilityHidden(true)
    }
}
