// DependencyContainer.swift
// CardConnect

import SwiftUI

// MARK: - Protocol

protocol DependencyContainer {
    var userProfileStore: UserProfileStore { get }
    // contactStore, scanFlow, permissionCoordinator — ilgili issue'larda eklenir
}

// MARK: - Live Implementation

final class LiveDependencyContainer: DependencyContainer {
    let userProfileStore: UserProfileStore

    init() {
        self.userProfileStore = UserProfileStore()
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
