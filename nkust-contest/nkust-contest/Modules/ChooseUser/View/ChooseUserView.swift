import SwiftUI

struct ChooseUserView: View {
    @Environment(AppState.self) private var appState
    @Binding var isVoiceEnabled: Bool

    var body: some View {
        ZStack {
            Color(white: 0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                Button {
                    appState.userRole = .caregiver
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "eyes")
                            .font(.system(size: 72))
                            .foregroundStyle(.white)
                        Text("照護者")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("照護者")

                HStack {
                    DashedLine()
                    Text("點擊區塊選擇身份")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    DashedLine()
                }
                .padding(.horizontal, 24)

                Button {
                    appState.userRole = .visuallyImpaired
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 72))
                            .foregroundStyle(.white)
                        Text("視障者")
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("視障者")
            }

            VStack {
                HStack {
                    Spacer()
                    VoiceToggleButton(isEnabled: $isVoiceEnabled)
                }
                .padding(.horizontal)
                Spacer()
            }
        }
    }
}

private struct DashedLine: View {
    var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(.gray)
            .frame(height: 1)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        }
    }
}

#Preview {
    ChooseUserView(isVoiceEnabled: .constant(true))
        .environment(AppState())
}
