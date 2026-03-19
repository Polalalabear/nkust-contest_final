import SwiftUI

struct LTCModeView: View {
    @StateObject private var viewModel = LTCModeViewModel()

    var body: some View {
        List(viewModel.contacts) { contact in
            Text(contact.name)
                .accessibilityLabel("Contact \(contact.name)")
        }
        .accessibilityLabel("LTC contact list")
    }
}
