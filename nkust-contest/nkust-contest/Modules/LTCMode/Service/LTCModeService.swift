import Foundation

protocol LTCModeServicing {
    func fetchContacts() -> [Contact]
    func call(contact: Contact)
}

final class StubLTCModeService: LTCModeServicing {
    func fetchContacts() -> [Contact] {
        // TODO: load contacts from local data source
        return [
            Contact(id: UUID(), name: "Caregiver A"),
            Contact(id: UUID(), name: "Caregiver B")
        ]
    }

    func call(contact: Contact) {
        // TODO: integrate call flow
        _ = contact
    }
}
