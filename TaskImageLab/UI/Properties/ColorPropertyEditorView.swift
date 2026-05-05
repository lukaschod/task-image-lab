import SwiftUI

struct ColorPropertyEditorView: View {
    let property: ColorInspectableProperty

    var body: some View {
        HStack {
            Text(property.title)
                .foregroundStyle(.secondary)
            Spacer()
            ColorPicker(
                property.title,
                selection: Binding(
                    get: {
                        property.value() ?? .clear
                    },
                    set: { value in
                        property.update(value)
                    }
                ),
                supportsOpacity: true
            )
            .labelsHidden()
        }
        .font(.caption)
    }
}
