import SwiftUI

struct ModeHeaderBar: View {
    @Environment(AppState.self) private var appState
    let title: String
    @Binding var isVoiceEnabled: Bool
    var onBack: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
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

            HStack(spacing: 8) {
                Label(appState.effectiveDeviceConnected ? "已連線" : "尚未連線", systemImage: "wifi")
                    .foregroundStyle(appState.effectiveDeviceConnected ? .green : .red)
                Text("裝置電量 \(appState.deviceBattery)%")
                    .foregroundStyle(.white.opacity(0.85))
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.black.opacity(0.45))
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                appState.effectiveDeviceConnected
                    ? "裝置已連線，電量 \(appState.deviceBattery) 趴"
                    : "裝置尚未連線，電量 \(appState.deviceBattery) 趴"
            )
        }
    }
}
