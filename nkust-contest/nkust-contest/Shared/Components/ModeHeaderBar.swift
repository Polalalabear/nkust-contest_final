import SwiftUI

struct ModeHeaderBar: View {
    let title: String
    @Binding var isVoiceEnabled: Bool
    var onBack: (() -> Void)?

    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.gray.opacity(0.6)))
                }
                .accessibilityLabel("返回")
            }

            Spacer()

            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.black.opacity(0.5))
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )

            Spacer()

            VoiceToggleButton(isEnabled: $isVoiceEnabled)
        }
        .padding(.horizontal)
    }
}
