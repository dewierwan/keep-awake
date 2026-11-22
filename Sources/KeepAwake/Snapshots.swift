import AppKit
import SwiftUI

/// Renders the panel to PNG files without showing it, in both states and both
/// appearances. Used to check the design and to make the README picture.
@MainActor
func writeSnapshots(to directory: String) {
    _ = NSApplication.shared
    let folder = URL(fileURLWithPath: directory, isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    for active in [false, true] {
        for scheme in [ColorScheme.light, .dark] {
            let session = Session()
            if active { session.previewRunning(minutes: 20) }
            let view = PanelView(session: session, hotkeyHint: "⌃⌥⌘K starts 20 min", quit: {})
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let name = "panel-\(active ? "running" : "idle")-\(scheme == .dark ? "dark" : "light").png"
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            else {
                print("Could not render \(name)")
                continue
            }
            try? png.write(to: folder.appendingPathComponent(name))
            print("Wrote \(name) (\(Int(image.size.width)) x \(Int(image.size.height)) points)")
        }
    }
}

extension Session {
    /// Shows a running session without holding anything on the real Mac.
    func previewRunning(minutes: Int) {
        setPreview(end: Date().addingTimeInterval(TimeInterval(minutes * 60) - 18))
    }
}
