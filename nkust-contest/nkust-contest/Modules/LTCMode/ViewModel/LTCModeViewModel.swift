import Foundation
import Combine

struct Contact: Identifiable {
    let id: UUID
    let name: String
}

final class LTCModeViewModel: ObservableObject {
    @Published var contacts: [Contact] = []

    private let service: LTCModeServicing

    init(service: LTCModeServicing = StubLTCModeService()) {
        self.service = service
        contacts = service.fetchContacts()
    }

    func callContact(_ contact: Contact) {
        service.call(contact: contact)
    }
}
