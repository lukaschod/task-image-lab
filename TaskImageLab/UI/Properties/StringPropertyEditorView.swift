import SwiftUI

struct StringPropertyEditorView: View {
    let property: StringInspectableProperty

    @State private var text: String

    init(property: StringInspectableProperty) {
        self.property = property
        _text = State(initialValue: property.value() ?? "")
    }

    var body: some View {
        HStack {
            Text(property.title)
                .foregroundStyle(.secondary)
            Spacer()
            TextField(property.title, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .multilineTextAlignment(.trailing)
                .onChange(of: text) { _, newValue in
                    property.update(newValue)
                }
                .onSubmit {
                    text = property.value() ?? ""
                }
        }
        .font(.caption)
    }
}
