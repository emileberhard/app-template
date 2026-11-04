#if DEBUG
import SwiftUI
import UIKit

enum CaptureScreen: String, CaseIterable {
    case daysLeft = "days-left"
    case daysLeftDark = "days-left-dark"

    var style: UIUserInterfaceStyle {
        switch self {
        case .daysLeft: .light
        case .daysLeftDark: .dark
        }
    }

    @ViewBuilder var content: some View {
        switch self {
        case .daysLeft, .daysLeftDark:
            DaysLeftView(daysLeft: 58)
        }
    }

    static func named(_ list: String?) throws -> [CaptureScreen] {
        guard let list else {
            return allCases
        }
        let screens = try list.split(separator: ",", omittingEmptySubsequences: false).map { id in
            guard let screen = CaptureScreen(rawValue: String(id)) else {
                throw CaptureError("there is no screen \"\(id)\"; the screens are \(allCases.map(\.rawValue).joined(separator: ", "))")
            }
            return screen
        }
        guard Set(screens).count == screens.count else {
            throw CaptureError("\(list) names a screen more than once")
        }
        return screens
    }
}

struct CaptureView: View {
    static let directory = ProcessInfo.processInfo.environment["STARTER_CAPTURE"].map { URL(filePath: $0) }

    let directory: URL
    @State private var screen: CaptureScreen?
    @State private var appeared = AsyncStream.makeStream(of: CaptureScreen.self)

    var body: some View {
        Group {
            if let screen {
                screen.content
                    .transaction { $0.disablesAnimations = true }
                    .onAppear { appeared.continuation.yield(screen) }
            } else {
                Color.clear
            }
        }
        .id(screen)
        .task {
            do {
                try await capture()
                exit(0)
            } catch {
                print("capture failed: \(error)")
                exit(1)
            }
        }
    }

    private func capture() async throws {
        let screens = try CaptureScreen.named(ProcessInfo.processInfo.environment["STARTER_CAPTURE_SCREENS"])
        try FileManager.default.createDirectory(at: directory.appending(path: "jpg"), withIntermediateDirectories: true)
        UIView.setAnimationsEnabled(false)
        let window = try await keyWindow()
        let format = UIGraphicsImageRendererFormat()
        format.scale = window.traitCollection.displayScale
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        var shown = appeared.stream.makeAsyncIterator()
        let thumbnails = try await withThrowingTaskGroup(of: (String, UIImage).self) { group in
            for next in screens {
                window.overrideUserInterfaceStyle = next.style
                screen = next
                guard await shown.next(isolation: #isolation) == next else {
                    throw CaptureError("\(next.rawValue) did not appear")
                }
                await Task.yield()
                let image = try await snapshot(of: window, with: renderer)
                let id = next.rawValue
                let directory = directory
                group.addTask { (id, try await CaptureFiles.write(image, named: id, into: directory)) }
            }
            var thumbnails: [String: UIImage] = [:]
            for try await (id, thumbnail) in group {
                thumbnails[id] = thumbnail
            }
            return thumbnails
        }
        let ids = screens.map(\.rawValue)
        try writeSheet(ids.map { ($0, thumbnails[$0]!) })
        try JSONEncoder().encode(ids).write(to: directory.appending(path: "manifest.json"), options: .atomic)
    }

    private func keyWindow() async throws -> UIWindow {
        while true {
            let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            if let window = scene?.keyWindow {
                return window
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func snapshot(of window: UIWindow, with renderer: UIGraphicsImageRenderer) async throws -> UIImage {
        while true {
            var complete = false
            let image = renderer.image { _ in
                complete = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            if complete {
                return image
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    private func writeSheet(_ thumbnails: [(id: String, image: UIImage)]) throws {
        let columns = min(thumbnails.count, 4)
        let rows = (thumbnails.count + columns - 1) / columns
        let pixels = thumbnails.map { CGSize(width: $0.image.size.width * $0.image.scale, height: $0.image.size.height * $0.image.scale) }
        let cell = CGSize(width: pixels.map(\.width).max()!, height: pixels.map(\.height).max()!)
        let gap: CGFloat = 32
        let label: CGFloat = 56
        let size = CGSize(width: gap + CGFloat(columns) * (cell.width + gap), height: gap + CGFloat(rows) * (cell.height + label + gap))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]
        let sheet = UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.8) { context in
            UIColor(white: 0.3, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (index, thumbnail) in thumbnails.enumerated() {
                let origin = CGPoint(x: gap + CGFloat(index % columns) * (cell.width + gap), y: gap + CGFloat(index / columns) * (cell.height + label + gap))
                thumbnail.image.draw(in: CGRect(origin: origin, size: pixels[index]))
                (thumbnail.id as NSString).draw(at: CGPoint(x: origin.x, y: origin.y + cell.height + 12), withAttributes: attributes)
            }
        }
        try sheet.write(to: directory.appending(path: "sheet.jpg"), options: .atomic)
    }
}

nonisolated private enum CaptureFiles {
    static let thumbnailHeight: CGFloat = 900

    @concurrent static func write(_ image: UIImage, named id: String, into directory: URL) async throws -> UIImage {
        guard let png = image.pngData() else {
            throw CaptureError("could not encode \(id) as PNG")
        }
        try png.write(to: directory.appending(path: "\(id).png"), options: .atomic)
        let points = thumbnailHeight / image.scale
        guard let thumbnail = image.preparingThumbnail(of: CGSize(width: image.size.width * points / image.size.height, height: points)),
              let jpeg = thumbnail.jpegData(compressionQuality: 0.8) else {
            throw CaptureError("could not make the \(id) thumbnail")
        }
        try jpeg.write(to: directory.appending(path: "jpg/\(id).jpg"), options: .atomic)
        return thumbnail
    }
}

nonisolated private struct CaptureError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
#endif
