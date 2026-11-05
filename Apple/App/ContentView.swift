import SwiftUI

struct ContentView: View {
    let daysLeft: Int

    var body: some View {
        DaysLeftView(daysLeft: daysLeft)
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
