import SwiftUI
import StarterCore

@main
struct StarterApp: App {
    var body: some Scene {
        WindowGroup {
            TimelineView(.everyMinute) { context in
                VStack(spacing: 12) {
                    Text(daysRemainingInYear(on: context.date, calendar: .current), format: .number)
                        .font(.largeTitle.bold())
                    Text("Days left this year")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #if DEBUG
            .task {
                if let directory = Capture.directory {
                    await Capture.screen(into: directory)
                }
            }
            #endif
        }
    }
}
