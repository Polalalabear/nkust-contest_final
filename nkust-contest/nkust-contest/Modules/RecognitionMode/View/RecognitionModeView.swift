import SwiftUI

@MainActor
struct RecognitionModeView: View {
    @Environment(AppState.self) private var appState
    @Binding var isVoiceEnabled: Bool
    var onBack: (() -> Void)?
    @State private var viewModel = RecognitionModeViewModel()

    var body: some View {
        ZStack {
            CameraPreviewPlaceholder()

            VStack(spacing: 12) {
                ModeHeaderBar(
                    title: "辨識模式",
                    isVoiceEnabled: $isVoiceEnabled,
                    onBack: onBack
                )
                .padding(.top, 54)

                if viewModel.isSuccess {
                    successCard
                    resultCard
                } else {
                    scanningCard
                }

                Spacer()

                if viewModel.isSuccess {
                    cameraSourcePicker
                }

                SwipeHintBar(
                    leftHint: AppMode.recognitionMode.swipeHint.left,
                    rightHint: AppMode.recognitionMode.swipeHint.right
                )
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            viewModel.syncStreaming(mode: appState.dataSourceMode, isConnected: appState.effectiveDeviceConnected)
        }
        .onChange(of: appState.dataSourceMode) { _, mode in
            viewModel.syncStreaming(mode: mode, isConnected: appState.effectiveDeviceConnected)
        }
        .onChange(of: appState.effectiveDeviceConnected) { _, connected in
            viewModel.syncStreaming(mode: appState.dataSourceMode, isConnected: connected)
        }
        .onChange(of: viewModel.useDeviceCamera) { _, _ in
            viewModel.syncStreaming(mode: appState.dataSourceMode, isConnected: appState.effectiveDeviceConnected)
        }
        .onDisappear {
            viewModel.stopStreaming()
        }
    }

    private var scanningCard: some View {
        OverlayCard(
            backgroundColor: Color(white: 0.3),
            iconLabel: "掃描",
            title: "辨識中",
            subtitle: "請持續將辨識物品擺放在鏡頭前方"
        ) {
            Image(systemName: "barcode.viewfinder")
        }
    }

    private var successCard: some View {
        OverlayCard(
            backgroundColor: .green,
            iconLabel: "完成",
            title: "辨識成功"
        ) {
            Image(systemName: "checkmark")
        }
    }

    private var resultCard: some View {
        OverlayCard(
            backgroundColor: Color(white: 0.3),
            iconLabel: "描述",
            title: "辨識結果",
            subtitle: viewModel.resultDescription
        ) {
            Image(systemName: "doc.text")
        }
    }

    private var cameraSourcePicker: some View {
        HStack(spacing: 0) {
            Text("穿戴裝置")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(viewModel.useDeviceCamera ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    viewModel.useDeviceCamera
                        ? RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.5))
                        : nil
                )
                .onTapGesture { viewModel.useDeviceCamera = true }

            Text("手機鏡頭")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(!viewModel.useDeviceCamera ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    !viewModel.useDeviceCamera
                        ? RoundedRectangle(cornerRadius: 8).fill(.gray.opacity(0.5))
                        : nil
                )
                .onTapGesture { viewModel.useDeviceCamera = false }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.black.opacity(0.4))
        )
        .padding(.horizontal, 40)
    }
}

#Preview {
    RecognitionModeView(isVoiceEnabled: .constant(true))
}
