import SwiftUI

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: DashboardTab = .summary

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("摘要", systemImage: "heart.fill", value: .summary) {
                SummaryView()
            }

            Tab("定位地圖", systemImage: "map.fill", value: .map) {
                LocationMapView()
            }
        }
    }
}

enum DashboardTab: Hashable {
    case summary
    case map
}

struct SummaryView: View {
    @Environment(AppState.self) private var appState
    @State private var showProfile = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusBar
                    quickCallButton
                    healthCard(
                        icon: "flame.fill",
                        title: "行走步數",
                        value: "3279",
                        unit: "步"
                    )
                    healthCard(
                        icon: "flame.fill",
                        title: "行走距離",
                        value: "2.7",
                        unit: "公里"
                    )
                    healthCard(
                        icon: "flame.fill",
                        title: "站立分鐘數",
                        value: "93",
                        unit: "分鐘"
                    )
                    allHealthDataLink
                }
                .padding()
            }
            .navigationTitle("摘要")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showProfile = true
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("個人資訊")
                }
            }
            .sheet(isPresented: $showProfile) {
                ProfileSheetView()
            }
        }
    }

    private var statusBar: some View {
        HStack(spacing: 0) {
            statusItem(
                icon: "wifi",
                label: "裝置連接",
                value: appState.deviceConnected ? "已連接" : "未連接",
                valueColor: appState.deviceConnected ? .green : .red
            )
            Divider().frame(height: 50)
            statusItem(
                icon: "battery.50percent",
                label: "裝置電量",
                value: "\(appState.deviceBattery) %",
                valueColor: .primary
            )
            Divider().frame(height: 50)
            statusItem(
                icon: "battery.50percent",
                label: "手機電量",
                value: "\(appState.phoneBattery) %",
                valueColor: .orange
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    private func statusItem(icon: String, label: String, value: String, valueColor: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(valueColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var quickCallButton: some View {
        Button { } label: {
            Label("快速通話", systemImage: "phone.fill")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(.green, lineWidth: 2)
                )
        }
        .accessibilityLabel("快速通話")
    }

    private func healthCard(icon: String, title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.orange)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.title)
                    .foregroundStyle(.orange.opacity(0.5))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    private var allHealthDataLink: some View {
        HStack {
            Image(systemName: "heart.fill")
                .foregroundStyle(.orange)
            Text("顯示所有健康資料")
                .font(.body)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }
}

struct ProfileSheetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.gray)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("照護者")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("caregiver@example.com")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("裝置資訊") {
                    LabeledContent("裝置連線", value: appState.deviceConnected ? "已連接" : "未連接")
                    LabeledContent("裝置電量", value: "\(appState.deviceBattery) %")
                    LabeledContent("手機電量", value: "\(appState.phoneBattery) %")
                    LabeledContent("定位分享", value: appState.isLocationSharing ? "開啟" : "關閉")
                }

                Section("關於") {
                    LabeledContent("版本", value: "1.0.0")
                    LabeledContent("建置", value: "2026.03.19")
                }

                Section {
                    Button(role: .destructive) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            appState.userRole = nil
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Label("登出", systemImage: "rectangle.portrait.and.arrow.right")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("個人資訊")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
}
