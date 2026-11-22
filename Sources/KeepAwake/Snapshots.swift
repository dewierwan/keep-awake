import AppKit
import SwiftUI

/// Renders the panel to PNG files without showing it, in both states and both
/// appearances. Used to check the design and to make the README picture.
@MainActor
func writeSnapshots(to directory: String) {
    _ = NSApplication.shared
    let folder = URL(fileURLWithPath: directory, isDirectory: true)
    try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

    // Idle, running, and idle with the settings open.
    for (name, active, showSettings) in [("idle", false, false), ("running", true, false), ("settings", false, true)] {
        for scheme in [ColorScheme.light, .dark] {
            let session = Session()
            if active { session.previewRunning(minutes: 20) }
            let model = PanelModel()
            model.showingSettings = showSettings
            let view = PanelView(session: session, model: model, quit: {})
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let file = "panel-\(name)-\(scheme == .dark ? "dark" : "light").png"
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            else {
                print("Could not render \(file)")
                continue
            }
            try? png.write(to: folder.appendingPathComponent(file))
            print("Wrote \(file) (\(Int(image.size.width)) x \(Int(image.size.height)) points)")
        }
    }
}

extension Session {
    /// Shows a running session without holding anything on the real Mac.
    func previewRunning(minutes: Int) {
        setPreview(end: Date().addingTimeInterval(TimeInterval(minutes * 60) - 18))
    }
}
