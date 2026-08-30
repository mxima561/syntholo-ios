import Foundation
import SwiftUI

struct ModuleDetailPresentation: Equatable {
    let title: String
    let summary: String
    let version: Int
    let lessons: [LessonRowPresentation]

    init?(
        snapshot: CurriculumSnapshot,
        reference: ModuleVersionReference
    ) {
        guard snapshot.locale == reference.locale,
              snapshot.catalogVersion.catalogVersionID == reference.catalogVersionID,
              snapshot.catalogVersion.programEntries.contains(where: {
                  $0.programVersionID == reference.programVersionID
              }),
              let program = snapshot.programVersions.first(where: {
                  $0.programVersionID == reference.programVersionID
              }),
              program.moduleVersionIDs.contains(reference.moduleVersionID),
              let module = snapshot.moduleVersions.first(where: {
                  $0.moduleVersionID == reference.moduleVersionID
              }),
              module.programID == program.programID else {
            return nil
        }
        guard program.locale == reference.locale,
              module.locale == reference.locale,
              snapshot.catalogVersion.programEntries.contains(where: {
                  $0.programVersionID == reference.programVersionID
                      && $0.programPointerID.stableIDToken == program.programID.rawValue
              }) else {
            return nil
        }

        var lessonsByID: [CurriculumVersionID: CurriculumLessonVersion] = [:]
        for lesson in snapshot.lessonVersions {
            guard lessonsByID.updateValue(
                lesson,
                forKey: lesson.lessonVersionID
            ) == nil else {
                return nil
            }
        }
        let rubricVersionIDs = Set(
            snapshot.rubricVersions.map(\.rubricVersionID)
        )

        title = module.title
        summary = module.summary
        version = module.version.rawValue
        var orderedLessons: [LessonRowPresentation] = []
        orderedLessons.reserveCapacity(module.lessonVersionIDs.count)
        for lessonVersionID in module.lessonVersionIDs {
            guard let lesson = lessonsByID[lessonVersionID],
                  lesson.programID == program.programID,
                  lesson.moduleID == module.moduleID,
                  lesson.locale == reference.locale,
                  rubricVersionIDs.contains(lesson.rubricVersionID) else {
                return nil
            }
            orderedLessons.append(LessonRowPresentation(
                id: lesson.lessonVersionID,
                title: lesson.title,
                objective: lesson.objective,
                expectedDurationMinutes: lesson.expectedDurationMinutes,
                version: lesson.version.rawValue,
                route: LessonVersionReference(
                    locale: reference.locale,
                    catalogVersionID: reference.catalogVersionID,
                    programVersionID: reference.programVersionID,
                    moduleVersionID: reference.moduleVersionID,
                    lessonVersionID: lesson.lessonVersionID,
                    rubricVersionID: lesson.rubricVersionID
                )
            ))
        }
        lessons = orderedLessons
    }
}

struct LessonRowPresentation: Identifiable, Equatable {
    let id: CurriculumVersionID
    let title: String
    let objective: String
    let expectedDurationMinutes: Int
    let version: Int
    let route: LessonVersionReference
}

struct ModuleDetailView: View {
    let presentation: ModuleDetailPresentation

    var body: some View {
        List {
            ModuleHeaderView(
                title: presentation.title,
                summary: presentation.summary,
                version: presentation.version
            )

            Section("Lessons") {
                ForEach(presentation.lessons) { lesson in
                    LessonNavigationRow(presentation: lesson)
                }
            }
        }
        .navigationTitle(presentation.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("curriculum.module.detail")
    }
}

private struct ModuleHeaderView: View {
    let title: String
    let summary: String
    let version: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.title2)
                .foregroundStyle(SyntholoColor.accent)
                .accessibilityHidden(true)

            Text(title)
                .font(SyntholoTextStyle.pageTitle)
                .fixedSize(horizontal: false, vertical: true)

            Text(summary)
                .font(SyntholoTextStyle.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            LabeledContent("Module version") {
                Text(version, format: .number)
                    .monospacedDigit()
            }
            .font(.subheadline)
        }
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .combine)
    }
}

private struct LessonNavigationRow: View {
    let presentation: LessonRowPresentation

    var body: some View {
        NavigationLink(value: LearnRoute.lesson(presentation.route)) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(presentation.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text(presentation.objective)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: Space.sm) {
                    Label {
                        Text(
                            Measurement(
                                value: Double(presentation.expectedDurationMinutes),
                                unit: UnitDuration.minutes
                            ),
                            format: .measurement(width: .wide)
                        )
                    } icon: {
                        Image(systemName: "clock")
                    }

                    HStack(spacing: Space.xs) {
                        Text("Lesson version")
                        Text(presentation.version, format: .number)
                            .monospacedDigit()
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, Space.xs)
        }
        .accessibilityIdentifier(
            "curriculum.lesson.\(presentation.id.rawValue)"
        )
    }
}
