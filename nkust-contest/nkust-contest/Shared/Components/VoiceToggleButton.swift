import SwiftUI

struct VoiceToggleButton: View {
    @Binding var isEnabled: Bool

    var body: some View {
        Button {
            isEnabled.toggle()
        } label: {
            Image(systemName: isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(isEnabled ? .green : .pink)
                .frame(width: 48, height: 48)
                .background(
                    Circle()
                        .stroke(isEnabled ? .green : .pink, lineWidth: 2.5)
                )
        }
        .accessibilityLabel(isEnabled ? "語音已開啟" : "語音已關閉")
    }
}
