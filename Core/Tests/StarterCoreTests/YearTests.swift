import Foundation
import Testing
@testable import StarterCore

@Test(arguments: [
    (2024, 1, 1, 365),
    (2024, 2, 28, 307),
    (2024, 2, 29, 306),
    (2025, 1, 1, 364),
    (2025, 12, 31, 0),
])
func remainingDays(year: Int, month: Int, day: Int, expected: Int) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "Europe/Stockholm"))
    let date = try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 23)))
    #expect(daysRemainingInYear(on: date, calendar: calendar) == expected)
}
