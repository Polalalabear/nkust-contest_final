import SwiftUI

@MainActor
struct WalkModeView: View {
    @Environment(AppState.self) private var appState
    @Binding var isVoiceEnabled: Bool
    var onBack: (() -> Void)?
    @State private var viewModel = WalkModeViewModel()

    var body: some View {
        @Bindable var state = appState
        ZStack {
            CameraPreviewPlaceholder(frame: viewModel.latestFrame)
            if appState.showWalkDebugGrid {
                WalkDebugGridOverlay(highlightedCell: viewModel.highlightedGridCell)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

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
                modelDetectionCard

                directionCard

                Spacer()

                Toggle("顯示九宮格偵錯", isOn: $state.showWalkDebugGrid)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(.black.opacity(0.45))
                            .stroke(.white.opacity(0.25), lineWidth: 1)
                    )
                    .tint(.green)
                    .padding(.horizontal, 20)

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
            print("[WalkDebugGrid] overlay \(appState.showWalkDebugGrid ? "enabled" : "disabled")")
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
        .onChange(of: appState.showWalkDebugGrid) { _, enabled in
            print("[WalkDebugGrid] overlay \(enabled ? "enabled" : "disabled")")
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

    private var modelDetectionCard: some View {
        OverlayCard(
            backgroundColor: Color.black.opacity(0.55),
            iconLabel: "模型",
            title: "即時判斷",
            subtitle: viewModel.modelDetectionText
        ) {
            Image(systemName: "brain.head.profile")
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

private struct WalkDebugGridOverlay: View {
    let highlightedCell: WalkModeViewModel.GridCell?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let cellWidth = width / 3
            let cellHeight = height / 3
            ZStack {
                ForEach(0..<3, id: \.self) { row in
                    ForEach(0..<3, id: \.self) { col in
                        Rectangle()
                            .stroke(.white.opacity(0.22), lineWidth: 0.8)
                            .background(
                                Rectangle()
                                    .fill(highlightedCell?.row == row && highlightedCell?.col == col ? .green.opacity(0.20) : .clear)
                            )
                            .frame(width: cellWidth, height: cellHeight)
                            .position(x: cellWidth * (CGFloat(col) + 0.5), y: cellHeight * (CGFloat(row) + 0.5))
                    }
                }
            }
        }
    }
}

#Preview {
    WalkModeView(isVoiceEnabled: .constant(true))
}
