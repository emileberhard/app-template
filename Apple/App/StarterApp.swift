import StarterCore
import SwiftUI

@main
struct StarterApp: App {
    private var currentContent: some View {
        TimelineView(.everyMinute) { context in
            ContentView(daysLeft: daysRemainingInYear(on: context.date, calendar: .current))
        }
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let directory = CaptureView.directory {
                CaptureView(directory: directory)
            } else {
                currentContent
            }
            #else
            currentContent
            #endif
        }
    }
}
