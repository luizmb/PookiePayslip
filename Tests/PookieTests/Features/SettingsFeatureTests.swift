import AppDomain
import Foundation
import ReactiveConcurrency
import SettingsFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftRexTesting
import Testing

@MainActor
private func store(
    initial: SettingsFeature.State = SettingsFeature.initialState(with: ()),
    env: SettingsFeature.Environment = mockEnv(),
    exhaustive: Bool = true
) -> TestStore<SettingsFeature.Action, SettingsFeature.State, SettingsFeature.Environment> {
    TestStore(initial: initial, behavior: SettingsFeature.behavior(), environment: env, exhaustive: exhaustive)
}

private func mockEnv(zip: Data = Data("zip".utf8)) -> SettingsFeature.Environment {
    SettingsFeature.Environment(
        loadSettings: { .just(.default) },
        saveSettings: { _ in .just(()) },
        exportDatabase: { .just(zip) }
    )
}

@Suite("SettingsFeature Export")
@MainActor
struct SettingsFeatureExportTests {

    @Test func exportDatabaseProducesZipAndSurfacesShareable() async {
        let zip = Data("backup-bytes".utf8)
        let s = store(env: mockEnv(zip: zip))

        s.dispatch(.exportDatabase) { _ in }   // produce-only
        await s.runEffects()
        s.receive(SettingsFeature.Action.prism.exportReady) { data, state in
            state.exportData = data
            #expect(data == zip)
        }
        #expect(SettingsFeature.mapState(mockEnv())(s.state).exportShareable?.data == zip)
    }

    @Test func startClearsStaleBackup() async {
        var initial = SettingsFeature.initialState(with: ())
        initial.exportData = Data("old".utf8)
        let s = store(initial: initial)

        s.dispatch(.start) { $0.exportData = nil }   // cleared on every appear
        await s.runEffects()
        s.receive(SettingsFeature.Action.prism.loaded) { _, _ in }
        #expect(s.state.exportData == nil)
    }

    @Test func noShareableUntilExported() {
        #expect(SettingsFeature.mapState(mockEnv())(SettingsFeature.initialState(with: ())).exportShareable == nil)
    }
}

// MARK: - Snapshots

#if os(iOS) || os(tvOS)
import SnapshotTesting
import SwiftUI

@Suite("SettingsFeature Snapshots", .snapshots)
@MainActor
struct SettingsFeatureSnapshotTests {
    private func feature(state: SettingsFeature.State) -> TestFeature<SettingsFeature> {
        TestFeature<SettingsFeature>(initial: state, environment: mockEnv())
    }

    @Test func snapshotDefault() async {
        await snap(feature(state: SettingsFeature.initialState(with: ())), named: "settings-default")
    }

    @Test func snapshotBackupReady() async {
        var s = SettingsFeature.initialState(with: ())
        s.exportData = Data("backup".utf8)   // export produced → button is a ShareLink
        await snap(feature(state: s), named: "settings-backup-ready")
    }
}
#endif
