//
//  StoredItem.swift
//
//  PRO feature — offline-first persistence with SwiftData (how OverglowAI &
//  Humanit store streaks, history & progress).
//
//  Self-contained: delete `Modules/SwiftDataStore` + flip
//  `featureFlags.swiftDataStore` off to remove.
//
//  NOTE: SwiftData is iOS 17+. The kit's deployment target is iOS 16, so this
//  module is gated with `@available(iOS 17, *)`. If you raise the deployment
//  target to 17, you can drop the availability annotations.
//

import Foundation
import SwiftData

@available(iOS 17, *)
@Model
final class StoredItem {
    var title: String
    var detail: String
    var isDone: Bool
    var createdAt: Date

    init(title: String, detail: String = "", isDone: Bool = false) {
        self.title = title
        self.detail = detail
        self.isDone = isDone
        self.createdAt = Date()
    }
}
