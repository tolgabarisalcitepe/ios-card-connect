// RootNavigationView.swift
// CardConnect

import SwiftUI

struct RootNavigationView: View {
    @AppStorage("onboarding_done") private var onboardingDone = false
    @State private var path = NavigationPath()

    var body: some View {
        if onboardingDone {
            NavigationStack(path: $path) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { destination(for: $0) }
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
            Text("CameraView — Epic 1")
        case .confirm:
            Text("ConfirmView — Epic 1")
        case .duplicate(let id):
            Text("DuplicateView — Epic 3: \(id)")
        case .eventMatch(let id):
            Text("EventMatchView — Epic 4: \(id)")
        }
    }
}
