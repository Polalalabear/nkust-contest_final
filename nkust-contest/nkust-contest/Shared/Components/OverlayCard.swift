import SwiftUI

struct OverlayCard<Icon: View>: View {
    let backgroundColor: Color
    let icon: Icon
    let iconLabel: String
    let title: String
    var subtitle: String = ""

    init(
        backgroundColor: Color,
        iconLabel: String,
        title: String,
        subtitle: String = "",
        @ViewBuilder icon: () -> Icon
    ) {
        self.backgroundColor = backgroundColor
        self.iconLabel = iconLabel
        self.title = title
        self.subtitle = subtitle
        self.icon = icon()
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                icon
                    .font(.title2)
                    .foregroundStyle(.white)
                Text(iconLabel)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: 50)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundStyle(.white)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(backgroundColor.opacity(0.85))
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(iconLabel) \(title) \(subtitle)")
    }
}
