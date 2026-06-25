// DependencyContainerTests.swift
// CardConnectTests

import XCTest
@testable import CardConnect

final class DependencyContainerTests: XCTestCase {

    // MARK: - Mock

    private final class MockDependencyContainer: DependencyContainer {
        let userProfileStore: UserProfileStore = UserProfileStore()
    }

    // MARK: - Tests

    func testLiveDependencyContainerConformsToProtocol() {
        let container: any DependencyContainer = LiveDependencyContainer()
        XCTAssertNotNil(container.userProfileStore)
    }

    func testMockContainerConformsToProtocol() {
        let container: any DependencyContainer = MockDependencyContainer()
        XCTAssertNotNil(container.userProfileStore)
    }

    func testLiveContainerReturnsSameUserProfileStoreInstance() {
        let container = LiveDependencyContainer()
        // Her erişimde aynı instance dönmeli — yeni actor üretilmemeli
        let storeA = container.userProfileStore
        let storeB = container.userProfileStore
        XCTAssertTrue(storeA === storeB)
    }
}
