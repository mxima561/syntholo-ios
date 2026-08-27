import SwiftUI

struct FeatureHomeScaffold: View {
    let title: LocalizedStringKey
    let headline: LocalizedStringKey
    let bodyText: LocalizedStringKey
    let systemImage: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Label(headline, systemImage: systemImage)
                        .font(SyntholoTextStyle.pageTitle)
                    Text(bodyText)
                        .font(SyntholoTextStyle.body)
                        .foregroundStyle(SyntholoColor.secondaryInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Layout.pageInset)
            }
            .background(SyntholoColor.canvas)
            .navigationTitle(title)
        }
    }
}
