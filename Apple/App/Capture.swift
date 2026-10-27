#if DEBUG
import SwiftUI
import UIKit

enum Capture {
    static let directory = ProcessInfo.processInfo.environment["STARTER_CAPTURE"].map { URL(filePath: $0) }

    static func screen(into directory: URL) async {
        do {
            let window = try await keyWindow()
            let format = UIGraphicsImageRendererFormat()
            format.scale = window.traitCollection.displayScale
            format.opaque = true
            let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
                _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            guard let png = image.pngData() else { throw CaptureError("could not encode the screen as PNG") }
            try png.write(to: directory.appending(path: "01.png"), options: .atomic)
            exit(0)
        } catch {
            print("capture failed: \(error)")
            exit(1)
        }
    }

    private static func keyWindow() async throws -> UIWindow {
        while true {
            let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            if let window = scene?.keyWindow {
                return window
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }
}

private struct CaptureError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
#endif
