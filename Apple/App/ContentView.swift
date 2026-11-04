import StarterCore
import SwiftUI

struct ContentView: View {
    var body: some View {
        TimelineView(.everyMinute) { context in
            DaysLeftView(daysLeft: daysRemainingInYear(on: context.date, calendar: .current))
        }
    }
}

struct DaysLeftView: View {
    let daysLeft: Int

    var body: some View {
        VStack(spacing: 12) {
            Text(daysLeft, format: .number)
                .font(.largeTitle.bold())
            Text("Days left this year")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
