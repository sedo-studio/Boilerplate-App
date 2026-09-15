//
//  AppRouter.swift
//

import SwiftUI

public enum AppRoute: Hashable {
    /// The paid proximity screen. Reached from the finder once the radar is
    /// unlocked; the paywall is presented as a sheet rather than a route.
    case radar
}

@MainActor
public final class AppRouter: ObservableObject {
    @Published public var path: NavigationPath = .init()

    public init() {}

    public func reset() { path.removeLast(path.count) }
    public func push(_ route: AppRoute) { path.append(route) }
}
