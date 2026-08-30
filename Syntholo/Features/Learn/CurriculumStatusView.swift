import SwiftUI

enum CurriculumStatusKind: Equatable {
    case loading
    case saved(isRefreshing: Bool)
    case empty
    case updateRequired(hasSavedContent: Bool)
    case unavailable
    case compositionPending
    case routeUnavailable
}

struct CurriculumStatusView: View {
    let kind: CurriculumStatusKind
    var retryAction: (() -> Void)?

    var body: some View {
        switch kind {
        case .loading:
            CurriculumLoadingStatusView()

        case let .saved(isRefreshing):
            CurriculumSavedStatusView(
                isRefreshing: isRefreshing,
                retryAction: retryAction
            )

        case .empty:
            CurriculumUnavailableStatusView(
                title: "No curriculum is published yet",
                systemImage: "books.vertical",
                description: "Learning content for this language isn’t available yet.",
                accessibilityIdentifier: "curriculum.status.empty",
                retryAction: nil
            )

        case let .updateRequired(hasSavedContent):
            if hasSavedContent {
                CurriculumUpdateBannerView()
            } else {
                CurriculumUnavailableStatusView(
                    title: "Update Syntholo",
                    systemImage: "arrow.down.app",
                    description: "A newer version of Syntholo is required to view this curriculum.",
                    accessibilityIdentifier: "curriculum.status.update-required",
                    retryAction: nil
                )
            }

        case .unavailable:
            CurriculumUnavailableStatusView(
                title: "Learning content is unavailable",
                systemImage: "wifi.exclamationmark",
                description: "Your place is safe. Check your connection and try again.",
                accessibilityIdentifier: "curriculum.status.unavailable",
                retryAction: retryAction
            )

        case .compositionPending:
            CurriculumCompositionPendingView()

        case .routeUnavailable:
            CurriculumUnavailableStatusView(
                title: "This curriculum item is unavailable",
                systemImage: "doc.questionmark",
                description: "Return to Learn and choose an available curriculum item.",
                accessibilityIdentifier: "curriculum.status.route-unavailable",
                retryAction: nil
            )
        }
    }
}

/// A finite Task 8 root-composition seam. Task 9 removes this state when the
/// real curriculum dependencies are constructed in `RootView`.
private struct CurriculumCompositionPendingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Space.md) {
                Image(systemName: "books.vertical")
                    .font(.largeTitle)
                    .foregroundStyle(SyntholoColor.secondaryInk)
                    .accessibilityHidden(true)

                Text("Learning content is unavailable")
                    .font(SyntholoTextStyle.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    "Learning content isn’t available right now. Please try again later."
                )
                    .font(SyntholoTextStyle.body)
                    .foregroundStyle(SyntholoColor.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(Layout.pageInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SyntholoColor.canvas)
        .accessibilityIdentifier("curriculum.status.unavailable")
    }
}

private struct CurriculumLoadingStatusView: View {
    var body: some View {
        VStack(spacing: Space.md) {
            ProgressView()
                .controlSize(.large)

            Text("Loading curriculum…")
                .font(.headline)

            Text("Checking for available programs.")
                .font(.body)
                .foregroundStyle(SyntholoColor.secondaryInk)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Layout.pageInset)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("curriculum.status.loading")
    }
}

private struct CurriculumSavedStatusView: View {
    let isRefreshing: Bool
    let retryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            if isRefreshing {
                Label("Saved curriculum", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .foregroundStyle(SyntholoColor.warning)

                Text("Saved lessons remain available while Syntholo checks for updates.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Label("Couldn’t refresh curriculum", systemImage: "arrow.down.circle.fill")
                    .font(.headline)
                    .foregroundStyle(SyntholoColor.warning)

                Text("Your saved lessons remain available. Try again when you’re ready.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if isRefreshing {
                ProgressView("Checking for updates…")
                    .font(.subheadline)
            } else if let retryAction {
                Button(action: retryAction) {
                    Text("Try again")
                        .frame(minHeight: Layout.minimumControlHeight)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("curriculum.status.retry")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(SyntholoColor.warning.opacity(0.12), in: .rect(cornerRadius: Radius.control))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("curriculum.status.saved")
    }
}

private struct CurriculumUpdateBannerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Label("Update Syntholo", systemImage: "arrow.down.app.fill")
                .font(.headline)
                .foregroundStyle(SyntholoColor.warning)

            Text(
                "A newer app is required for the latest curriculum. Your saved curriculum remains available below."
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(SyntholoColor.warning.opacity(0.12), in: .rect(cornerRadius: Radius.control))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("curriculum.status.update-required")
    }
}

private struct CurriculumUnavailableStatusView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let description: LocalizedStringKey
    let accessibilityIdentifier: String
    let retryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier(accessibilityIdentifier)
            } icon: {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
        } description: {
            Text(description)
                .font(.body)
                .foregroundStyle(SyntholoColor.secondaryInk)
        } actions: {
            if let retryAction {
                Button(action: retryAction) {
                    Text("Try again")
                        .frame(minHeight: Layout.minimumControlHeight)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("curriculum.status.retry")
            }
        }
    }
}
