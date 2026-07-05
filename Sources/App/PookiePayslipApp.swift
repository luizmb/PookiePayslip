import AppCore
import AppDomain
import SwiftUI

@main
struct PookiePayslipApp: App {
    private let world = World.real
    private let store: MainStoreType

    init() {
        store = MainStore.app(world: world)
    }

    var body: some Scene {
        AppRoute.scene(store: store, world: world)
    }
}
