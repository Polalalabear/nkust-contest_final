import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 200)
                .overlay(Text("Live Camera Feed"))

            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 160)
                .overlay(Text("Map Placeholder"))

            HStack {
                Button("Call") {
                    viewModel.callUser()
                }
                Button("Send Voice Message") {
                    viewModel.sendVoiceMessage()
                }
                Button("View Logs") {
                    viewModel.viewLogs()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .accessibilityLabel("Caregiver dashboard")
    }
}
