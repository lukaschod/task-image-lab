// Marks that it is tracked for changes.
protocol Changed: AnyObject {
    var changed: Bool { get set }
}

func resetChanged(on canvas: Canvas) {
    for layer in canvas.layers {
        for component in layer.components {
            if let changed = component as? Changed {
                changed.changed = false
            }
        }
    }
}
