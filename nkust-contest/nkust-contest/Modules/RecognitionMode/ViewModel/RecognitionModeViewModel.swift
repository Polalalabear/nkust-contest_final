import Foundation
import Combine

final class RecognitionModeViewModel: ObservableObject {
    @Published var showOverlay: Bool = false
    @Published var overlayMessage: String = ""

    private let service: RecognitionModeServicing

    init(service: RecognitionModeServicing = StubRecognitionModeService()) {
        self.service = service
    }

    func requestRecognition() async {
        let message = await service.recognizeCurrentFrame()
        overlayMessage = message
        showOverlay = !message.isEmpty
    }
}
