import AppKit
import Metal

final class Preview: Component {
    let previewUpdateDelay: TimeInterval = 0.5

    let preview: NSImage
    var bitmap: NSBitmapImageRep?
    var requestedUpdateAt: TimeInterval?

    init(preview: NSImage = NSImage()) {
        self.preview = preview
    }

    func update(from texture: MTLTexture) {
        let width = texture.width
        let height = texture.height

        guard
            width > 0,
            height > 0,
            let bitmap = ensureBitmap(width: width, height: height)
        else {
            return
        }

        texture.getBytes(
            bitmap.bitmapData!,
            bytesPerRow: width * 4,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )
    }

    private func ensureBitmap(width: Int, height: Int) -> NSBitmapImageRep? {
        if let bitmap, bitmap.pixelsWide == width, bitmap.pixelsHigh == height {
            return bitmap
        }

        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }

        for representation in preview.representations {
            preview.removeRepresentation(representation)
        }
        preview.addRepresentation(bitmap)
        preview.size = NSSize(width: width, height: height)
        self.bitmap = bitmap
        return bitmap
    }
}

extension Preview {
    func requestPreviewUpdate(at timestamp: TimeInterval) {
        requestedUpdateAt = timestamp
    }

    func isReadyForPreviewUpdate(at currentTime: TimeInterval) -> Bool {
        guard let requestedUpdateAt else {
            return false
        }

        return currentTime - requestedUpdateAt >= previewUpdateDelay
    }

    func finishPreviewUpdate() {
        requestedUpdateAt = nil
    }
}
