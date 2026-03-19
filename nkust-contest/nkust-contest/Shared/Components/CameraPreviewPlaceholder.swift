import SwiftUI

struct CameraPreviewPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.gray.opacity(0.3), .gray.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white.opacity(0.15))
            }
            .ignoresSafeArea()
    }
}
