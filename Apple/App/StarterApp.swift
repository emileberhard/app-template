import SwiftUI

@main
struct StarterApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let directory = CaptureView.directory {
                CaptureView(directory: directory)
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
