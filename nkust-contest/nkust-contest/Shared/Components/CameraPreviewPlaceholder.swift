import SwiftUI
import UIKit

struct CameraPreviewPlaceholder: View {
    var frame: UIImage? = nil

    var body: some View {
        Group {
            if let frame {
                Image(uiImage: frame)
                    .resizable()
                    .scaledToFill()
            } else {
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
            }
        }
        .ignoresSafeArea()
    }
}
