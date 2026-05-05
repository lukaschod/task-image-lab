import SwiftUI

struct SIMD2FloatPropertyEditorView: View {
    let property: SIMD2FloatInspectableProperty

    @State private var xText: String
    @State private var yText: String

    init(property: SIMD2FloatInspectableProperty) {
        self.property = property

        let value = property.value() ?? .zero
        _xText = State(initialValue: Self.formatted(value.x))
        _yText = State(initialValue: Self.formatted(value.y))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(property.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                axisField(label: "X", text: $xText)
                axisField(label: "Y", text: $yText)
            }
        }
    }

    private func axisField(label: String, text: Binding<String>) -> some View {
        TextField(label, text: text)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .onChange(of: text.wrappedValue) { _, _ in
                updateValue()
            }
            .onSubmit {
                syncFromProperty()
            }
    }

    private func updateValue() {
        guard
            let x = Float(xText),
            let y = Float(yText)
        else {
            return
        }

        property.update(SIMD2(x, y))
    }

    private func syncFromProperty() {
        let value = property.value() ?? .zero
        xText = Self.formatted(value.x)
        yText = Self.formatted(value.y)
    }

    private static func formatted(_ value: Float) -> String {
        String(format: "%.1f", value)
    }
}
