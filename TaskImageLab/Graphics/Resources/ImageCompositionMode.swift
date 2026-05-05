final class ImageCompositionMode: Resource {
    var usesComputeComposition: Bool

    init(usesComputeComposition: Bool = false) {
        self.usesComputeComposition = usesComputeComposition
    }
}
