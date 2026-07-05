import AppDomain
import ReportResultFeature
import SwiftRexArchitecture

public let reportResultScope = Scope<AppAction, AppState, World, ReportResultFeature>(
    ReportResultFeature.self,
    action: \.reportResult,
    state: \.reportResult,
    environment: { world in
                ReportResultFeature.Environment(
                    renderPDF: { r, recs in world.renderPDF(r, recs) },
                    formatDate: world.formatDate,
                    formatMoney: world.formatMoney
                )
            }
)
