import SwiftUI
import Combine

struct RecognitionModeView: View {
    @StateObject private var viewModel = RecognitionModeViewModel()

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.1))
                .ignoresSafeArea()

            if viewModel.showOverlay {
                Text(viewModel.overlayMessage)
                    .padding()
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .accessibilityLabel("Recognition mode camera preview")
    }
}

#Preview {
    RecognitionModeView()
}
