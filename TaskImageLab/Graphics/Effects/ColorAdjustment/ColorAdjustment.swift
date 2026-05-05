import Foundation
import SwiftUI

final class ColorAdjustment: Component, Inspectable, Changed {
    var brightness: Float = 0 {
        didSet { changed = true }
    }
    var contrast: Float = 1 {
        didSet { changed = true }
    }
    var saturation: Float = 1 {
        didSet { changed = true }
    }
    var changed: Bool = true
    var sourceHandle: TextureHandle = .invalid

    var inspectorTitle: String {
        "Color Adjustment"
    }

    func inspectableProperties() -> [InspectableProperty] {
        [
            .float(
                FloatInspectableProperty(
                    id: "colorAdjustment.brightness",
                    title: "Brightness",
                    owner: self,
                    keyPath: \.brightness
                )
            ),
            .float(
                FloatInspectableProperty(
                    id: "colorAdjustment.contrast",
                    title: "Contrast",
                    owner: self,
                    keyPath: \.contrast
                )
            ),
            .float(
                FloatInspectableProperty(
                    id: "colorAdjustment.saturation",
                    title: "Saturation",
                    owner: self,
                    keyPath: \.saturation
                )
            )
        ]
    }
}
