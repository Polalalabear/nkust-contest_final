import SwiftUI
import MapKit

struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab: DashboardTab = .summary

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("主控台", systemImage: "heart.fill", value: .summary) {
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

// MARK: - Summary

struct SummaryView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DashboardViewModel()
    @State private var showProfile = false
    @State private var stepsChartStyle: ChartStyle = .bar
    @State private var distanceChartStyle: ChartStyle = .bar
    @State private var standingChartStyle: ChartStyle = .bar

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    actionButtons
                    quickCallButton

                    NavigationLink {
                        HealthDetailView(
                            metric: .steps,
                            records: DailyHealthRecord.mockThreeMonths()
                        )
                    } label: {
                        healthCardWithChart(
                            icon: "figure.walk",
                            title: "行走步數",
                            value: "\(viewModel.todaySteps)",
                            unit: "步",
                            metric: .steps,
                            chartStyle: $stepsChartStyle
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        HealthDetailView(
                            metric: .distance,
                            records: DailyHealthRecord.mockThreeMonths()
                        )
                    } label: {
                        healthCardWithChart(
                            icon: "map",
                            title: "行走距離",
                            value: String(format: "%.1f", viewModel.todayDistance),
                            unit: "公里",
                            metric: .distance,
                            chartStyle: $distanceChartStyle
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        HealthDetailView(
                            metric: .standing,
                            records: DailyHealthRecord.mockThreeMonths()
                        )
                    } label: {
                        healthCardWithChart(
                            icon: "figure.stand",
                            title: "站立分鐘數",
                            value: "\(viewModel.todayStanding)",
                            unit: "分鐘",
                            metric: .standing,
                            chartStyle: $standingChartStyle
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        AllHealthDataView()
                    } label: {
                        allHealthDataLink
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
            .navigationTitle("照護者主控台")
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

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                viewModel.fetchVisUserLocation()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("一鍵取得即時位置")
                            .font(.headline)
                            .fontWeight(.semibold)
                        if appState.isLocationSharing {
                            Text("位置分享已開啟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("位置分享未開啟")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } icon: {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.blue.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.blue.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(!appState.isLocationSharing)
            .opacity(appState.isLocationSharing ? 1 : 0.6)
            .accessibilityLabel("一鍵取得視障者即時位置")

            Button {
                viewModel.showNearestHospital()
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("最近醫院")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Text("顯示距離視障者最近的醫院")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "cross.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.red.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.red.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("顯示距離視障者最近醫院")
        }
    }

    // MARK: - Quick Call

    private var quickCallButton: some View {
        Button {
            viewModel.callUser()
        } label: {
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

    // MARK: - Health Card + Chart

    private func healthCardWithChart(
        icon: String,
        title: String,
        value: String,
        unit: String,
        metric: HealthMetric,
        chartStyle: Binding<ChartStyle>
    ) -> some View {
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
            }

            HealthChartView(
                records: viewModel.weekRecords,
                metric: metric,
                chartStyle: chartStyle
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
    }

    // MARK: - All Health Link

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

// MARK: - Profile Sheet

struct ProfileSheetView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false

    var body: some View {
        @Bindable var state = appState
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.gray)
                        VStack(alignment: .leading, spacing: 4) {
                            if isEditing {
                                TextField("姓名", text: $state.caregiverName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            } else {
                                Text(appState.caregiverName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            Text("caregiver@example.com")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("個人資料") {
                    if isEditing {
                        HStack {
                            Text("姓名")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("姓名", text: $state.caregiverName)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("關係")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("關係", text: $state.caregiverRelationship)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("緊急聯絡電話")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("電話", text: $state.caregiverEmergencyPhone)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.phonePad)
                        }
                    } else {
                        LabeledContent("姓名", value: appState.caregiverName)
                        LabeledContent("關係", value: appState.caregiverRelationship)
                        LabeledContent("緊急聯絡電話", value: appState.caregiverEmergencyPhone)
                    }
                }

                Section("裝置資訊") {
                    LabeledContent("裝置連線", value: appState.deviceConnected ? "已連接" : "未連接")
                    LabeledContent("裝置電量", value: "\(appState.deviceBattery) %")
                    LabeledContent("手機電量", value: "\(appState.phoneBattery) %")
                    LabeledContent("定位分享", value: appState.isLocationSharing ? "開啟" : "關閉")
                }

                Section("關於") {
                    LabeledContent("版本", value: AppState.appVersion)
                    LabeledContent("建置", value: AppState.buildDate)
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
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "完成" : "編輯") {
                        withAnimation { isEditing.toggle() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environment(AppState())
}
