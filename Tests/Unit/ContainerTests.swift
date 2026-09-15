//
//  ContainerTests.swift
//

import XCTest
@testable import FindMyHeadphones

final class ContainerTests: XCTestCase {
    func testContainerBuilds() throws {
        let container = DIContainer.makeDefault()
        XCTAssertNotNil(container.purchasesService as Any)
        XCTAssertNotNil(container.analytics as Any)
        XCTAssertEqual(container.config.appName.isEmpty, false)
    }

    func testEntitlementIdentifiersMatchStoreProducts() {
        // These strings are configured in RevenueCat; a typo here silently
        // locks paying customers out of what they bought.
        XCTAssertEqual(AppEntitlement.radarUnlock.rawValue, "radar_unlock")
        XCTAssertEqual(AppEntitlement.leftBehindAlerts.rawValue, "left_behind_alerts")
        XCTAssertEqual(AppEntitlement.radarUnlock.offeringIdentifier, "radar_unlock")
    }
}
