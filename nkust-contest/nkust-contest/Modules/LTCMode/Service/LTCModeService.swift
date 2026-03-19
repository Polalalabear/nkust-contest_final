import Foundation

struct Contact: Identifiable {
    let id: UUID
    let name: String
}

protocol LTCModeServicing {
    func fetchContacts() -> [Contact]
    func call(contact: Contact)
}

final class StubLTCModeService: LTCModeServicing {
    func fetchContacts() -> [Contact] {
        // TODO: load contacts from local data source
        [
            Contact(id: UUID(), name: "媽媽"),
            Contact(id: UUID(), name: "爸爸"),
            Contact(id: UUID(), name: "爺爺"),
            Contact(id: UUID(), name: "奶奶"),
            Contact(id: UUID(), name: "叔叔")
        ]
    }

    func call(contact: Contact) {
        // TODO: integrate call flow
        _ = contact
    }
}
