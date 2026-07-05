import AppDomain
import CalendarFeature
import Core
import CoreFP
import DayDetailFeature
import Foundation
import ReportInputFeature
import ReportResultFeature
import ReactiveConcurrency
import SwiftRexReactiveConcurrency

// MARK: - Calendar mock environment

extension CalendarFeature.Environment {
    /// Empty store — all reads return fileNotFound (empty month)
    static func mock(
        currentDate: @Sendable @escaping () -> Date = { Fixture.today },
        readFile: @Sendable @escaping (String) -> Publisher<Data, ReadingError> = { _ in
            .fail(.fileNotFound(filename: "mock"))
        }
    ) -> CalendarFeature.Environment {
        CalendarFeature.Environment(
            decoder:     JSONDecoder(),
            readFile:    readFile,
            currentDate: currentDate,
            calendar:    { Fixture.calendar },
            formatDate:  Formatting.dateFormatter(locale: Locale(identifier: "en_GB"), calendar: Fixture.calendar),
            formatMoney: Formatting.moneyFormatter(locale: Locale(identifier: "en_GB"))
        )
    }

    /// Pre-loads the given records for any file read
    static func mock(records: [WorkDayRecord]) -> CalendarFeature.Environment {
        let md = MonthData(records: records, salary: nil)
        let data = (try? JSONEncoder().encode(md)) ?? Data()
        return mock(readFile: { _ in .just(data) })
    }
}

// MARK: - DayDetail mock environment

extension DayDetailFeature.Environment {
    static func mock(
        currentDate: @Sendable @escaping () -> Date = { Fixture.today },
        newID:       @Sendable @escaping () -> UUID   = { Fixture.idA },
        readFile:    @Sendable @escaping (String) -> Publisher<Data, ReadingError> = { _ in
            .fail(.fileNotFound(filename: "mock"))
        },
        saveFile:    @Sendable @escaping (Data, String) -> Publisher<Void, SavingError> = { _, _ in
            .just(())
        }
    ) -> DayDetailFeature.Environment {
        DayDetailFeature.Environment(
            decoder:     JSONDecoder(),
            encoder:     JSONEncoder(),
            readFile:    readFile,
            saveFile:    saveFile,
            currentDate: currentDate,
            newID:       newID,
            calendar:    { Fixture.calendar },
            dayBefore:   { Fixture.calendar.date(byAdding: .day, value: -1, to: $0) ?? $0 },
            dayAfter:    { Fixture.calendar.date(byAdding: .day, value:  1, to: $0) ?? $0 },
            loadSettings: { .just(.default) },
            formatDate:  Formatting.dateFormatter(locale: Locale(identifier: "en_GB"), calendar: Fixture.calendar)
        )
    }

    /// Pre-loads the given record so `loadDay` finds it
    static func mock(existingRecord record: WorkDayRecord) -> DayDetailFeature.Environment {
        let md = MonthData(records: [record], salary: nil)
        let data = (try? JSONEncoder().encode(md)) ?? Data()
        return mock(readFile: { _ in .just(data) })
    }
}

// MARK: - ReportInput mock environment

extension ReportInputFeature.Environment {
    static func mock(
        currentDate: @Sendable @escaping () -> Date = { Fixture.today },
        records: [WorkDayRecord] = [],
        calcTax: @Sendable @escaping (Decimal, Int, SalaryRecord) -> TaxBreakdown = { gross, _, _ in
            TaxBreakdown(ni: 0, pension: 0, incomeTax: 0, studentLoan: 0, net: gross)
        }
    ) -> ReportInputFeature.Environment {
        let md = MonthData(records: records, salary: nil)
        let data = (try? JSONEncoder().encode(md)) ?? Data()
        return ReportInputFeature.Environment(
            decoder:     JSONDecoder(),
            readFile:    { _ in .just(data) },
            currentDate: currentDate,
            calendar:    { Fixture.calendar },
            calcTax:     calcTax
        )
    }

    // Per-month files keyed by `monthFilename` (e.g. "07-2026.json"). A missing filename reads as an
    // empty month (file-not-found). Use to exercise salary carry-forward across month boundaries.
    static func mock(
        monthFiles: [String: MonthData],
        currentDate: @Sendable @escaping () -> Date = { Fixture.today },
        calcTax: @Sendable @escaping (Decimal, Int, SalaryRecord) -> TaxBreakdown = { gross, _, _ in
            TaxBreakdown(ni: 0, pension: 0, incomeTax: 0, studentLoan: 0, net: gross)
        }
    ) -> ReportInputFeature.Environment {
        ReportInputFeature.Environment(
            decoder:     JSONDecoder(),
            readFile:    { filename in
                guard let md = monthFiles[filename], let data = try? JSONEncoder().encode(md) else {
                    return .fail(.fileNotFound(filename: filename))
                }
                return .just(data)
            },
            currentDate: currentDate,
            calendar:    { Fixture.calendar },
            calcTax:     calcTax
        )
    }
}

// MARK: - ReportResult mock environment

extension ReportResultFeature.Environment {
    static var mock: ReportResultFeature.Environment {
        ReportResultFeature.Environment(
            renderPDF: { _, _ in .just(Data("fake-pdf".utf8)) },
            formatDate: Formatting.dateFormatter(locale: Locale(identifier: "en_GB"), calendar: Fixture.calendar),
            formatMoney: Formatting.moneyFormatter(locale: Locale(identifier: "en_GB"))
        )
    }

    static var failingRender: ReportResultFeature.Environment {
        ReportResultFeature.Environment(
            renderPDF: { _, _ in .fail(.renderingFailed("mock failure")) },
            formatDate: Formatting.dateFormatter(locale: Locale(identifier: "en_GB"), calendar: Fixture.calendar),
            formatMoney: Formatting.moneyFormatter(locale: Locale(identifier: "en_GB"))
        )
    }
}
