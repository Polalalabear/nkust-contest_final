import SwiftUI

struct DeviceInfoView: View {
    @Environment(AppState.self) private var appState
    @Binding var isVoiceEnabled: Bool
    var onBack: () -> Void
    var onStart: () -> Void
    var onReconnect: (() -> Void)?

    var body: some View {
        ZStack {
            Color(white: 0.12).ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                    .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 20) {
                        deviceCard
                        phoneCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                Spacer()

                Button {
                    attemptStart()
                } label: {
                    Text("點擊任意處開始啟動辨識")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding(.bottom, 20)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            attemptStart()
        }
        .onAppear {
            ConnectionStatusAnnouncer.shared.notifyIfDisconnected(
                screenID: "device_info",
                isConnected: appState.effectiveDeviceConnected,
                voiceEnabled: isVoiceEnabled
            )
        }
        .onChange(of: appState.effectiveDeviceConnected) { _, connected in
            ConnectionStatusAnnouncer.shared.notifyIfDisconnected(
                screenID: "device_info",
                isConnected: connected,
                voiceEnabled: isVoiceEnabled
            )
        }
        .onChange(of: isVoiceEnabled) { _, voiceEnabled in
            ConnectionStatusAnnouncer.shared.notifyIfDisconnected(
                screenID: "device_info",
                isConnected: appState.effectiveDeviceConnected,
                voiceEnabled: voiceEnabled
            )
        }
        .onDisappear {
            ConnectionStatusAnnouncer.shared.stopReminders(screenID: "device_info")
            VoiceAnnouncementCenter.shared.stopAll()
        }
    }

    private var headerBar: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.gray.opacity(0.5)))
            }
            .accessibilityLabel("返回")

            Spacer()

            VoiceToggleButton(isEnabled: $isVoiceEnabled)
        }
        .padding(.horizontal)
    }

    private func attemptStart() {
        guard appState.effectiveDeviceConnected else {
            ConnectionStatusAnnouncer.shared.notifyIfDisconnected(
                screenID: "device_info",
                isConnected: false,
                voiceEnabled: isVoiceEnabled
            )
            return
        }
        onStart()
    }

    private var deviceCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: "wifi")
                    .font(.system(size: 44))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 2) {
                    Text("裝置連接")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(connectionStatusText)
                        .font(.title)
                        .fontWeight(.black)
                        .foregroundStyle(connectionStatusColor)
                }
            }

            Text("(請開起 wifi 功能)")
                .font(.caption)
                .foregroundStyle(.gray)

            if !appState.effectiveDeviceConnected && appState.dataSourceMode == .live {
                Button {
                    onReconnect?()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("重新連線")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(.blue))
                }
                .accessibilityLabel("重新連線")
                .padding(.top, 4)
            }

            Divider().background(.gray)

            batterySection(
                title: "裝置電量",
                percent: appState.deviceBattery,
                hours: max(1, appState.deviceBattery / 30)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.gray.opacity(0.5), lineWidth: 1.5)
        )
    }

    private var phoneCard: some View {
        VStack(spacing: 16) {
            batterySection(
                title: "手機電量",
                percent: appState.phoneBattery,
                hours: max(1, appState.phoneBattery / 20)
            )

            HStack {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                Text("分享定位")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Spacer()
                @Bindable var state = appState
                Toggle("", isOn: $state.isLocationSharing)
                    .labelsHidden()
                    .tint(.green)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.gray.opacity(0.5), lineWidth: 1.5)
        )
    }

    private func batterySection(title: String, percent: Int, hours: Int) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                Image(systemName: "battery.50percent")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
                Text("\(percent) %")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text("(剩餘使用時間約 \(hours) 小時)")
                .font(.caption)
                .foregroundStyle(.gray)

            ProgressView(value: Double(percent), total: 100)
                .tint(batteryColor(percent))
                .scaleEffect(y: 2)
                .clipShape(Capsule())
        }
    }

    private var connectionStatusText: String {
        if appState.dataSourceMode == .live {
            switch appState.liveStreamHealthState {
            case .connecting: return "連線中..."
            case .connected: return "已連接"
            case .stale: return "訊號不穩"
            case .disconnected: return "未連接"
            }
        }
        return appState.effectiveDeviceConnected ? "已連接" : "未連接"
    }

    private var connectionStatusColor: Color {
        if appState.dataSourceMode == .live {
            switch appState.liveStreamHealthState {
            case .connected: return .green
            case .connecting: return .yellow
            case .stale: return .orange
            case .disconnected: return .red
            }
        }
        return appState.effectiveDeviceConnected ? .green : .red
    }

    private func batteryColor(_ percent: Int) -> Color {
        if percent > 50 { return .green }
        if percent > 20 { return .yellow }
        return .red
    }
}

#Preview {
    DeviceInfoView(isVoiceEnabled: .constant(true), onBack: {}, onStart: {}, onReconnect: {})
        .environment(AppState())
}
