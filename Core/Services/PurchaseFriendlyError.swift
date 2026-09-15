//
//  PurchaseFriendlyError.swift
//

import Foundation

public enum PurchaseFriendlyError: Error, LocalizedError, Sendable, Equatable {
    case ownershipConflict
    case cancelled
    case notAllowed
    case network
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case .ownershipConflict:
            return NSLocalizedString("This purchase belongs to a different Apple ID. Sign in with that Apple ID and tap Restore.", comment: "")
        case .cancelled:
            return NSLocalizedString("Purchase cancelled", comment: "")
        case .notAllowed:
            return NSLocalizedString("Purchases not allowed on this device.", comment: "")
        case .network:
            return NSLocalizedString("Network error. Please try again.", comment: "")
        case .unknown(let msg):
            return msg
        }
    }
}

