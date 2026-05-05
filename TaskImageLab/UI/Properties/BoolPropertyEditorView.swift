import SwiftUI

struct BoolPropertyEditorView: View {
    let property: BoolInspectableProperty

    var body: some View {
        Toggle(isOn: binding) {
            Text(property.title)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .toggleStyle(.switch)
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { property.value() ?? false },
            set: { property.update($0) }
        )
    }
}
