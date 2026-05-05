import Foundation

struct CanvasSizePreset {
    let title: String
    let size: CGSize

    static let all: [CanvasSizePreset] = [
        CanvasSizePreset(title: "Small 800 x 600", size: CGSize(width: 800, height: 600)),
        CanvasSizePreset(title: "Square 1024 x 1024", size: CGSize(width: 1024, height: 1024)),
        CanvasSizePreset(title: "HD 1280 x 720", size: CGSize(width: 1280, height: 720)),
        CanvasSizePreset(title: "Full HD 1920 x 1080", size: CGSize(width: 1920, height: 1080)),
        CanvasSizePreset(title: "Ultra HD 3840 x 2160", size: CGSize(width: 3840, height: 2060))
    ]
}

extension Notification.Name {
    static let canvasSizeDidChange = Notification.Name("CanvasSizeDidChange")
}
