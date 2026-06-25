// DependencyContainerTests.swift
// CardConnectTests

import XCTest
@testable import CardConnect

final class DependencyContainerTests: XCTestCase {

    // MARK: - Mock

    private final class MockDependencyContainer: DependencyContainer {
        let userProfileStore: UserProfileStore = UserProfileStore()
        let scanFlow: ScanFlowActor = ScanFlowActor()
        let permissionCoordinator: PermissionCoordinator = PermissionCoordinator()
    }

    // MARK: - Protocol conformance

    func testLiveDependencyContainerConformsToProtocol() {
        let container: any DependencyContainer = LiveDependencyContainer()
        XCTAssertNotNil(container.userProfileStore)
        XCTAssertNotNil(container.scanFlow)
        XCTAssertNotNil(container.permissionCoordinator)
    }

    func testMockContainerConformsToProtocol() {
        let container: any DependencyContainer = MockDependencyContainer()
        XCTAssertNotNil(container.userProfileStore)
        XCTAssertNotNil(container.scanFlow)
        XCTAssertNotNil(container.permissionCoordinator)
    }

    // MARK: - Same instance guarantee

    func testLiveContainerReturnsSameUserProfileStoreInstance() {
        let container = LiveDependencyContainer()
        XCTAssertTrue(container.userProfileStore === container.userProfileStore)
    }

    func testLiveContainerReturnsSameScanFlowInstance() {
        let container = LiveDependencyContainer()
        XCTAssertTrue(container.scanFlow === container.scanFlow)
    }

    func testLiveContainerReturnsSamePermissionCoordinatorInstance() {
        let container = LiveDependencyContainer()
        XCTAssertTrue(container.permissionCoordinator === container.permissionCoordinator)
    }
}
