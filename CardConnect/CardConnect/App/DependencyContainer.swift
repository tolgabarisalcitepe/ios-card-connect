// DependencyContainer.swift
// CardConnect

import SwiftUI

// MARK: - Protocol

protocol DependencyContainer {
    var userProfileStore: UserProfileStore { get }
    var scanFlow: ScanFlowActor { get }
    var permissionCoordinator: PermissionCoordinator { get }
    // contactStore — Epic 2'de eklenir
}

// MARK: - Live Implementation

final class LiveDependencyContainer: DependencyContainer {
    let userProfileStore: UserProfileStore
    let scanFlow: ScanFlowActor
    let permissionCoordinator: PermissionCoordinator

    init() {
        self.userProfileStore = UserProfileStore()
        self.scanFlow = ScanFlowActor()
        self.permissionCoordinator = PermissionCoordinator()
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
