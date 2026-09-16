//
//  FinderLogicTests.swift
//
//  Covers the pure logic behind the finder — no CoreBluetooth, no device.
//

import XCTest
import SwiftUI
@testable import FindMyHeadphones

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

final class TemperatureRampTests: XCTestCase {
    private func components(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    func testEndsAreBlueAndRed() {
        let cold = components(DS.Colors.temperature(0))
        XCTAssertGreaterThan(cold.b, cold.r, "The weakest signal must read as blue.")

        let hot = components(DS.Colors.temperature(1))
        XCTAssertGreaterThan(hot.r, hot.b, "The strongest signal must read as red.")
    }

    func testRampNeverPassesThroughPurple() {
        // The bug this guards: interpolating blue straight to red in RGB runs
        // through magenta, putting purple — neither hot nor cold — in the
        // middle of the range. Purple means high red AND high blue at once.
        for step in 0...20 {
            let t = Double(step) / 20
            let c = components(DS.Colors.temperature(t))
            XCTAssertFalse(c.r > 0.5 && c.b > 0.5,
                           "t=\(t) is purple: r=\(c.r) b=\(c.b)")
        }
    }

    func testWarmsMonotonically() {
        // Red should only ever climb, and blue only ever fall, as signal grows.
        var lastRed: CGFloat = -1
        var lastBlue: CGFloat = 2
        for step in 0...20 {
            let c = components(DS.Colors.temperature(Double(step) / 20))
            XCTAssertGreaterThanOrEqual(c.r, lastRed - 0.01)
            XCTAssertLessThanOrEqual(c.b, lastBlue + 0.01)
            lastRed = c.r
            lastBlue = c.b
        }
    }

    func testClampsOutOfRangeInput() {
        XCTAssertEqual(components(DS.Colors.temperature(-5)).b, components(DS.Colors.temperature(0)).b)
        XCTAssertEqual(components(DS.Colors.temperature(99)).r, components(DS.Colors.temperature(1)).r)
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
