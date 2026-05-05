func forceTransformChanged(on canvas: Canvas) {
    guard let transformUpdateMode: TransformUpdateMode = canvas.resource() else {
        return
    }

    guard transformUpdateMode.behavior == .alwaysChanged else {
        return
    }

    for (_, transform) in canvas.query(Transform.self) {
        transform.changed = true
    }
}
