import AppDomain
import CalendarFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftRexSwiftUI
import SwiftUI

/// The app shell — a `NavigationStack` over the store's path.
///
/// It knows exactly two things: a ``ViewStore`` and a ``AppRouter``. No `World`, no feature types, no
/// idea how a child screen is assembled — it asks the router for a destination and renders it. Both are
/// handed in at construction by ``AppFeature``, which is the only place holding the `World`.
///
/// Holding the router rather than reading it from `@Environment` is deliberate: it is deterministic
/// across sheet and cover boundaries, exactly where SwiftUI's environment propagation is not.
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public struct AppRootView: View, Routable {
    let viewStore: ViewStore<AppState, AppAction>
    public let router: AppRouter

    init(viewStore: ViewStore<AppState, AppAction>, router: AppRouter) {
        self.viewStore = viewStore
        self.router = router
    }

    public var body: some View {
        NavigationStack(
            path: viewStore.binding(.state(\.routes), dispatch: .action(\.navigation.setPath))
        ) {
            router.root()
                .navigationDestination(for: AppRoute.self) { route in
                    router.destination(for: route)
                }
        }
    }
}
