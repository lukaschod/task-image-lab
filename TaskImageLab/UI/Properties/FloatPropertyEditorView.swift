import SwiftUI

struct FloatPropertyEditorView: View {
    let property: FloatInspectableProperty

    @State private var text: String

    init(property: FloatInspectableProperty) {
        self.property = property
        _text = State(initialValue: Self.formatted(property.value() ?? 0))
    }

    var body: some View {
        HStack {
            Text(property.title)
                .foregroundStyle(.secondary)
            Spacer()
            TextField(property.title, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 96)
                .multilineTextAlignment(.trailing)
                .onChange(of: text) { _, _ in
                    updateValue()
                }
                .onSubmit {
                    syncFromProperty()
                }
        }
        .font(.caption)
    }

    private func updateValue() {
        guard let value = Float(text) else {
            return
        }

        property.update(value)
    }

    private func syncFromProperty() {
        text = Self.formatted(property.value() ?? 0)
    }

    private static func formatted(_ value: Float) -> String {
        String(format: "%.1f", value)
    }
}
