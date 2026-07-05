import Foundation
import FPMacros

@Prisms
public enum AppRoute: Hashable, Sendable, Codable {
    case calendar
    case dayDetail(Date)
    case reportInput
    case reportResult
    case salaryEditor
    case settings
}
