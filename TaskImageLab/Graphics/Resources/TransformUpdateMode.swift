enum TransformUpdateBehavior: String {
    case onChange
    case alwaysChanged
}

final class TransformUpdateMode: Resource {
    var behavior: TransformUpdateBehavior

    init(behavior: TransformUpdateBehavior = .onChange) {
        self.behavior = behavior
    }
}
