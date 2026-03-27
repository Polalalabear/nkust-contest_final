import SwiftUI
import UIKit

struct BlindModeGestureOverlay: UIViewRepresentable {
    let onReplay: () -> Void
    let onToggleVoice: () -> Void

    func makeUIView(context: Context) -> GestureCaptureView {
        let view = GestureCaptureView()
        view.backgroundColor = .clear
        view.onReplay = onReplay
        view.onToggleVoice = onToggleVoice
        return view
    }

    func updateUIView(_ uiView: GestureCaptureView, context: Context) {
        uiView.onReplay = onReplay
        uiView.onToggleVoice = onToggleVoice
    }
}

final class GestureCaptureView: UIView {
    var onReplay: (() -> Void)?
    var onToggleVoice: (() -> Void)?

    private lazy var doubleTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleReplayTap(_:)))
        recognizer.numberOfTouchesRequired = 1
        recognizer.numberOfTapsRequired = 2
        recognizer.cancelsTouchesInView = false
        return recognizer
    }()

    private lazy var tripleTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleToggleVoiceTap(_:)))
        recognizer.numberOfTouchesRequired = 1
        recognizer.numberOfTapsRequired = 3
        recognizer.cancelsTouchesInView = false
        return recognizer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        addGestureRecognizer(doubleTapRecognizer)
        addGestureRecognizer(tripleTapRecognizer)
        doubleTapRecognizer.require(toFail: tripleTapRecognizer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleReplayTap(_ recognizer: UITapGestureRecognizer) {
        guard shouldHandleTap(in: recognizer) else { return }
        onReplay?()
    }

    @objc private func handleToggleVoiceTap(_ recognizer: UITapGestureRecognizer) {
        guard shouldHandleTap(in: recognizer) else { return }
        onToggleVoice?()
    }

    private func shouldHandleTap(in recognizer: UITapGestureRecognizer) -> Bool {
        let point = recognizer.location(in: self)
        return point.y >= bounds.height / 3.0
    }
}
