import AppDomain
import CoreFP
import NavigationFeature
import SwiftRex

private let stateOptics  = AppState.lens.navigation
private let actionOptics = AppAction.prism.navigation

public extension Behavior
where Action      == NavigationFeature.Action,
      State       == NavigationFeature.State,
      Environment == Void {

    func lift() -> Behavior<AppAction, AppState, World> {
        lift(
            action:      actionOptics,
            state:       stateOptics,
            environment: ignore
        )
    }
}

public extension NavigationViewModel {
    @MainActor
    static func from(store: MainStoreType) -> NavigationViewModel {
        NavigationViewModel(
            store: store.projection(
                action: actionOptics.review,
                state:  stateOptics.get
            )
        )
    }
}
