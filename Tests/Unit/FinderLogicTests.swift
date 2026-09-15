//
//  FinderLogicTests.swift
//
//  Covers the pure logic behind the finder — no CoreBluetooth, no device.
//

import XCTest
@testable import TheSwiftKit

final class ProximityLevelTests: XCTestCase {
    func testBucketsCoverTheUsefulRange() {
        XCTAssertEqual(ProximityLevel(rssi: -40), .veryClose)
        XCTAssertEqual(ProximityLevel(rssi: -55), .veryClose)
        XCTAssertEqual(ProximityLevel(rssi: -56), .close)
        XCTAssertEqual(ProximityLevel(rssi: -70), .close)
        XCTAssertEqual(ProximityLevel(rssi: -71), .nearby)
        XCTAssertEqual(ProximityLevel(rssi: -85), .nearby)
        XCTAssertEqual(ProximityLevel(rssi: -86), .far)
        XCTAssertEqual(ProximityLevel(rssi: -120), .far)
    }

    func testIntensityIncreasesWithCloseness() {
        XCTAssertTrue(ProximityLevel.far.intensity < ProximityLevel.nearby.intensity)
        XCTAssertTrue(ProximityLevel.nearby.intensity < ProximityLevel.close.intensity)
        XCTAssertTrue(ProximityLevel.close.intensity < ProximityLevel.veryClose.intensity)
    }
}

final class RSSISmootherTests: XCTestCase {
    func testIgnoresUnavailableReadings() {
        var smoother = RSSISmoother()
        smoother.add(127)   // CoreBluetooth's "no value" sentinel
        XCTAssertNil(smoother.smoothedRSSI)
        XCTAssertEqual(smoother.sampleCount, 0)
    }

    func testFirstSampleSeedsBothAverages() {
        var smoother = RSSISmoother()
        smoother.add(-60)
        XCTAssertEqual(smoother.smoothedRSSI, -60)
        XCTAssertEqual(smoother.proximity, .close)
    }

    func testStaysSteadyUntilEnoughSamples() {
        var smoother = RSSISmoother()
        smoother.add(-90)
        smoother.add(-50)
        XCTAssertEqual(smoother.trend, .steady, "A trend from two samples would be noise, not movement.")
    }

    func testReportsWarmerAsSignalStrengthens() {
        var smoother = RSSISmoother()
        for _ in 0..<5 { smoother.add(-85) }
        for _ in 0..<5 { smoother.add(-55) }
        XCTAssertEqual(smoother.trend, .warmer)
    }

    func testReportsColderAsSignalWeakens() {
        var smoother = RSSISmoother()
        for _ in 0..<5 { smoother.add(-55) }
        for _ in 0..<5 { smoother.add(-85) }
        XCTAssertEqual(smoother.trend, .colder)
    }

    func testSmallJitterDoesNotReadAsMovement() {
        var smoother = RSSISmoother()
        let jitter = [-70, -71, -69, -70, -71, -69, -70, -70]
        jitter.forEach { smoother.add($0) }
        XCTAssertEqual(smoother.trend, .steady)
    }

    func testResetClearsState() {
        var smoother = RSSISmoother()
        for _ in 0..<5 { smoother.add(-60) }
        smoother.reset()
        XCTAssertNil(smoother.smoothedRSSI)
        XCTAssertEqual(smoother.trend, .steady)
    }
}

final class HeadphoneHeuristicTests: XCTestCase {
    func testMatchesCommonHeadphoneNames() {
        XCTAssertTrue(HeadphoneHeuristic.looksLikeHeadphones(name: "Sam's AirPods Pro"))
        XCTAssertTrue(HeadphoneHeuristic.looksLikeHeadphones(name: "WH-1000XM5"))
        XCTAssertTrue(HeadphoneHeuristic.looksLikeHeadphones(name: "Galaxy Buds2"))
        XCTAssertTrue(HeadphoneHeuristic.looksLikeHeadphones(name: "beats studio"))
    }

    func testIgnoresUnrelatedPeripherals() {
        XCTAssertFalse(HeadphoneHeuristic.looksLikeHeadphones(name: "Living Room TV"))
        XCTAssertFalse(HeadphoneHeuristic.looksLikeHeadphones(name: ""))
    }
}

final class LeftBehindPromptPolicyTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "LeftBehindPromptPolicyTests")!
        defaults.removePersistentDomain(forName: "LeftBehindPromptPolicyTests")
    }

    func testStaysQuietUntilTheAppHasProvedItself() {
        XCTAssertFalse(LeftBehindPromptPolicy.registerFindAndShouldPrompt(isSubscribed: false, defaults: defaults))
        XCTAssertTrue(LeftBehindPromptPolicy.registerFindAndShouldPrompt(isSubscribed: false, defaults: defaults))
    }

    func testNeverPromptsAnExistingSubscriber() {
        for _ in 0..<5 {
            XCTAssertFalse(LeftBehindPromptPolicy.registerFindAndShouldPrompt(isSubscribed: true, defaults: defaults))
        }
    }

    func testRespectsCooldownAfterAnOffer() {
        _ = LeftBehindPromptPolicy.registerFindAndShouldPrompt(isSubscribed: false, defaults: defaults)
        XCTAssertTrue(LeftBehindPromptPolicy.registerFindAndShouldPrompt(isSubscribed: false, defaults: defaults))
        XCTAssertFalse(LeftBehindPromptPolicy.registerFindAndShouldPrompt(isSubscribed: false, defaults: defaults),
                       "A declined offer should not come back on the very next find.")
    }
}
