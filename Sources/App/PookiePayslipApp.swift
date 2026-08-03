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
        WindowGroup {
            // The app is an ordinary Feature: it builds its own view, and the World stops there.
            AppFeature.view(store: store, environment: world)
        }
    }
}
