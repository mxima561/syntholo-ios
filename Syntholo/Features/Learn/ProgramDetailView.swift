import SwiftUI

struct ProgramDetailPresentation: Equatable {
    let title: String
    let promise: String
    let version: Int
    let isComingSoon: Bool
    let modules: [ModuleRowPresentation]

    init?(
        snapshot: CurriculumSnapshot,
        reference: ProgramVersionReference
    ) {
        guard snapshot.locale == reference.locale,
              snapshot.catalogVersion.catalogVersionID == reference.catalogVersionID,
              snapshot.catalogVersion.programEntries.contains(where: {
                  $0.programVersionID == reference.programVersionID
              }),
              let program = snapshot.programVersions.first(where: {
                  $0.programVersionID == reference.programVersionID
              }) else {
            return nil
        }
        guard program.locale == reference.locale,
              snapshot.catalogVersion.programEntries.contains(where: {
                  $0.programVersionID == reference.programVersionID
                      && $0.programPointerID.stableIDToken == program.programID.rawValue
              }) else {
            return nil
        }

        var modulesByID: [CurriculumVersionID: CurriculumModuleVersion] = [:]
        for module in snapshot.moduleVersions {
            guard modulesByID.updateValue(
                module,
                forKey: module.moduleVersionID
            ) == nil else {
                return nil
            }
        }

        title = program.title
        promise = program.promise
        version = program.version.rawValue
        isComingSoon = program.catalogState == .comingSoon
        guard isComingSoon == program.moduleVersionIDs.isEmpty else {
            return nil
        }
        var orderedModules: [ModuleRowPresentation] = []
        orderedModules.reserveCapacity(program.moduleVersionIDs.count)
        for moduleVersionID in program.moduleVersionIDs {
            guard let module = modulesByID[moduleVersionID],
                  module.programID == program.programID,
                  module.locale == reference.locale else {
                return nil
            }
            orderedModules.append(ModuleRowPresentation(
                id: module.moduleVersionID,
                title: module.title,
                summary: module.summary,
                version: module.version.rawValue,
                route: ModuleVersionReference(
                    locale: reference.locale,
                    catalogVersionID: reference.catalogVersionID,
                    programVersionID: reference.programVersionID,
                    moduleVersionID: module.moduleVersionID
                )
            ))
        }
        modules = orderedModules
    }
}

struct ModuleRowPresentation: Identifiable, Equatable {
    let id: CurriculumVersionID
    let title: String
    let summary: String
    let version: Int
    let route: ModuleVersionReference
}

struct ProgramDetailView: View {
    let presentation: ProgramDetailPresentation

    var body: some View {
        List {
            ProgramHeaderView(
                title: presentation.title,
                promise: presentation.promise,
                version: presentation.version
            )

            if presentation.isComingSoon {
                CurriculumComingSoonView()
            } else {
                Section("Modules") {
                    ForEach(presentation.modules) { module in
                        ModuleNavigationRow(presentation: module)
                    }
                }
            }
        }
        .navigationTitle(presentation.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("curriculum.program.detail")
    }
}

private struct ProgramHeaderView: View {
    let title: String
    let promise: String
    let version: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Image(systemName: "book.closed.fill")
                .font(.title2)
                .foregroundStyle(SyntholoColor.accent)
                .accessibilityHidden(true)

            Text(title)
                .font(SyntholoTextStyle.pageTitle)
                .fixedSize(horizontal: false, vertical: true)

            Text(promise)
                .font(SyntholoTextStyle.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("Program version") {
                Text(version, format: .number)
                    .monospacedDigit()
            }
            .font(.subheadline)
        }
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .combine)
    }
}

private struct ModuleNavigationRow: View {
    let presentation: ModuleRowPresentation

    var body: some View {
        NavigationLink(value: LearnRoute.module(presentation.route)) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(presentation.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(presentation.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Space.xs) {
                    Text("Module version")
                    Text(presentation.version, format: .number)
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, Space.xs)
        }
        .accessibilityIdentifier(
            "curriculum.module.\(presentation.id.rawValue)"
        )
    }
}

private struct CurriculumComingSoonView: View {
    var body: some View {
        ContentUnavailableView(
            "More modules are arriving",
            systemImage: "clock",
            description: Text(
                "This program is in the catalog. Its learning modules are coming soon."
            )
        )
        .accessibilityIdentifier("curriculum.program.coming-soon")
    }
}
