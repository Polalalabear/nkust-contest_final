import SwiftUI
import UIKit

struct CameraPreviewPlaceholder: View {
    var frame: UIImage? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let frame {
                    Image(uiImage: frame)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.gray.opacity(0.3), .gray.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: geo.size.width, height: geo.size.height)
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.white.opacity(0.15))
                        }
                        .clipped()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}
