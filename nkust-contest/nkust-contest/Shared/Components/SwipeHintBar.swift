import SwiftUI

struct SwipeHintBar: View {
    let leftHint: String
    let rightHint: String

    var body: some View {
        VStack(spacing: 4) {
            Text(leftHint)
            Text(rightHint)
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.gray.opacity(0.7))
        )
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("滑動提示：\(leftHint)，\(rightHint)")
    }
}
