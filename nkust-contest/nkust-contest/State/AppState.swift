import Foundation
import Combine

final class AppState: ObservableObject {
    @Published var currentMode: AppMode = .walkMode
    @Published var isMuted: Bool = false
}
