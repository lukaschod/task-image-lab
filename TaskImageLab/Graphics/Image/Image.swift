import Foundation
import simd

final class Image: Component, Inspectable, Changed {
    private(set) var size: SIMD2<Int>
    private(set) var bytesPerRow: Int
    private(set) var pixels: [UInt8]
    var changed: Bool = true

    init(size: SIMD2<Int>, bytesPerRow: Int, pixels: [UInt8]) {
        self.size = size
        self.bytesPerRow = bytesPerRow
        self.pixels = pixels
    }

    func resize(to newSize: SIMD2<Int>) {
        if size == newSize {
            return
        }

        let width = max(newSize.x, 0)
        let height = max(newSize.y, 0)
        let resizedBytesPerRow = width * 4

        guard
            width > 0,
            height > 0,
            size.x > 0,
            size.y > 0
        else {
            size = SIMD2(width, height)
            bytesPerRow = resizedBytesPerRow
            pixels = []
            changed = true
            return
        }

        let bytesPerPixel = 4
        var resizedPixels = [UInt8](repeating: 0, count: resizedBytesPerRow * height)

        for destinationY in 0..<height {
            let sourceY = min((destinationY * size.y) / height, size.y - 1)
            let sourceRowStart = sourceY * bytesPerRow
            let destinationRowStart = destinationY * resizedBytesPerRow

            for destinationX in 0..<width {
                let sourceX = min((destinationX * size.x) / width, size.x - 1)
                let sourcePixelStart = sourceRowStart + (sourceX * bytesPerPixel)
                let destinationPixelStart = destinationRowStart + (destinationX * bytesPerPixel)

                resizedPixels[destinationPixelStart..<(destinationPixelStart + bytesPerPixel)] =
                    pixels[sourcePixelStart..<(sourcePixelStart + bytesPerPixel)]
            }
        }

        size = SIMD2(width, height)
        bytesPerRow = resizedBytesPerRow
        pixels = resizedPixels
        changed = true
    }

    var inspectorTitle: String {
        "Image"
    }

    func inspectableProperties() -> [InspectableProperty] {
        [
            .simd2Float(
                SIMD2FloatInspectableProperty(
                    id: "image.size",
                    title: "Size",
                    getValue: { [weak self] in
                        guard let self else {
                            return nil
                        }

                        return SIMD2(Float(size.x), Float(size.y))
                    },
                    setValue: { _ in }
                )
            )
        ]
    }
}
