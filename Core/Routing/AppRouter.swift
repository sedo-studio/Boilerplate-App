//
//  AppRouter.swift
//

import SwiftUI

public enum AppRoute: Hashable {
    /// The proximity screen. `preview` opens it as a timed glimpse for someone
    /// who hasn't bought it yet — the paywall then slides up over the top.
    case radar(preview: Bool)
}

@MainActor
public final class AppRouter: ObservableObject {
    @Published public var path: NavigationPath = .init()

    public init() {}

    public func reset() { path.removeLast(path.count) }
    public func push(_ route: AppRoute) { path.append(route) }
    public func pop() { if !path.isEmpty { path.removeLast() } }
}
