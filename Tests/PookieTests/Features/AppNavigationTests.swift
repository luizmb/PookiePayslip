@testable import AppCore
import AppDomain
import CalendarFeature
import CoreFP
import DayDetailFeature
import Foundation
import Observation
import ReactiveConcurrency
import ReportInputFeature
import ReportResultFeature
import SalaryEditorFeature
import SettingsFeature
import SwiftRex
import SwiftRexArchitecture
import SwiftRexSwiftUI
import SwiftRexTesting
import Testing

// The navigation reducer is pure — it never reaches the World — so a stub is enough to instantiate it.
private extension World {
    static let stub = World(
        decoder: JSONDecoder(),
        encoder: JSONEncoder(),
        readFile: { _ in .fail(.fileNotFound(filename: "stub")) },
        saveFile: { _, _ in .just(()) },
        currentDate: { Fixture.today },
        newID: { Fixture.idA },
        calendar: { Fixture.calendar },
        dayBefore: { $0 },
        dayAfter: { $0 },
        calcTax: { _, _, _ in TaxBreakdown(ni: 0, pension: 0, incomeTax: 0, studentLoan: 0, net: 0) },
        renderPDF: { _, _ in .just(Data()) },
        formatDate: { _, _ in "" },
        formatMoney: { _, _ in "" },
        loadSettings: { .just(.default) },
        saveSettings: { _ in .just(()) },
        exportDatabase: { .just(Data()) }
    )
}

private let stubReport = PayReport(
    totalHours: 8,
    isEstimated: false,
    weekdayAvgHours: 8,
    weekendAvgHours: 0,
    projectedDays: 0,
    incompleteDays: 0,
    grossPay: 88,
    niDeduction: 0,
    pensionDeduction: 0,
    incomeTaxDeduction: 0,
    studentLoanDeduction: 0,
    netPay: 88,
    noWeekdayDataWarning: false,
    periodDays: 1,
    salary: SalaryRecord(amount: 11, periodicity: .hourly)
)

@MainActor
private func store(initial: AppState = AppState()) -> TestStore<AppAction, AppState, World> {
    TestStore(initial: initial, behavior: navigationBehavior(), environment: .stub, exhaustive: false)
}

/// A one-shot flag settable from the `@Sendable` `onChange` callback.
/// `@unchecked Sendable` is sound here: every access to `value` is guarded by `lock`.
private final class Flag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    var isSet: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

// MARK: - Tests
//
// There is no invariant test here, and that is the point: a screen's state lives *in* the `path` element,
// so "a route without its state" cannot be constructed. The previous design needed a test to police that;
// this one makes it a type error.

@Suite("Navigation: the stack is the state")
@MainActor
struct AppNavigationTests {

    @Test func startsAtTheRootWithAnEmptyStack() {
        #expect(AppState().path.isEmpty)
        #expect(AppState().routes.isEmpty)
    }

    /// Pushing appends a screen that is already complete — there is no second step that could be missed.
    @Test func pushAppendsAFullyBuiltScreen() {
        let s = store()
        s.dispatch(AppAction.navigation(.push(.dayDetail(Fixture.todayMidnight)))) { state in
            state.path = [.dayDetail(DayDetailFeature.State(date: Fixture.todayMidnight))]
        }
        #expect(s.state.routes == [AppRoute.dayDetail])
        #expect(AppScopes.dayDetail.state.preview(s.state)?.date == Fixture.todayMidnight)
    }

    /// The report rides along with the push, so the result screen can never exist without its figures.
    @Test func pushCarriesEverythingTheScreenNeeds() {
        let s = store()
        s.dispatch(
            AppAction.navigation(.push(.reportResult(stubReport, [], from: Fixture.twoDaysAgo, to: Fixture.today)))
        ) { state in
            state.path = [
                .reportResult(
                    ReportResultFeature.State(report: stubReport, records: [], from: Fixture.twoDaysAgo, to: Fixture.today)
                )
            ]
        }
        #expect(AppScopes.reportResult.state.preview(s.state)?.report == stubReport)
    }

    /// The editor seeds itself from the calendar — the navigator never reaches in to set fields.
    @Test func salaryEditorIsBuiltFromTheMonthTheCalendarIsShowing() {
        var initial = AppState()
        initial.calendar.currentMonth = Fixture.todayMidnight
        initial.calendar.salary = SalaryRecord(amount: 42, periodicity: .monthly)
        let s = store(initial: initial)

        s.dispatch(AppAction.navigation(.push(.salaryEditor))) { state in
            state.path = [
                .salaryEditor(
                    SalaryEditorFeature.State(editing: initial.calendar.salary, month: Fixture.todayMidnight)
                )
            ]
        }
        #expect(AppScopes.salaryEditor.state.preview(s.state)?.amount == 42)
        #expect(AppScopes.salaryEditor.state.preview(s.state)?.periodicity == .monthly)
    }

    /// Popping removes the element — the screen's data goes with it because it *is* the element.
    @Test func popRemovesTheScreenAndItsData() {
        let s = store()
        s.dispatch(AppAction.navigation(.push(.settings))) { state in
            state.path = [.settings(SettingsFeature.initialState(with: ()))]
        }
        s.dispatch(AppAction.navigation(.pop)) { state in
            state.path = []
        }
        #expect(AppScopes.settings.state.preview(s.state) == nil)
    }

    /// Back button and back-swipe both arrive as `setPath`; folding to the longest matching prefix is
    /// total, so an unexpected path truncates rather than leaving the stack disagreeing with the screen.
    @Test func interactiveSetPathTruncatesToTheLongestMatchingPrefix() {
        let s = store()
        s.dispatch(AppAction.navigation(.push(.reportInput))) { state in
            state.path = [.reportInput(ReportInputFeature.initialState(with: ()))]
        }
        s.dispatch(
            AppAction.navigation(.push(.reportResult(stubReport, [], from: Fixture.twoDaysAgo, to: Fixture.today)))
        ) { state in
            state.path.append(
                .reportResult(
                    ReportResultFeature.State(report: stubReport, records: [], from: Fixture.twoDaysAgo, to: Fixture.today)
                )
            )
        }
        #expect(s.state.routes == [AppRoute.reportInput, .reportResult])

        s.dispatch(AppAction.navigation(.setPath([.reportInput]))) { state in
            state.path.removeLast()
        }
        #expect(AppScopes.reportResult.state.preview(s.state) == nil)
        #expect(AppScopes.reportInput.state.preview(s.state) != nil)
    }

    @Test func popToRootEmptiesTheStack() {
        let s = store()
        s.dispatch(AppAction.navigation(.push(.reportInput))) { state in
            state.path = [.reportInput(ReportInputFeature.initialState(with: ()))]
        }
        s.dispatch(AppAction.navigation(.popToRoot)) { state in
            state.path = []
        }
        #expect(s.state == AppState())
    }

    /// Re-entering a screen builds a new one, so last visit's data cannot flash while the load is in flight.
    @Test func reenteringAScreenBuildsItAfresh() {
        var initial = AppState()
        var stale = DayDetailFeature.State(date: Fixture.twoDaysAgo)
        stale.record = WorkDayRecord(id: Fixture.idA, date: Fixture.twoDaysAgo)
        stale.dateTitle = "a previous visit"
        initial.path = [.dayDetail(stale)]
        let s = store(initial: initial)

        s.dispatch(AppAction.navigation(.pop)) { state in
            state.path = []
        }
        s.dispatch(AppAction.navigation(.push(.dayDetail(Fixture.todayMidnight)))) { state in
            state.path = [.dayDetail(DayDetailFeature.State(date: Fixture.todayMidnight))]
        }

        #expect(AppScopes.dayDetail.state.preview(s.state)?.date == Fixture.todayMidnight)
        #expect(AppScopes.dayDetail.state.preview(s.state)?.record == nil)
        #expect(AppScopes.dayDetail.state.preview(s.state)?.dateTitle == "")
    }

    @Test func popOnAnEmptyStackIsANoOp() {
        let s = store()
        s.dispatch(AppAction.navigation(.pop)) { _ in }
        #expect(s.state.path.isEmpty)
    }

    /// The scope's affine lane reads and writes the same `path` element, in place — a write lands on the
    /// screen it read from rather than on a copy.
    @Test func theAffineScopeWritesBackIntoTheElementItRead() {
        var state = AppState()
        state.path = [.dayDetail(DayDetailFeature.State(date: Fixture.twoDaysAgo))]

        AppScopes.dayDetail.state.modify(&state) { $0.dateTitle = "edited" }

        #expect(state.path.count == 1)
        #expect(AppScopes.dayDetail.state.preview(state)?.dateTitle == "edited")
    }

    /// Writing a screen that is not on the stack is a no-op — the affine lane has nothing to focus, so a
    /// child behavior cannot conjure a screen navigation never pushed.
    @Test func writingAScreenThatIsNotOnTheStackChangesNothing() {
        var state = AppState()
        AppScopes.settings.state.modify(&state) { $0.defaultBreakMinutes = 99 }
        #expect(state == AppState())
    }

    /// The bug that made every push a silent no-op on screen.
    ///
    /// `Store` is a plain `final class` and `StoreType.state` an ordinary protocol requirement, so a view
    /// body reading `store.state` registers **no** observation dependency: the reducer appended the
    /// route, the state was correct, and `NavigationStack` was simply never asked to re-render. Routing
    /// the root through `AppFeature`'s `ViewStore` — the same one every other screen gets — is what fixes
    /// it. `withObservationTracking` is precisely the mechanism SwiftUI uses to decide.
    @Test func theRootPathIsObservableSoAPushActuallyRerendersTheStack() async {
        let store = Store(initial: AppState(), behavior: navigationBehavior(), environment: World.stub)
        let viewStore = ViewStore(store)

        let invalidated = Flag()
        withObservationTracking {
            _ = viewStore.state.routes
        } onChange: {
            invalidated.set()
        }

        store.dispatch(AppAction.navigation(.push(.settings)))
        await Task.yield()

        #expect(invalidated.isSet, "SwiftUI would never re-render the NavigationStack, so no push would appear")
        #expect(viewStore.state.routes == [AppRoute.settings])
    }
}
