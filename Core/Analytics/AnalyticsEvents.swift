//
//  AnalyticsEvents.swift
//
//  The funnel this app is measured on. Keep names stable — renaming one breaks
//  the historical series in TelemetryDeck.
//

import Foundation

public enum AnalyticsEvent {
    // Detection funnel
    public static let scanStarted = "Finder.Scan.Started"
    public static let scanFoundDevice = "Finder.Scan.Found"
    public static let scanFoundNothing = "Finder.Scan.Empty"
    public static let bluetoothDenied = "Finder.Bluetooth.Denied"
    /// The user confirmed they physically recovered the headphones.
    public static let findSucceeded = "Finder.Find.Succeeded"

    // Paywall #1 — one-time radar unlock
    public static let radarPaywallViewed = "Paywall.Radar.Viewed"
    public static let radarPaywallPurchased = "Paywall.Radar.Purchased"
    public static let radarPaywallDismissed = "Paywall.Radar.Dismissed"

    // Paywall #2 — left-behind alerts subscription (tracked separately)
    public static let alertsPaywallViewed = "Paywall.Alerts.Viewed"
    public static let alertsPaywallPurchased = "Paywall.Alerts.Purchased"
    public static let alertsPaywallDismissed = "Paywall.Alerts.Dismissed"

    // Left-behind alerts
    public static let leftBehindAlertSent = "Alerts.LeftBehind.Sent"
    public static let leftBehindEnabled = "Alerts.LeftBehind.Enabled"

    // Review prompt
    public static let reviewPrompted = "Review.Prompted"
}

public enum AnalyticsProperty {
    public static let source = "source"
    public static let proximity = "proximity"
    public static let durationSeconds = "durationSeconds"
}
