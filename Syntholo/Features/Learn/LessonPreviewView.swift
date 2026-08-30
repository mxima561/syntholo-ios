import Foundation
import SwiftUI

struct LessonPreviewPresentation: Equatable {
    let title: String
    let objective: String
    let expectedDurationMinutes: Int
    let lessonVersion: Int
    let rubricVersion: Int
    let blocks: [LessonContentBlockPresentation]
    let criteria: [RubricCriterionPresentation]

    init?(
        snapshot: CurriculumSnapshot,
        reference: LessonVersionReference
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
              module.programID == program.programID,
              module.lessonVersionIDs.contains(reference.lessonVersionID),
              let lesson = snapshot.lessonVersions.first(where: {
                  $0.lessonVersionID == reference.lessonVersionID
              }),
              lesson.programID == program.programID,
              lesson.moduleID == module.moduleID,
              lesson.rubricVersionID == reference.rubricVersionID,
              let rubric = snapshot.rubricVersions.first(where: {
                  $0.rubricVersionID == reference.rubricVersionID
              }) else {
            return nil
        }
        guard program.locale == reference.locale,
              module.locale == reference.locale,
              lesson.locale == reference.locale,
              rubric.locale == reference.locale,
              snapshot.catalogVersion.programEntries.contains(where: {
                  $0.programVersionID == reference.programVersionID
                      && $0.programPointerID.stableIDToken == program.programID.rawValue
              }) else {
            return nil
        }

        var assetsByID: [CurriculumVersionID: CurriculumAssetVersion] = [:]
        for asset in snapshot.assetVersions {
            guard assetsByID.updateValue(
                asset,
                forKey: asset.assetVersionID
            ) == nil else {
                return nil
            }
        }

        var sanitizedBlocks: [LessonContentBlockPresentation] = []
        var seenBlockIDs: Set<CurriculumStableID> = []
        sanitizedBlocks.reserveCapacity(lesson.blocks.count)

        for (expectedOrder, block) in lesson.blocks.enumerated() {
            guard block.order == expectedOrder,
                  seenBlockIDs.insert(block.blockID).inserted else {
                return nil
            }
            switch block {
            case let .conceptText(concept):
                sanitizedBlocks.append(
                    .concept(
                        ConceptBlockPresentation(
                            id: concept.blockID,
                            heading: concept.heading,
                            body: concept.body
                        )
                    )
                )

            case let .stillDiagram(diagram):
                guard lesson.assetVersionIDs.contains(diagram.assetVersionID),
                      let asset = assetsByID[diagram.assetVersionID],
                      asset.locale == reference.locale,
                      let presentation = DiagramBlockPresentation(
                          block: diagram,
                          asset: asset
                      ) else {
                    return nil
                }
                sanitizedBlocks.append(.diagram(presentation))

            case let .singleAnswerQuestion(question):
                var seenOptionIDs: Set<CurriculumStableID> = []
                var options: [QuestionOptionPresentation] = []
                options.reserveCapacity(question.options.count)
                for option in question.options {
                    guard seenOptionIDs.insert(option.optionID).inserted else {
                        return nil
                    }
                    options.append(
                        QuestionOptionPresentation(
                            id: option.optionID,
                            text: option.text
                        )
                    )
                }
                sanitizedBlocks.append(
                    .question(
                        QuestionBlockPresentation(
                            id: question.blockID,
                            prompt: question.prompt,
                            options: options
                        )
                    )
                )
            }
        }

        var seenCriterionIDs: Set<CurriculumStableID> = []
        var sanitizedCriteria: [RubricCriterionPresentation] = []
        sanitizedCriteria.reserveCapacity(rubric.criteria.count)
        for criterion in rubric.criteria {
            guard seenCriterionIDs.insert(criterion.criterionID).inserted else {
                return nil
            }
            sanitizedCriteria.append(
                RubricCriterionPresentation(
                    id: criterion.criterionID,
                    title: criterion.title,
                    description: criterion.description
                )
            )
        }
        guard !sanitizedCriteria.isEmpty else {
            return nil
        }

        title = lesson.title
        objective = lesson.objective
        expectedDurationMinutes = lesson.expectedDurationMinutes
        lessonVersion = lesson.version.rawValue
        rubricVersion = rubric.version.rawValue
        blocks = sanitizedBlocks
        criteria = sanitizedCriteria
    }
}

enum LessonContentBlockPresentation: Identifiable, Equatable {
    case concept(ConceptBlockPresentation)
    case diagram(DiagramBlockPresentation)
    case question(QuestionBlockPresentation)

    var id: CurriculumStableID {
        switch self {
        case let .concept(presentation):
            presentation.id
        case let .diagram(presentation):
            presentation.id
        case let .question(presentation):
            presentation.id
        }
    }
}

struct ConceptBlockPresentation: Equatable {
    let id: CurriculumStableID
    let heading: String?
    let body: String
}

struct DiagramBlockPresentation: Equatable {
    let id: CurriculumStableID
    let assetVersionID: CurriculumVersionID
    let title: String
    let textAlternative: String
    let nodes: [DiagramNodePresentation]
    let connectors: [DiagramConnectorPresentation]

    init?(
        block: StillDiagramBlockV1,
        asset: CurriculumAssetVersion
    ) {
        guard block.assetVersionID == asset.assetVersionID else {
            return nil
        }

        var labelsByNodeID: [CurriculumStableID: String] = [:]
        for node in asset.payload.nodes {
            guard labelsByNodeID.updateValue(
                node.label,
                forKey: node.nodeID
            ) == nil else {
                return nil
            }
        }

        var sanitizedConnectors: [DiagramConnectorPresentation] = []
        var seenConnectorIDs: Set<CurriculumStableID> = []
        sanitizedConnectors.reserveCapacity(asset.payload.connectors.count)
        for connector in asset.payload.connectors {
            guard seenConnectorIDs.insert(connector.connectorID).inserted,
                  let fromLabel = labelsByNodeID[connector.fromNodeID],
                  let toLabel = labelsByNodeID[connector.toNodeID] else {
                return nil
            }
            sanitizedConnectors.append(
                DiagramConnectorPresentation(
                    id: connector.connectorID,
                    fromLabel: fromLabel,
                    toLabel: toLabel,
                    label: connector.label
                )
            )
        }

        id = block.blockID
        assetVersionID = asset.assetVersionID
        title = block.title
        textAlternative = asset.accessibilityDescription
        nodes = asset.payload.nodes.map {
            DiagramNodePresentation(
                id: $0.nodeID,
                label: $0.label,
                isEmphasized: $0.emphasis == .accent
            )
        }
        connectors = sanitizedConnectors
    }
}

struct DiagramNodePresentation: Identifiable, Equatable {
    let id: CurriculumStableID
    let label: String
    let isEmphasized: Bool
}

struct DiagramConnectorPresentation: Identifiable, Equatable {
    let id: CurriculumStableID
    let fromLabel: String
    let toLabel: String
    let label: String?
}

struct QuestionBlockPresentation: Equatable {
    let id: CurriculumStableID
    let prompt: String
    let options: [QuestionOptionPresentation]
}

struct QuestionOptionPresentation: Identifiable, Equatable {
    let id: CurriculumStableID
    let text: String
}

struct RubricCriterionPresentation: Identifiable, Equatable {
    let id: CurriculumStableID
    let title: String
    let description: String
}

struct LessonPreviewView: View {
    let presentation: LessonPreviewPresentation

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Space.lg) {
                LessonPreviewHeader(presentation: presentation)

                ForEach(presentation.blocks) { block in
                    LessonContentBlockView(presentation: block)
                }

                RubricCriteriaView(criteria: presentation.criteria)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Layout.pageInset)
        }
        .background(SyntholoColor.canvas)
        .navigationTitle(presentation.title)
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("curriculum.lesson.preview")
    }
}

private struct LessonPreviewHeader: View {
    let presentation: LessonPreviewPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Label("Read-only lesson preview", systemImage: "eye.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SyntholoColor.accent)

            Text(presentation.title)
                .font(SyntholoTextStyle.pageTitle)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Objective")
                    .font(.headline)
                Text(presentation.objective)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            LabeledContent("Expected duration") {
                Text(
                    Measurement(
                        value: Double(presentation.expectedDurationMinutes),
                        unit: UnitDuration.minutes
                    ),
                    format: .measurement(width: .wide)
                )
            }

            LabeledContent("Lesson version") {
                Text(presentation.lessonVersion, format: .number)
                    .monospacedDigit()
            }

            LabeledContent("Rubric version") {
                Text(presentation.rubricVersion, format: .number)
                    .monospacedDigit()
            }

            LabeledContent("Rubric type") {
                Text("Deterministic")
            }
        }
        .curriculumCard()
        .accessibilityElement(children: .contain)
    }
}

private struct LessonContentBlockView: View {
    let presentation: LessonContentBlockPresentation

    var body: some View {
        switch presentation {
        case let .concept(concept):
            ConceptBlockView(presentation: concept)
        case let .diagram(diagram):
            DiagramBlockView(presentation: diagram)
        case let .question(question):
            QuestionBlockView(presentation: question)
        }
    }
}

private struct ConceptBlockView: View {
    let presentation: ConceptBlockPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            Label("Concept", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(SyntholoColor.accent)

            if let heading = presentation.heading {
                Text(heading)
                    .font(SyntholoTextStyle.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(presentation.body)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .curriculumCard()
        .accessibilityIdentifier(
            "curriculum.concept.\(presentation.id.rawValue)"
        )
    }
}

private struct DiagramBlockView: View {
    let presentation: DiagramBlockPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Label("Diagram", systemImage: "point.3.connected.trianglepath.dotted")
                .font(.headline)
                .foregroundStyle(SyntholoColor.accent)

            Text(presentation.title)
                .font(SyntholoTextStyle.sectionTitle)
                .fixedSize(horizontal: false, vertical: true)

            DiagramGraphicView(
                nodes: presentation.nodes,
                connectors: presentation.connectors
            )
            .accessibilityHidden(true)

            Divider()

            Label("Text alternative", systemImage: "text.alignleft")
                .font(.subheadline.weight(.semibold))

            Text(presentation.textAlternative)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .curriculumCard()
        .accessibilityIdentifier(
            "curriculum.diagram.\(presentation.id.rawValue)"
        )
    }
}

private struct DiagramGraphicView: View {
    let nodes: [DiagramNodePresentation]
    let connectors: [DiagramConnectorPresentation]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            ForEach(nodes) { node in
                Label {
                    Text(node.label)
                        .fontWeight(node.isEmphasized ? .semibold : .regular)
                } icon: {
                    Image(systemName: node.isEmphasized ? "star.fill" : "circle.fill")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.sm)
                .background(
                    node.isEmphasized
                        ? SyntholoColor.accent.opacity(0.15)
                        : SyntholoColor.canvas,
                    in: .rect(cornerRadius: Radius.control)
                )
            }

            ForEach(connectors) { connector in
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.sm) {
                        Text(connector.fromLabel)
                        Image(systemName: "arrow.right")
                        Text(connector.toLabel)
                    }
                    .font(.subheadline)

                    if let label = connector.label {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct QuestionBlockView: View {
    let presentation: QuestionBlockPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Label("Question preview", systemImage: "questionmark.bubble.fill")
                .font(.headline)
                .foregroundStyle(SyntholoColor.accent)

            Text(presentation.prompt)
                .font(SyntholoTextStyle.sectionTitle)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: Space.sm) {
                ForEach(presentation.options) { option in
                    HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                        Image(systemName: "circle")
                            .accessibilityHidden(true)
                        Text(option.text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Space.sm)
                    .background(
                        SyntholoColor.canvas,
                        in: .rect(cornerRadius: Radius.control)
                    )
                    .accessibilityElement(children: .combine)
                }
            }

            Text("Read-only preview. Answers aren’t collected yet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .curriculumCard()
        .accessibilityIdentifier(
            "curriculum.question.\(presentation.id.rawValue)"
        )
    }
}

private struct RubricCriteriaView: View {
    let criteria: [RubricCriterionPresentation]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Label("Criteria", systemImage: "checklist")
                .font(.headline)
                .foregroundStyle(SyntholoColor.accent)

            Text(
                "These read-only criteria describe what the lesson checks without showing answers."
            )
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(criteria) { criterion in
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(criterion.title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(criterion.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.xs)
            }
        }
        .curriculumCard()
        .accessibilityIdentifier("curriculum.lesson.criteria")
    }
}

private struct CurriculumCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Space.md)
            .background(
                SyntholoColor.surface,
                in: .rect(cornerRadius: Radius.card)
            )
    }
}

private extension View {
    func curriculumCard() -> some View {
        modifier(CurriculumCardModifier())
    }
}
