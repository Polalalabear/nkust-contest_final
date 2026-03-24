import SwiftUI
import Observation
import UIKit

@MainActor
@Observable
final class LTCModeViewModel {
    var contacts: [ContactInfo] = []
    var selectedContact: ContactInfo?
    var showContactList: Bool = false
    var isCalling: Bool = false
    var currentLocation: String = "台中市 水湍市場"
    var isUsingLiveStream: Bool = false
    var latestFrame: UIImage?
    var lastFrameReceivedAt: Date?

    private let service: LTCModeServicing
    private let streamService: StreamService
    private var isStreaming = false

    init(
        service: LTCModeServicing? = nil,
        streamService: StreamService? = nil
    ) {
        let resolvedService = service ?? StubLTCModeService()
        let resolvedStreamService = streamService ?? StreamServiceFactory.makeDefault()
        self.service = resolvedService
        self.streamService = resolvedStreamService
        let loaded = resolvedService.fetchContacts()
        self.contacts = loaded.map {
            ContactInfo(id: $0.id, name: $0.name, isAvailable: Bool.random())
        }
        self.selectedContact = contacts.first
        self.streamService.onFrame = { [weak self] frame in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleIncomingFrame(frame)
            }
        }
    }

    func callContact(_ contact: ContactInfo) {
        isCalling = true
        service.call(contact: Contact(id: contact.id, name: contact.name))
    }

    func endCall() {
        isCalling = false
    }

    func syncStreaming(mode: DataSourceMode, isConnected: Bool) {
        let shouldUseLiveStream = mode == .live && isConnected
        isUsingLiveStream = shouldUseLiveStream
        debugLog("sync streaming mode=\(mode.rawValue) connected=\(isConnected)")

        if shouldUseLiveStream {
            startStreamingIfNeeded()
        } else {
            stopStreaming()
            latestFrame = nil
        }
    }

    func stopStreaming() {
        guard isStreaming else { return }
        debugLog("stop stream")
        streamService.stop()
        isStreaming = false
    }

    private func startStreamingIfNeeded() {
        guard !isStreaming else { return }
        debugLog("start stream")
        streamService.start()
        isStreaming = true
    }

    private func handleIncomingFrame(_ frame: UIImage?) {
        guard isUsingLiveStream else { return }
        guard let frame else {
            debugLog("received nil frame")
            latestFrame = nil
            return
        }
        latestFrame = frame
        lastFrameReceivedAt = Date()
    }

    private func debugLog(_ message: String) {
        print("[LTCMode] \(message)")
    }

    deinit {
        let stream = streamService
        Task { @MainActor in
            stream.stop()
        }
    }
}
