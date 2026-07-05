import AppDomain
import SettingsFeature
import SwiftRexArchitecture

public let settingsScope = Scope<AppAction, AppState, World, SettingsFeature>(
    SettingsFeature.self,
    action: \.settings,
    state: \.settings,
    environment: { world in
                SettingsFeature.Environment(
                    loadSettings: world.loadSettings,
                    saveSettings: world.saveSettings,
                    exportDatabase: world.exportDatabase
                )
            }
)
