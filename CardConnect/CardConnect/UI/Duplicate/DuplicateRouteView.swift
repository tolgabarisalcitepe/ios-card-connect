import SwiftUI
import SwiftData

/// `.duplicate` route'unu gerçek Contact nesnelerine çözer.
struct DuplicateRouteView: View {
    let existingContactID: UUID
    @Environment(\.dependencies) private var dependencies
    @Query private var contacts: [Contact]

    init(existingContactID: UUID) {
        self.existingContactID = existingContactID
        _contacts = Query(filter: #Predicate { $0.id == existingContactID })
    }

    var body: some View {
        Group {
            if let existing = contacts.first {
                IncomingContactWrapper(existing: existing)
            } else {
                ContentUnavailableView(
                    "Kişi bulunamadı",
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
            }
        }
    }
}

// MARK: - IncomingContactWrapper

private struct IncomingContactWrapper: View {
    let existing: Contact
    @Environment(\.dependencies) private var dependencies
    @State private var incoming: Contact?

    var body: some View {
        Group {
            if let incoming {
                DuplicateView(existing: existing, incoming: incoming)
            } else {
                ProgressView()
                    .task {
                        incoming = await dependencies.scanFlow.incomingContact
                    }
            }
        }
    }
}
