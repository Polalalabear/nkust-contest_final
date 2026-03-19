import SwiftUI
import Observation

@Observable
final class LTCModeViewModel {
    var contacts: [ContactInfo] = []
    var selectedContact: ContactInfo?
    var showContactList: Bool = false
    var isCalling: Bool = false
    var currentLocation: String = "台中市 水湍市場"

    private let service: LTCModeServicing

    init(service: LTCModeServicing = StubLTCModeService()) {
        self.service = service
        let loaded = service.fetchContacts()
        self.contacts = loaded.map {
            ContactInfo(id: $0.id, name: $0.name, isAvailable: Bool.random())
        }
        self.selectedContact = contacts.first
    }

    func callContact(_ contact: ContactInfo) {
        isCalling = true
        service.call(contact: Contact(id: contact.id, name: contact.name))
    }

    func endCall() {
        isCalling = false
    }
}
