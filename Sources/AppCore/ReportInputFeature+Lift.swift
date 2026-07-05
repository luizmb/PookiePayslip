import AppDomain
import Core
import ReportInputFeature
import SwiftRexArchitecture

public let reportInputScope = Scope<AppAction, AppState, World, ReportInputFeature>(
    ReportInputFeature.self,
    action: \.reportInput,
    state: \.reportInput,
    environment: { world in
                ReportInputFeature.Environment(
                    decoder:     world.decoder,
                    readFile:    world.readFile,
                    currentDate: world.currentDate,
                    calendar:    world.calendar,
                    calcTax:     world.calcTax
                )
            }
)
