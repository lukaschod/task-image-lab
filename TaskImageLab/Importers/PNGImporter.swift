import CoreGraphics
import Foundation
import ImageIO
import simd

enum PNGImporterError: Error {
    case decodeFailed
    case invalidImage
}

struct PNGImporter {
    func importPNG(from url: URL) throws -> Image {
        let data = try Data(contentsOf: url)
        return try importPNG(from: data)
    }

    func importPNG(from data: Data) throws -> Image {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw PNGImporterError.decodeFailed
        }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)

        guard
            let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw PNGImporterError.invalidImage
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return Image(
            size: SIMD2(width, height),
            bytesPerRow: bytesPerRow,
            pixels: pixels
        )
    }
}
