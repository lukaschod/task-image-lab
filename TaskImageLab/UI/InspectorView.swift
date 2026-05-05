import SwiftUI

struct InspectorView: View {
    let canvas: Canvas
    let onAddColorAdjustment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Properties")
                    .font(.title3.weight(.semibold))
                Spacer()
                Menu {
                    Button("Color Adjustment", action: onAddColorAdjustment)
                } label: {
                    Text("Add")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if let layer = selectedLayer {
                ForEach(inspectableComponents(for: layer), id: \.inspectorTitle) { component in
                    propertySection(title: component.inspectorTitle) {
                        ForEach(component.inspectableProperties()) { property in
                            propertyEditor(for: property)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 240)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
    }

    private var selectedLayer: Layer? {
        let selection: LayerSelection? = canvas.resource()
        return selection?.layer
    }

    @ViewBuilder
    private func propertySection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func propertyEditor(for property: InspectableProperty) -> some View {
        switch property {
        case let .float(property):
            FloatPropertyEditorView(property: property)
        case let .simd2Float(property):
            SIMD2FloatPropertyEditorView(property: property)
        case let .color(property):
            ColorPropertyEditorView(property: property)
        case let .bool(property):
            BoolPropertyEditorView(property: property)
        case let .string(property):
            StringPropertyEditorView(property: property)
        }
    }

    private func inspectableComponents(for layer: Layer) -> [any Inspectable] {
        [layer] + layer.components.compactMap { component in
            component as? any Inspectable
        }
    }
}
