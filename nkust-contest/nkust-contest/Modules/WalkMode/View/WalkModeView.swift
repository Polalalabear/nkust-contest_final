import SwiftUI

struct WalkModeView: View {
    @StateObject private var viewModel = WalkModeViewModel()

    var body: some View {
        VStack {
            VStack(spacing: 8) {
                Text("Connection: \(viewModel.connectionStatus)")
                Text("Battery: \(viewModel.batteryLevel)")
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Status bar")

            Spacer()

            Button("Main Button") {
                viewModel.handleSingleTap()
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Main control button")
            .onTapGesture(count: 2) {
                viewModel.handleDoubleTap()
            }
            .onLongPressGesture(minimumDuration: 1.0) {
                viewModel.handleLongPress()
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 2.5)
                    .onEnded { _ in
                        viewModel.handleVeryLongPress()
                    }
            )

            Spacer()

            Text("Walk Mode")
                .accessibilityLabel("Mode indicator Walk Mode")
        }
        .padding()
    }
}
