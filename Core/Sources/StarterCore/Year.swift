import Foundation

public func daysRemainingInYear(on date: Date, calendar: Calendar) -> Int {
    guard let days = calendar.range(of: .day, in: .year, for: date),
          let today = calendar.ordinality(of: .day, in: .year, for: date) else {
        preconditionFailure("The calendar cannot represent this date.")
    }
    return days.count - today
}
