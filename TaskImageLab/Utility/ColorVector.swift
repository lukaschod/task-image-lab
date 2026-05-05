import AppKit
import SwiftUI
import simd

extension Color {
    func simd4RGBA() -> SIMD4<Float>? {
        guard let resolvedColor = NSColor(self).usingColorSpace(.deviceRGB) else {
            return nil
        }

        return SIMD4(
            Float(resolvedColor.redComponent),
            Float(resolvedColor.greenComponent),
            Float(resolvedColor.blueComponent),
            Float(resolvedColor.alphaComponent)
        )
    }
}
