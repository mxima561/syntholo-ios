import SwiftUI

struct CurriculumCatalogPresentation: Equatable {
    let locale: String
    let version: Int
    let programs: [ProgramCatalogRowPresentation]

    init?(snapshot: CurriculumSnapshot) {
        guard snapshot.catalogVersion.locale == snapshot.locale else {
            return nil
        }
        var programsByID: [CurriculumVersionID: CurriculumProgramVersion] = [:]
        for program in snapshot.programVersions {
            guard programsByID.updateValue(
                program,
                forKey: program.programVersionID
            ) == nil else {
                return nil
            }
        }

        var orderedPrograms: [ProgramCatalogRowPresentation] = []
        var seenProgramVersionIDs: Set<CurriculumVersionID> = []
        orderedPrograms.reserveCapacity(
            snapshot.catalogVersion.programEntries.count
        )
        for entry in snapshot.catalogVersion.programEntries {
            guard let program = programsByID[entry.programVersionID],
                  program.locale == snapshot.locale,
                  entry.programPointerID.stableIDToken == program.programID.rawValue,
                  seenProgramVersionIDs.insert(program.programVersionID).inserted else {
                return nil
            }

            let availability: ProgramCatalogAvailability
            switch program.catalogState {
            case .available:
                guard !program.moduleVersionIDs.isEmpty else {
                    return nil
                }
                availability = .available(
                    ProgramVersionReference(
                        locale: snapshot.locale,
                        catalogVersionID: snapshot.catalogVersion.catalogVersionID,
                        programVersionID: program.programVersionID
                    )
                )
            case .comingSoon:
                guard program.moduleVersionIDs.isEmpty else {
                    return nil
                }
                availability = .comingSoon
            }

            orderedPrograms.append(
                ProgramCatalogRowPresentation(
                    id: program.programVersionID,
                    title: program.title,
                    promise: program.promise,
                    version: program.version.rawValue,
                    availability: availability
                )
            )
        }

        locale = snapshot.locale.rawValue
        version = snapshot.catalogVersion.version.rawValue
        programs = orderedPrograms
    }
}

enum ProgramCatalogAvailability: Equatable {
    case available(ProgramVersionReference)
    case comingSoon
}

struct ProgramCatalogRowPresentation: Identifiable, Equatable {
    let id: CurriculumVersionID
    let title: String
    let promise: String
    let version: Int
    let availability: ProgramCatalogAvailability
}

struct LearnHomeView: View {
    let store: CurriculumStore
    @Bindable var router: AppRouter

    init(store: CurriculumStore, router: AppRouter) {
        self.store = store
        self.router = router
    }

    var body: some View {
        NavigationStack(path: $router.learnPath) {
            CurriculumStoreContent(store: store)
                .navigationDestination(for: LearnRoute.self) { route in
                    destination(for: route, store: store)
                }
        }
        .task {
            store.load()
        }
        .onChange(of: router.learnPath, initial: true) { _, newPath in
            store.setPinnedCatalogVersionIDs(
                Set(newPath.map(\.catalogVersionID))
            )
        }
    }

    @ViewBuilder
    private func destination(
        for route: LearnRoute,
        store: CurriculumStore
    ) -> some View {
        if let snapshot = store.snapshot(for: route.catalogVersionID) {
            switch route {
            case let .program(reference):
                if let presentation = ProgramDetailPresentation(
                    snapshot: snapshot,
                    reference: reference
                ) {
                    ProgramDetailView(presentation: presentation)
                } else {
                    CurriculumStatusView(kind: .routeUnavailable)
                }

            case let .module(reference):
                if let presentation = ModuleDetailPresentation(
                    snapshot: snapshot,
                    reference: reference
                ) {
                    ModuleDetailView(presentation: presentation)
                } else {
                    CurriculumStatusView(kind: .routeUnavailable)
                }

            case let .lesson(reference):
                if let presentation = LessonPreviewPresentation(
                    snapshot: snapshot,
                    reference: reference
                ) {
                    LessonPreviewView(presentation: presentation)
                } else {
                    CurriculumStatusView(kind: .routeUnavailable)
                }
            }
        } else {
            CurriculumStatusView(kind: .routeUnavailable)
        }
    }
}

private struct CurriculumStoreContent: View {
    let store: CurriculumStore

    var body: some View {
        switch store.state {
        case .loading:
            CurriculumStatusView(kind: .loading)
                .navigationTitle("Learn")

        case let .ready(snapshot, freshness):
            if freshness == .saved {
                CurriculumCatalogScreen(
                    snapshot: snapshot,
                    status: .saved(isRefreshing: store.isLoadActive),
                    retryAction: {
                        store.retry()
                    }
                )
            } else {
                CurriculumCatalogScreen(
                    snapshot: snapshot,
                    status: nil,
                    retryAction: nil
                )
            }

        case .empty:
            CurriculumStatusView(kind: .empty)
                .navigationTitle("Learn")

        case let .updateRequired(_, fallbackSnapshot):
            if let fallbackSnapshot {
                CurriculumCatalogScreen(
                    snapshot: fallbackSnapshot,
                    status: .updateRequired(hasSavedContent: true),
                    retryAction: nil
                )
            } else {
                CurriculumStatusView(
                    kind: .updateRequired(hasSavedContent: false)
                )
                .navigationTitle("Learn")
            }

        case let .unavailable(retryable):
            if retryable {
                CurriculumStatusView(
                    kind: .unavailable,
                    retryAction: {
                        store.retry()
                    }
                )
                .navigationTitle("Learn")
            } else {
                CurriculumStatusView(kind: .unavailable)
                    .navigationTitle("Learn")
            }
        }
    }
}

private struct CurriculumCatalogScreen: View {
    private let presentation: CurriculumCatalogPresentation?
    let status: CurriculumStatusKind?
    let retryAction: (() -> Void)?

    init(
        snapshot: CurriculumSnapshot,
        status: CurriculumStatusKind?,
        retryAction: (() -> Void)?
    ) {
        presentation = CurriculumCatalogPresentation(snapshot: snapshot)
        self.status = status
        self.retryAction = retryAction
    }

    var body: some View {
        if let presentation {
            List {
                CurriculumCatalogHeader(
                    locale: presentation.locale,
                    version: presentation.version
                )

                if let status {
                    CurriculumStatusView(
                        kind: status,
                        retryAction: retryAction
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(
                        EdgeInsets(
                            top: Space.sm,
                            leading: 0,
                            bottom: Space.sm,
                            trailing: 0
                        )
                    )
                }

                Section {
                    ForEach(presentation.programs) { program in
                        ProgramCatalogRow(presentation: program)
                    }
                } header: {
                    Text("Programs")
                        .font(.headline)
                        .foregroundStyle(SyntholoColor.ink)
                        .textCase(nil)
                }
            }
            .navigationTitle("Learn")
            .accessibilityIdentifier("curriculum.catalog")
        } else {
            CurriculumStatusView(kind: .unavailable)
                .navigationTitle("Learn")
        }
    }
}

private struct CurriculumCatalogHeader: View {
    let locale: String
    let version: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Image(systemName: "books.vertical.fill")
                .font(.title2)
                .foregroundStyle(SyntholoColor.accent)
                .accessibilityHidden(true)

            Text("Curriculum catalog")
                .font(SyntholoTextStyle.pageTitle)
                .fixedSize(horizontal: false, vertical: true)

            Text("Choose an available program to preview its lessons.")
                .font(.body)
                .foregroundStyle(SyntholoColor.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Language")
                    .font(.subheadline.weight(.semibold))
                Text(locale)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Catalog version")
                    .font(.subheadline.weight(.semibold))
                Text(version, format: .number)
                    .font(.body)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .contain)
    }
}

private struct ProgramCatalogRow: View {
    let presentation: ProgramCatalogRowPresentation

    var body: some View {
        switch presentation.availability {
        case let .available(reference):
            NavigationLink(value: LearnRoute.program(reference)) {
                ProgramCatalogRowContent(
                    presentation: presentation,
                    isComingSoon: false
                )
            }
            .accessibilityIdentifier(
                "curriculum.program.\(presentation.id.rawValue)"
            )

        case .comingSoon:
            ProgramCatalogRowContent(
                presentation: presentation,
                isComingSoon: true
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(
                "curriculum.program.\(presentation.id.rawValue)"
            )
        }
    }
}

private struct ProgramCatalogRowContent: View {
    let presentation: ProgramCatalogRowPresentation
    let isComingSoon: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(presentation.title)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Text(presentation.promise)
                .font(.subheadline)
                .foregroundStyle(SyntholoColor.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Space.xs) {
                Text("Program version")
                    .font(.body)
                Text(presentation.version, format: .number)
                    .font(.body)
                    .monospacedDigit()

                if isComingSoon {
                    Label("More modules are arriving", systemImage: "clock")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(
                isComingSoon
                    ? SyntholoColor.warning
                    : SyntholoColor.secondaryInk
            )
        }
        .padding(.vertical, Space.xs)
    }
}
