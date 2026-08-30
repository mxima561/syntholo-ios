import SwiftUI

enum OnboardingPalette {
    static let campusPaper = Color(
        red: 247.0 / 255.0,
        green: 248.0 / 255.0,
        blue: 244.0 / 255.0
    )
    static let academicInk = Color(
        red: 21.0 / 255.0,
        green: 34.0 / 255.0,
        blue: 56.0 / 255.0
    )
    static let lectureBlue = Color(
        red: 46.0 / 255.0,
        green: 91.0 / 255.0,
        blue: 255.0 / 255.0
    )
    static let proofGreen = Color(
        red: 31.0 / 255.0,
        green: 122.0 / 255.0,
        blue: 90.0 / 255.0
    )
    static let markerGold = Color(
        red: 183.0 / 255.0,
        green: 121.0 / 255.0,
        blue: 31.0 / 255.0
    )
    static let correctionCoral = Color(
        red: 199.0 / 255.0,
        green: 78.0 / 255.0,
        blue: 78.0 / 255.0
    )
}

struct ChoiceListItem<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let detail: LocalizedStringKey
    let systemImage: String
}

struct ChoiceListView<ID: Hashable>: View {
    let items: [ChoiceListItem<ID>]
    let selectedID: ID?
    let onSelect: (ID) -> Void

    var body: some View {
        VStack(spacing: Space.sm) {
            ForEach(items) { item in
                let isSelected = item.id == selectedID

                Button {
                    onSelect(item.id)
                } label: {
                    HStack(spacing: Space.md) {
                        Image(systemName: item.systemImage)
                            .font(.body.weight(.semibold))
                            .frame(width: 24)
                            .foregroundStyle(
                                isSelected
                                    ? OnboardingPalette.proofGreen
                                    : OnboardingPalette.lectureBlue
                            )
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text(LocalizedStringKey(item.title))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(OnboardingPalette.academicInk)
                            Text(item.detail)
                                .font(.subheadline)
                                .foregroundStyle(OnboardingPalette.academicInk.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: Space.sm)

                        Image(systemName: isSelected ? "checkmark" : "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(
                                isSelected
                                    ? OnboardingPalette.proofGreen
                                    : OnboardingPalette.academicInk.opacity(0.66)
                            )
                            .accessibilityHidden(true)
                    }
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, minHeight: Layout.minimumControlHeight)
                    .background(OnboardingPalette.campusPaper)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                isSelected
                                    ? OnboardingPalette.proofGreen
                                    : OnboardingPalette.academicInk.opacity(0.28),
                                lineWidth: isSelected ? 2 : 1
                            )
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(item.title)
                .accessibilityValue(isSelected ? "Selected" : "Not selected")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

struct OnboardingPage<Content: View>: View {
    let eyebrow: LocalizedStringKey
    let progress: Int?
    let title: LocalizedStringKey
    let introduction: LocalizedStringKey?
    let accessibilityIdentifier: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: Space.md) {
                if let progress {
                    CurriculumThreadView(progress: progress)
                        .padding(.top, 3)
                }

                VStack(alignment: .leading, spacing: Space.lg) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text(eyebrow)
                            .font(.system(.caption, design: .monospaced, weight: .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(OnboardingPalette.lectureBlue)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(title)
                            .font(.system(.title, design: .default, weight: .bold))
                            .foregroundStyle(OnboardingPalette.academicInk)
                            .fixedSize(horizontal: false, vertical: true)

                        if let introduction {
                            Text(introduction)
                                .font(.body)
                                .foregroundStyle(OnboardingPalette.academicInk.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(.horizontal, Layout.pageInset)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xl)
        }
        .background(OnboardingPalette.campusPaper)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct CurriculumThreadView: View {
    let progress: Int

    var body: some View {
        VStack(spacing: 0) {
            ForEach(1...6, id: \.self) { index in
                node(at: index)

                if index < 6 {
                    Rectangle()
                        .fill(segmentColor(after: index))
                        .frame(width: 2, height: 22)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(width: 18)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func node(at index: Int) -> some View {
        if index == progress {
            Circle()
                .fill(OnboardingPalette.lectureBlue)
                .frame(width: 14, height: 14)
                .overlay {
                    Circle()
                        .stroke(OnboardingPalette.campusPaper, lineWidth: 3)
                        .padding(-4)
                }
        } else if index < progress {
            Circle()
                .fill(OnboardingPalette.proofGreen)
                .frame(width: 10, height: 10)
                .frame(width: 14, height: 14)
        } else {
            Circle()
                .stroke(OnboardingPalette.academicInk.opacity(0.36), lineWidth: 1.5)
                .frame(width: 10, height: 10)
                .frame(width: 14, height: 14)
        }
    }

    private func segmentColor(after index: Int) -> Color {
        guard progress > 1 else {
            return .clear
        }
        return index < progress
            ? OnboardingPalette.proofGreen
            : OnboardingPalette.academicInk.opacity(0.18)
    }
}
