// RootNavigationView.swift
// CardConnect

import SwiftUI
import SwiftData

struct RootNavigationView: View {
    @AppStorage("onboarding_done") private var onboardingDone = false
    @State private var path = NavigationPath()
    @Environment(\.dependencies) private var dependencies
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if onboardingDone {
            NavigationStack(path: $path) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { destination(for: $0) }
            }
            .task {
                if ProcessInfo.processInfo.arguments.contains("-UITestMockOCR") {
                    var card = ParsedCard()
                    card.firstName = "Test"
                    card.lastName = "Kullanıcı"
                    await dependencies.scanFlow.setParsedCard(card)
                    path.append(AppRoute.confirm)
                } else if ProcessInfo.processInfo.arguments.contains("-UITestMockDuplicate") {
                    let existing = Contact(source: .manual, firstName: "Mevcut", lastName: "Kişi", company: "ABC A.Ş.")
                    modelContext.insert(existing)
                    let incoming = Contact(source: .businessCard, firstName: "Mevcut", lastName: "Kişi", company: "Yeni A.Ş.")
                    await dependencies.scanFlow.setIncomingContact(incoming)
                    path.append(AppRoute.duplicate(contactID: existing.id))
                }
            }
        } else {
            OnboardingView {
                onboardingDone = true
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView()
        case .camera:
            CameraView(path: $path)
        case .confirm:
            ConfirmView(path: $path)
        case .duplicate(let id):
            DuplicateRouteView(
                existingContactID: id,
                onMerged: { mergedID in
                    path.removeLast()
                    path.append(AppRoute.detail(contactID: mergedID))
                },
                onNew: { newID in
                    path.removeLast()
                    path.append(AppRoute.eventMatch(contactID: newID))
                }
            )
        case .eventMatch(let id):
            EventMatchView(
                contactID: id,
                onSkip: { path = NavigationPath() },
                onMatched: {
                    path.removeLast()
                    path.append(AppRoute.detail(contactID: id))
                }
            )
        case .detail(let id):
            DetailView(contactID: id)
        case .edit(let id):
            ContactEditView(contactID: id)
        case .mailCompose(let id):
            Text("MailComposeView — Epic 5 #id: \(id)")
        }
    }
}
