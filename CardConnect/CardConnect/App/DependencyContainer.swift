// DependencyContainer.swift
// CardConnect

import SwiftUI

// MARK: - Protocol

protocol DependencyContainer {
    var userProfileStore: UserProfileStore { get }
    var scanFlow: ScanFlowActor { get }
    // contactStore, permissionCoordinator — ilgili issue'larda eklenir
}

// MARK: - Live Implementation

final class LiveDependencyContainer: DependencyContainer {
    let userProfileStore: UserProfileStore
    let scanFlow: ScanFlowActor

    init() {
        self.userProfileStore = UserProfileStore()
        self.scanFlow = ScanFlowActor()
    }
}

// MARK: - @Environment Wiring

private enum DependencyContainerKey: EnvironmentKey {
    static let defaultValue: any DependencyContainer = LiveDependencyContainer()
}

extension EnvironmentValues {
    var dependencies: any DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
