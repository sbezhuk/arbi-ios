import SwiftUI

struct PersistenceFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Arbi data is temporarily unavailable", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(message)
            Text("The existing local database was preserved. Please restart Arbi or contact support.")
        }
    }
}
