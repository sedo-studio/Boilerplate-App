//
//  AppEvents.swift
//

import Foundation

extension Notification.Name {
    /// Posted by the purchases layer whenever entitlements may have changed.
    static let entitlementsDidChange = Notification.Name("entitlementsDidChange")
    /// Posted when the tracked headphones connect to this device.
    static let headphonesDidConnect = Notification.Name("headphonesDidConnect")
    /// Posted when the tracked headphones disconnect from this device.
    /// `Modules/LeftBehind` listens for this to arm a "left behind" alert.
    static let headphonesDidDisconnect = Notification.Name("headphonesDidDisconnect")
}

/// Keys for the `headphonesDidConnect` / `headphonesDidDisconnect` payloads.
public enum HeadphoneEventKey {
    public static let deviceId = "deviceId"     // String (CBPeripheral identifier)
    public static let deviceName = "deviceName" // String
}
