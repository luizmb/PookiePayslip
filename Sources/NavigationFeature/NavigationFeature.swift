import AppDomain
import CoreFP
import Foundation
import Observation
import SwiftRex
import SwiftRexArchitecture
import SwiftRexSwiftUI
import SwiftUI

// NavigationFeature is NOT a @Feature conformer — it manages the navigation stack only.
// The ViewModel is created manually; the behavior is lifted manually in AppCore.

public enum NavigationFeature {

    // MARK: - State

    @Lenses
    public struct State: Sendable, Equatable, Codable {
        public var path: [AppRoute]

        public init(path: [AppRoute] = []) {
            self.path = path
        }
    }

    // MARK: - Action

    @Prisms
    public enum Action: Sendable {
        case setPath([AppRoute])
        case push(AppRoute)
        case pop
        case replaceLast(AppRoute)  // update the top of the stack in-place (e.g. prev/next day)
    }

    // MARK: - Behavior (local types — lifted manually in AppCore via Navigation+Lift)

    public static func behavior() -> Behavior<Action, State, Void> {
        .handle { action, _ in
            switch action {
            case .setPath(let p):    return .reduce { $0.path = p }
            case .push(let r):       return .reduce { $0.path.append(r) }
            case .pop:               return .reduce { if !$0.path.isEmpty { $0.path.removeLast() } }
            case .replaceLast(let r): return .reduce { if !$0.path.isEmpty { $0.path[$0.path.count - 1] = r } }
            }
        }
    }
}

// MARK: - NavigationViewModel (created manually — the NavigationFeature exception)
// This is the only ViewModel in the app created outside of Module/Feature machinery.

@Observable
@MainActor
public final class NavigationViewModel {
    private let store: any StoreType<NavigationFeature.Action, NavigationFeature.State>
    private var token: SubscriptionToken?

    public var path: [AppRoute] = []

    public init(store: any StoreType<NavigationFeature.Action, NavigationFeature.State>) {
        self.store = store
        self.path = store.state.path
        token = store.observe(didChange: { [weak self] in
            guard let self else { return }
            self.path = store.state.path
        })
    }

    public func dispatch(_ action: NavigationFeature.Action) {
        store.dispatch(action)
    }

    public var pathBinding: Binding<[AppRoute]> {
        Binding(
            get: { self.path },
            set: { self.dispatch(.setPath($0)) }
        )
    }
}
