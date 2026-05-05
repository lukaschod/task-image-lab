import SwiftUI

struct HierarchyView: View {
    let importedFileName: String
    let canvas: Canvas
    let layers: [LayerListItem]
    let onChooseFile: () -> Void
    let onCreateRectangle: () -> Void
    let onCreateEllipse: () -> Void
    let onStressTest: () -> Void
    let onSelectLayer: (Layer?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Layers")
                    .font(.title3.weight(.semibold))
                Spacer()
                Menu {
                    Button("Choose File", action: onChooseFile)
                    Button("Rectangle", action: onCreateRectangle)
                    Button("Ellipse", action: onCreateEllipse)
                    Button("Stress Test", action: onStressTest)
                } label: {
                    Text("Import")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(layers) { layer in
                        HStack(spacing: 10) {
                            LayerPreviewView(canvas: canvas, layer: layer)

                            Text(layer.name)
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(layer.isSelected ? Color.accentColor.opacity(0.3) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(
                                    layer.isSelected ? Color.accentColor.opacity(0.65) : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            onSelectLayer(layer.layer)
                        }
                    }

                    if layers.isEmpty {
                        Text("Import an SVG or PNG to populate layers.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .padding(18)
        .frame(width: 280)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct LayerPreviewView: View {
    let canvas: Canvas
    let layer: LayerListItem

    private let previewFrame = CGSize(width: 32, height: 32)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))

            if let previewImage {
                SwiftUI.Image(nsImage: previewImage)
                    .resizable()
                    .aspectRatio(previewAspectRatio, contentMode: .fit)
                    .frame(width: previewFrame.width - 6, height: previewFrame.height - 6)
            } else {
                Circle()
                    .fill(layer.isVisible ? Color.white.opacity(0.9) : Color.white.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(width: previewFrame.width, height: previewFrame.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var previewImage: NSImage? {
        guard
            let layer = layer.layer,
            let _: Texture = canvas.getComponent(layer: layer),
            let preview: Preview = canvas.getComponent(layer: layer)
        else {
            return nil
        }

        return preview.preview
    }

    private var previewAspectRatio: CGFloat {
        guard
            let layer = layer.layer,
            let transform: Transform = canvas.getComponent(layer: layer),
            transform.size.y > 0
        else {
            return 1
        }

        return CGFloat(transform.size.x / transform.size.y)
    }
}
