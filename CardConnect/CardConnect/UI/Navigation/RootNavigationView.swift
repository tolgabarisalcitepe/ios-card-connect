// RootNavigationView.swift
// CardConnect

import SwiftUI

struct RootNavigationView: View {
    @AppStorage("onboarding_done") private var onboardingDone = false
    @State private var path = NavigationPath()
    @Environment(\.dependencies) private var dependencies

    var body: some View {
        if onboardingDone {
            NavigationStack(path: $path) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { destination(for: $0) }
            }
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-UITestMockOCR") else { return }
                var card = ParsedCard()
                card.firstName = "Test"
                card.lastName = "Kullanıcı"
                await dependencies.scanFlow.setParsedCard(card)
                path.append(AppRoute.confirm)
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
        case .duplicate(_):
            // Note: existing/incoming Contact objects fetched by DuplicateViewModel in Epic 2
            // Placeholder until ContactStore is available
            Text("Duplikat görünümü Epic 2 sonrası aktif olacak")
                .foregroundStyle(.secondary)
        case .eventMatch(let id):
            Text("EventMatchView — Epic 4: \(id)")
        case .detail(let id):
            Text("DetailView — Epic 2 #96: \(id)")
        }
    }
}
