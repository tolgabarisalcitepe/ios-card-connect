import SwiftUI
import SwiftData

/// `.duplicate` route'unu gerçek Contact nesnelerine çözer.
struct DuplicateRouteView: View {
    let existingContactID: UUID
    let onMerged: (UUID) -> Void
    let onNew: (UUID) -> Void
    @Environment(\.dependencies) private var dependencies
    @Query private var contacts: [Contact]

    init(existingContactID: UUID, onMerged: @escaping (UUID) -> Void, onNew: @escaping (UUID) -> Void) {
        self.existingContactID = existingContactID
        self.onMerged = onMerged
        self.onNew = onNew
        _contacts = Query(filter: #Predicate { $0.id == existingContactID })
    }

    var body: some View {
        Group {
            if let existing = contacts.first {
                IncomingContactWrapper(existing: existing, onMerged: onMerged, onNew: onNew)
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
    let onMerged: (UUID) -> Void
    let onNew: (UUID) -> Void
    @Environment(\.dependencies) private var dependencies
    @State private var incoming: Contact?

    var body: some View {
        Group {
            if let incoming {
                DuplicateView(existing: existing, incoming: incoming, onMerged: onMerged, onNew: onNew)
            } else {
                ProgressView()
                    .task {
                        incoming = await dependencies.scanFlow.incomingContact
                    }
            }
        }
    }
}
