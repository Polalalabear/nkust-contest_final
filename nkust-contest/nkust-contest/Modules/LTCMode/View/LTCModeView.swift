import SwiftUI

struct LTCModeView: View {
    @Environment(AppState.self) private var appState
    @Binding var isVoiceEnabled: Bool
    var onBack: (() -> Void)?
    @State private var viewModel = LTCModeViewModel()

    var body: some View {
        ZStack {
            CameraPreviewPlaceholder(frame: viewModel.latestFrame)

            VStack(spacing: 12) {
                ModeHeaderBar(
                    title: "長照模式",
                    isVoiceEnabled: $isVoiceEnabled,
                    onBack: onBack
                )
                .padding(.top, 54)

                locationCard

                if viewModel.isCalling {
                    Spacer()
                    endCallButton
                } else if viewModel.showContactList {
                    contactListCard
                    Spacer()
                } else {
                    Spacer()
                    callCard
                }

                if !viewModel.isCalling {
                    SwipeHintBar(
                        leftHint: AppMode.ltcMode.swipeHint.left,
                        rightHint: AppMode.ltcMode.swipeHint.right
                    )
                }

                Spacer().frame(height: 30)
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
        .onDisappear {
            viewModel.stopStreaming()
        }
    }

    private var locationCard: some View {
        OverlayCard(
            backgroundColor: Color(white: 0.35),
            iconLabel: "位置",
            title: viewModel.currentLocation,
            subtitle: "分享位置"
        ) {
            Image(systemName: "figure.walk.diamond.fill")
        }
    }

    private var callCard: some View {
        Button {
            viewModel.showContactList = true
        } label: {
            OverlayCard(
                backgroundColor: Color.brown.opacity(0.8),
                iconLabel: "電話",
                title: "撥打電話給 \(viewModel.selectedContact?.name ?? "---")",
                subtitle: "請長按螢幕五秒撥打電話"
            ) {
                Image(systemName: "phone.fill")
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 5.0)
                .onEnded { _ in
                    if let contact = viewModel.selectedContact {
                        viewModel.callContact(contact)
                    }
                }
        )
        .accessibilityLabel("撥打電話")
    }

    private var contactListCard: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.contacts) { contact in
                Button {
                    viewModel.selectedContact = contact
                    viewModel.showContactList = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.8))
                        Text(contact.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                        Text(contact.isAvailable ? "可接聽" : "不克接聽")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(contact.isAvailable ? .green : .red)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                }
                .accessibilityLabel("\(contact.name) \(contact.isAvailable ? "可接聽" : "不克接聯")")

                if contact.id != viewModel.contacts.last?.id {
                    Divider().background(.white.opacity(0.2))
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.brown.opacity(0.75))
        )
        .padding(.horizontal)
    }

    private var endCallButton: some View {
        Button {
            viewModel.endCall()
        } label: {
            Image(systemName: "phone.down.fill")
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(Circle().fill(.red))
        }
        .accessibilityLabel("結束通話")
        .padding(.bottom, 40)
    }
}

#Preview {
    LTCModeView(isVoiceEnabled: .constant(true))
}
