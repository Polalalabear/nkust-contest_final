import SwiftUI

@MainActor
struct WalkModeView: View {
    @Environment(AppState.self) private var appState
    @Binding var isVoiceEnabled: Bool
    var onBack: (() -> Void)?
    @State private var viewModel = WalkModeViewModel()

    var body: some View {
        ZStack {
            CameraPreviewPlaceholder(frame: viewModel.latestFrame)

            VStack(spacing: 12) {
                ModeHeaderBar(
                    title: "行走模式",
                    isVoiceEnabled: $isVoiceEnabled,
                    onBack: onBack
                )
                .padding(.top, 54)

                if viewModel.trafficLight.isRed {
                    trafficLightCard
                } else if !viewModel.obstacle.description.isEmpty {
                    obstacleCard
                }

                directionCard

                Spacer()

                SwipeHintBar(
                    leftHint: AppMode.walkMode.swipeHint.left,
                    rightHint: AppMode.walkMode.swipeHint.right
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            viewModel.syncStreaming(mode: appState.dataSourceMode, isConnected: appState.effectiveDeviceConnected)
            viewModel.refreshNavigation(voiceEnabled: isVoiceEnabled)
        }
        .onChange(of: appState.dataSourceMode) { _, mode in
            viewModel.syncStreaming(mode: mode, isConnected: appState.effectiveDeviceConnected)
        }
        .onChange(of: appState.effectiveDeviceConnected) { _, connected in
            viewModel.syncStreaming(mode: appState.dataSourceMode, isConnected: connected)
        }
        .onChange(of: isVoiceEnabled) { _, newValue in
            viewModel.refreshNavigation(voiceEnabled: newValue)
        }
        .onDisappear {
            viewModel.stopStreaming()
        }
    }

    private var obstacleCard: some View {
        OverlayCard(
            backgroundColor: .blue,
            iconLabel: "障礙",
            title: viewModel.obstacle.description,
            subtitle: "約 \(viewModel.obstacle.distance) 公尺"
        ) {
            Image(systemName: "arrow.triangle.2.circlepath")
        }
    }

    private var directionCard: some View {
        OverlayCard(
            backgroundColor: Color(white: 0.3),
            iconLabel: "方向",
            title: viewModel.direction.instruction,
            subtitle: viewModel.direction.detail
        ) {
            Image(systemName: "location.north.fill")
        }
    }

    private var trafficLightCard: some View {
        OverlayCard(
            backgroundColor: .red.opacity(0.9),
            iconLabel: "號誌",
            title: "紅燈",
            subtitle: viewModel.trafficLight.instruction
        ) {
            Image(systemName: "traffic.light.fill")
        }
    }
}

#Preview {
    WalkModeView(isVoiceEnabled: .constant(true))
}
