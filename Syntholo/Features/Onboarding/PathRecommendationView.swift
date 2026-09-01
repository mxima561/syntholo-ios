import SwiftUI

struct PathRecommendationView: View {
    let recommendedPath: LearningPath
    let selectedPath: LearningPath?
    let onSelectPath: (LearningPath) -> Void

    #if DEBUG
    @State private var showsOtherPaths = ProcessInfo.processInfo.arguments.contains(
        "--path-options-expanded"
    )
    #else
    @State private var showsOtherPaths = false
    #endif

    var body: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--path-state-proof") {
            content
                .accessibilityValue(pathStateProof)
        } else {
            content
        }
        #else
        content
        #endif
    }

    private var content: some View {
        OnboardingPage(
            eyebrow: "YOUR ROUTE",
            progress: nil,
            title: "Start with Foundations",
            introduction: "Build core prompting and checking skills, then apply them to your goal.",
            accessibilityIdentifier: "onboarding.path"
        ) {
            routeGraphic

            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(spacing: Space.sm) {
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(OnboardingPalette.markerGold)
                        .accessibilityHidden(true)
                    Text("Recommended route")
                        .foregroundStyle(OnboardingPalette.academicInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption.weight(.semibold))

                Text(pathTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(OnboardingPalette.academicInk)

                Text(pathDetail)
                    .font(.body)
                    .foregroundStyle(OnboardingPalette.academicInk.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryButton(title: choosePathTitle) {
                onSelectPath(recommendedPath)
            }
            .accessibilityIdentifier("onboarding.choose-recommended-path")

            DisclosureGroup("Other paths", isExpanded: $showsOtherPaths) {
                ChoiceListView(
                    items: otherPaths,
                    selectedID: selectedPath,
                    onSelect: onSelectPath
                )
                .padding(.top, Space.sm)
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(OnboardingPalette.academicInk)
            .frame(minHeight: 44)
        }
    }

    #if DEBUG
    private var pathStateProof: String {
        "recommended=\(recommendedPath.rawValue);selected=\(selectedPath?.rawValue ?? "none")"
    }
    #endif

    private var routeGraphic: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.sm) {
                Circle()
                    .fill(OnboardingPalette.proofGreen)
                    .frame(width: 10, height: 10)
                Text("FOUNDATIONS")
                    .font(.system(.caption, design: .monospaced, weight: .bold))
            }

            HStack(alignment: .top, spacing: Space.sm) {
                Rectangle()
                    .fill(OnboardingPalette.markerGold)
                    .frame(width: 2, height: 34)
                    .padding(.leading, 4)
                Text(pathRouteLabel)
                    .font(.system(.caption, design: .monospaced, weight: .bold))
                    .padding(.top, 20)
            }
        }
        .foregroundStyle(OnboardingPalette.academicInk)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(routeAccessibilityLabel)
    }

    private var otherPaths: [ChoiceListItem<LearningPath>] {
        LearningPath.allCases
            .filter { $0 != recommendedPath }
            .map { path in
                ChoiceListItem(
                    id: path,
                    title: path.title,
                    detail: path.detail,
                    systemImage: path.systemImage,
                    accessibilityIdentifier: path.accessibilityIdentifier
                )
            }
    }

    private var pathTitle: LocalizedStringResource { recommendedPath.title }
    private var pathDetail: LocalizedStringResource { recommendedPath.detail }
    private var pathRouteLabel: LocalizedStringResource { recommendedPath.routeLabel }

    private var choosePathTitle: LocalizedStringResource {
        switch recommendedPath {
        case .school: "Choose AI for School"
        case .work: "Choose AI for Work"
        case .creation: "Choose AI for Creation"
        case .build: "Choose Build with AI"
        }
    }

    private var routeAccessibilityLabel: Text {
        switch recommendedPath {
        case .school: Text("Foundations, then AI for School")
        case .work: Text("Foundations, then AI for Work")
        case .creation: Text("Foundations, then AI for Creation")
        case .build: Text("Foundations, then Build with AI")
        }
    }
}

extension LearningPath {
    var title: LocalizedStringResource {
        switch self {
        case .school: "AI for School"
        case .work: "AI for Work"
        case .creation: "AI for Creation"
        case .build: "Build with AI"
        }
    }

    var routeLabel: LocalizedStringResource {
        switch self {
        case .school: "AI FOR SCHOOL"
        case .work: "AI FOR WORK"
        case .creation: "AI FOR CREATION"
        case .build: "BUILD WITH AI"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .school: "Use AI for research, study plans, and checked explanations."
        case .work: "Use AI for drafts, summaries, and repeatable workflows."
        case .creation: "Use AI to plan, create, and revise media responsibly."
        case .build: "Use AI to prototype, test, and improve working tools."
        }
    }

    var systemImage: String {
        switch self {
        case .school: "graduationcap"
        case .work: "briefcase"
        case .creation: "paintbrush"
        case .build: "hammer"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .school: "AI for School"
        case .work: "AI for Work"
        case .creation: "AI for Creation"
        case .build: "Build with AI"
        }
    }
}
