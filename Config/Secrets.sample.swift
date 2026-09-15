//
//  Secrets.sample.swift
//  Duplicate to Secrets.swift and fill in values.
//

import Foundation

// This sample is a template and should not compile into the app by default.
// If you want to build using the sample values, add `USE_SAMPLE_SECRETS` to
// your target's Swift Compiler - Custom Flags (Other Swift Flags): `-D USE_SAMPLE_SECRETS`.
#if USE_SAMPLE_SECRETS
public enum Secrets {
    // TelemetryDeck (analytics). Empty = analytics disabled.
    public static let telemetryDeckAppID: String = ""

    // RevenueCat public API key. Empty = the app runs on the local purchase
    // stub, which unlocks nothing but lets every screen be exercised.
    public static let revenueCatAPIKey: String = ""
}
#endif
