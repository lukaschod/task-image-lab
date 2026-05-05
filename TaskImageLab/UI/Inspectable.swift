import Foundation
import SwiftUI
import simd

final class WeakObjectReference<Object: AnyObject> {
    weak var object: Object?

    init(_ object: Object?) {
        self.object = object
    }
}

final class FloatInspectableProperty: Identifiable {
    let id: String
    let title: String

    private let getValue: () -> Float?
    private let setValue: (Float) -> Void

    init<Owner: AnyObject>(
        id: String,
        title: String,
        owner: Owner,
        keyPath: ReferenceWritableKeyPath<Owner, Float>
    ) {
        self.id = id
        self.title = title

        let reference = WeakObjectReference(owner)
        getValue = {
            reference.object?[keyPath: keyPath]
        }
        setValue = { value in
            reference.object?[keyPath: keyPath] = value
        }
    }

    func value() -> Float? {
        getValue()
    }

    func update(_ value: Float) {
        setValue(value)
    }
}

final class SIMD2FloatInspectableProperty: Identifiable {
    let id: String
    let title: String

    private let getValue: () -> SIMD2<Float>?
    private let setValue: (SIMD2<Float>) -> Void

    init<Owner: AnyObject>(
        id: String,
        title: String,
        owner: Owner,
        keyPath: ReferenceWritableKeyPath<Owner, SIMD2<Float>>
    ) {
        self.id = id
        self.title = title

        let reference = WeakObjectReference(owner)
        getValue = {
            reference.object?[keyPath: keyPath]
        }
        setValue = { value in
            reference.object?[keyPath: keyPath] = value
        }
    }

    init(
        id: String,
        title: String,
        getValue: @escaping () -> SIMD2<Float>?,
        setValue: @escaping (SIMD2<Float>) -> Void
    ) {
        self.id = id
        self.title = title
        self.getValue = getValue
        self.setValue = setValue
    }

    func value() -> SIMD2<Float>? {
        getValue()
    }

    func update(_ value: SIMD2<Float>) {
        setValue(value)
    }
}

final class ColorInspectableProperty: Identifiable {
    let id: String
    let title: String

    private let getValue: () -> Color?
    private let setValue: (Color) -> Void

    init<Owner: AnyObject>(
        id: String,
        title: String,
        owner: Owner,
        keyPath: ReferenceWritableKeyPath<Owner, Color>
    ) {
        self.id = id
        self.title = title

        let reference = WeakObjectReference(owner)
        getValue = {
            reference.object?[keyPath: keyPath]
        }
        setValue = { value in
            reference.object?[keyPath: keyPath] = value
        }
    }

    init(
        id: String,
        title: String,
        getValue: @escaping () -> Color?,
        setValue: @escaping (Color) -> Void
    ) {
        self.id = id
        self.title = title
        self.getValue = getValue
        self.setValue = setValue
    }

    func value() -> Color? {
        getValue()
    }

    func update(_ value: Color) {
        setValue(value)
    }
}

final class BoolInspectableProperty: Identifiable {
    let id: String
    let title: String

    private let getValue: () -> Bool?
    private let setValue: (Bool) -> Void

    init<Owner: AnyObject>(
        id: String,
        title: String,
        owner: Owner,
        keyPath: ReferenceWritableKeyPath<Owner, Bool>
    ) {
        self.id = id
        self.title = title

        let reference = WeakObjectReference(owner)
        getValue = {
            reference.object?[keyPath: keyPath]
        }
        setValue = { value in
            reference.object?[keyPath: keyPath] = value
        }
    }

    init(
        id: String,
        title: String,
        getValue: @escaping () -> Bool?,
        setValue: @escaping (Bool) -> Void
    ) {
        self.id = id
        self.title = title
        self.getValue = getValue
        self.setValue = setValue
    }

    func value() -> Bool? {
        getValue()
    }

    func update(_ value: Bool) {
        setValue(value)
    }
}

final class StringInspectableProperty: Identifiable {
    let id: String
    let title: String

    private let getValue: () -> String?
    private let setValue: (String) -> Void

    init<Owner: AnyObject>(
        id: String,
        title: String,
        owner: Owner,
        keyPath: ReferenceWritableKeyPath<Owner, String>
    ) {
        self.id = id
        self.title = title

        let reference = WeakObjectReference(owner)
        getValue = {
            reference.object?[keyPath: keyPath]
        }
        setValue = { value in
            reference.object?[keyPath: keyPath] = value
        }
    }

    init(
        id: String,
        title: String,
        getValue: @escaping () -> String?,
        setValue: @escaping (String) -> Void
    ) {
        self.id = id
        self.title = title
        self.getValue = getValue
        self.setValue = setValue
    }

    func value() -> String? {
        getValue()
    }

    func update(_ value: String) {
        setValue(value)
    }
}

enum InspectableProperty: Identifiable {
    case float(FloatInspectableProperty)
    case simd2Float(SIMD2FloatInspectableProperty)
    case color(ColorInspectableProperty)
    case bool(BoolInspectableProperty)
    case string(StringInspectableProperty)

    var id: String {
        switch self {
        case let .float(property):
            property.id
        case let .simd2Float(property):
            property.id
        case let .color(property):
            property.id
        case let .bool(property):
            property.id
        case let .string(property):
            property.id
        }
    }
}

protocol Inspectable {
    var inspectorTitle: String { get }
    func inspectableProperties() -> [InspectableProperty]
}
