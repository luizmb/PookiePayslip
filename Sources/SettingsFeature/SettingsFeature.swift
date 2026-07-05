import AppDomain
import CoreFP
import Foundation
import ReactiveConcurrency
import SwiftRexReactiveConcurrency
import SwiftUI
import SwiftRex
import SwiftRexArchitecture

@Feature(type: .moduleEntryPoint, strategy: .observationSimple)
public enum SettingsFeature {

    // MARK: - State

    public struct State: Sendable, Equatable, Codable {
        public var defaultStartTime: TimeOfDay
        public var defaultEndTime: TimeOfDay
        public var defaultBreakMinutes: Int
        public var exportData: Data?        // freshly-zipped backup, ready to share (cleared on each appear)

        public var settings: AppSettings {
            AppSettings(
                defaultStartTime: defaultStartTime,
                defaultEndTime: defaultEndTime,
                defaultBreakMinutes: defaultBreakMinutes
            )
        }
    }

    // MARK: - Action

    public enum Action: Sendable {
        case start
        case loaded(AppSettings)
        case setStart(TimeOfDay)
        case setEnd(TimeOfDay)
        case setBreakMinutes(Int)
        case save
        case saved(AppSettings)   // bridgeBehavior pops nav
        case saveFailed
        case back
        case exportDatabase       // zip all data files for a backup
        case exportReady(Data)    // zip produced → store for the ShareLink
        case exportFailed
    }

    // MARK: - Environment

    public struct Environment: Sendable {
        let loadSettings: @Sendable () -> Publisher<AppSettings, Never>
        let saveSettings: @Sendable (AppSettings) -> Publisher<Void, SavingError>
        let exportDatabase: @Sendable () -> Publisher<Data, ExportError>

        public init(
            loadSettings: @Sendable @escaping () -> Publisher<AppSettings, Never>,
            saveSettings: @Sendable @escaping (AppSettings) -> Publisher<Void, SavingError>,
            exportDatabase: @Sendable @escaping () -> Publisher<Data, ExportError>
        ) {
            self.loadSettings = loadSettings
            self.saveSettings = saveSettings
            self.exportDatabase = exportDatabase
        }
    }

    // MARK: - ViewModel

        public struct ViewState: Sendable, Equatable {
            public var startTime: TimeOfDay
            public var endTime: TimeOfDay
            public var breakMinutes: Int
            public var breakLabel: String       // "30 min"
            public var breakOptions: [Int]
            // Labels
            public var titleLabel: String
            public var subtitleLabel: String
            public var startLabel: String
            public var endLabel: String
            public var breakSectionLabel: String
            public var saveButtonLabel: String
            // Backup export
            public var exportSectionLabel: String
            public var exportButtonLabel: String
            public var exportShareable: ZipShareable?   // non-nil once the zip is ready to share
        }

        public enum ViewAction: Sendable {
            case setStart(TimeOfDay)
            case setEnd(TimeOfDay)
            case setBreakMinutes(Int)
            case save
            case back
            case onAppear
            case exportDatabase
        }

    // MARK: - Mappings

    public static let mapState = Reader<Environment, @MainActor @Sendable (State) -> ViewState> { _ in { state in
        .init(
            startTime: state.defaultStartTime,
            endTime: state.defaultEndTime,
            breakMinutes: state.defaultBreakMinutes,
            breakLabel: durationLabel(state.defaultBreakMinutes),
            breakOptions: [15, 30, 45, 60, 90],
            titleLabel: "Settings",
            subtitleLabel: "Defaults used when you tap a --:-- field on the Day screen.",
            startLabel: "Default start time",
            endLabel: "Default finish time",
            breakSectionLabel: "Default break length",
            saveButtonLabel: "Save",
            exportSectionLabel: "Backup",
            exportButtonLabel: "Export database",
            exportShareable: state.exportData.map { ZipShareable(data: $0) }
        )
    } }

    public static let mapAction = Reader<Environment, @Sendable (ViewAction) -> Action> { _ in { va in
        switch va {
        case .setStart(let t):        .setStart(t)
        case .setEnd(let t):          .setEnd(t)
        case .setBreakMinutes(let m): .setBreakMinutes(m)
        case .save:                   .save
        case .back:                   .back
        case .onAppear:               .start
        case .exportDatabase:         .exportDatabase
        }
    } }

    // MARK: - Lifecycle

    public static func initialState(with _: Void) -> State {
        let d = AppSettings.default
        return .init(
            defaultStartTime: d.defaultStartTime,
            defaultEndTime: d.defaultEndTime,
            defaultBreakMinutes: d.defaultBreakMinutes,
            exportData: nil
        )
    }

    // MARK: - Behavior

    public static func behavior() -> Behavior<Action, State, Environment> {
        .handle { action, context in
            guard let stateBefore = context.stateBefore else { return .doNothing }
            switch action {
            case .start:
                return .reduce { $0.exportData = nil }   // drop any stale backup from a prior visit
                    .produce { ctx in
                        ctx.environment.loadSettings()
                            .asEffect { result in
                                let settings: AppSettings
                                if case .success(let s) = result { settings = s } else { settings = .default }
                                return .loaded(settings)
                            }
                    }

            case .loaded(let settings):
                return .reduce { state in
                    state.defaultStartTime = settings.defaultStartTime
                    state.defaultEndTime = settings.defaultEndTime
                    state.defaultBreakMinutes = settings.defaultBreakMinutes
                }

            case .setStart(let t):        return .reduce { $0.defaultStartTime = t }
            case .setEnd(let t):          return .reduce { $0.defaultEndTime = t }
            case .setBreakMinutes(let m): return .reduce { $0.defaultBreakMinutes = m }

            case .save:
                let settings = stateBefore.settings
                return .produce { ctx in
                    ctx.environment.saveSettings(settings)
                        .asEffect { result in
                            if case .failure = result { .saveFailed } else { .saved(settings) }
                        }
                }

            case .exportDatabase:
                return .produce { ctx in
                    ctx.environment.exportDatabase()
                        .asEffect { result in
                            switch result {
                            case .success(let data): .exportReady(data)
                            case .failure:           .exportFailed
                            }
                        }
                }

            case .exportReady(let data):
                return .reduce { $0.exportData = data }

            case .exportFailed:
                return .doNothing

            case .saved, .saveFailed, .back:
                return .doNothing   // bridgeBehavior handles navigation
            }
        }
    }

    public typealias Content = SettingsView
}

// Renders a minute count as "30 min" / "1h 30m".
func durationLabel(_ minutes: Int) -> String {
    let h = minutes / 60, m = minutes % 60
    if h == 0 { return "\(m) min" }
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
extension SettingsFeature: SwiftRexArchitecture.Feature {}
