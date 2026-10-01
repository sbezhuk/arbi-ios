import SwiftUI

struct PersistenceFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(verbatim: "Arbi data is temporarily unavailable")
            } icon: {
                Image(systemName: "externaldrive.badge.exclamationmark")
            }
        } description: {
            Text(verbatim: message)
            Text(verbatim: "The existing local database was preserved. Please restart Arbi or contact support.")
        }
    }
}
