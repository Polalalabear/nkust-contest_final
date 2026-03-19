import SwiftUI
import Observation

@Observable
final class RecognitionModeViewModel {
    var isSuccess: Bool = false
    var resultDescription: String = ""
    var useDeviceCamera: Bool = true

    private let service: RecognitionModeServicing

    init(service: RecognitionModeServicing = StubRecognitionModeService()) {
        self.service = service
    }

    func requestRecognition() async {
        let message = await service.recognizeCurrentFrame()
        resultDescription = message
        isSuccess = !message.isEmpty
    }
}
