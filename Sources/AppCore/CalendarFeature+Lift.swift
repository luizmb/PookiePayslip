import AppDomain
import CalendarFeature
import Core
import SwiftRexArchitecture

public let calendarScope = Scope<AppAction, AppState, World, CalendarFeature>(
    CalendarFeature.self,
    action: \.calendar,
    state: \.calendar,
    environment: { world in
                CalendarFeature.Environment(
                    decoder:     world.decoder,
                    readFile:    world.readFile,
                    currentDate: world.currentDate,
                    calendar:    world.calendar,
                    formatDate:  world.formatDate,
                    formatMoney: world.formatMoney
                )
            }
)
