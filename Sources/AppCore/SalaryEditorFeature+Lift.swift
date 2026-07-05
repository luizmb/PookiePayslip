import AppDomain
import Core
import SalaryEditorFeature
import SwiftRexArchitecture

public let salaryEditorScope = Scope<AppAction, AppState, World, SalaryEditorFeature>(
    SalaryEditorFeature.self,
    action: \.salaryEditor,
    state: \.salaryEditor,
    environment: { world in
                SalaryEditorFeature.Environment(
                    decoder:  world.decoder,
                    encoder:  world.encoder,
                    readFile: world.readFile,
                    saveFile: world.saveFile,
                    calendar: world.calendar
                )
            }
)
