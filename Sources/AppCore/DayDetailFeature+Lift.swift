import AppDomain
import Core
import DayDetailFeature
import SwiftRexArchitecture

public let dayDetailScope = Scope<AppAction, AppState, World, DayDetailFeature>(
    DayDetailFeature.self,
    action: \.dayDetail,
    state: \.dayDetail,
    environment: { world in
                DayDetailFeature.Environment(
                    decoder:     world.decoder,
                    encoder:     world.encoder,
                    readFile:    world.readFile,
                    saveFile:    world.saveFile,
                    currentDate: world.currentDate,
                    newID:       world.newID,
                    calendar:    world.calendar,
                    dayBefore:   world.dayBefore,
                    dayAfter:    world.dayAfter,
                    loadSettings: world.loadSettings,
                    formatDate:  world.formatDate
                )
            }
)
