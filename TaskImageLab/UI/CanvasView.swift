import SwiftUI
import MetalKit
import QuartzCore

struct CanvasView: View {
    let renderer: Renderer
    let canvasSize: CGSize
    @Binding var zoomScale: CGFloat
    @Binding var committedZoomScale: CGFloat
    @Binding var isDropTargeted: Bool
    let onCanvasInteraction: () -> Void

    private let workspacePadding: CGFloat = 140

    @State private var dragLayer: Layer?
    @State private var dragLayerStartTranslation: SIMD2<Float> = .zero
    @State private var dragStartCanvasPoint: SIMD2<Float> = .zero

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            MetalCanvasArtboard(
                renderer: renderer,
                canvasSize: canvasSize,
                zoomScale: zoomScale
            )
            .contentShape(Rectangle())
            .gesture(canvasDragGesture)
        }
        .background(Color.clear)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(.white.opacity(0.65), lineWidth: 3)
                    .padding(18)
            }
        }
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    zoomScale = min(max(committedZoomScale * value, 0.25), 16)
                }
                .onEnded { value in
                    committedZoomScale = min(max(committedZoomScale * value, 0.25), 16)
                    zoomScale = committedZoomScale
                }
        )
    }

    private var canvasDragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let canvasPoint = SIMD2<Float>(
                    Float(value.location.x / zoomScale),
                    Float(value.location.y / zoomScale)
                )

                if dragLayer == nil {
                    let hitLayer = renderer.layer(at: canvasPoint)
                    renderer.selectLayer(hitLayer)
                    onCanvasInteraction()

                    guard
                        let hitLayer,
                        let transform: Transform = renderer.canvas.getComponent(layer: hitLayer)
                    else {
                        return
                    }

                    dragLayer = hitLayer
                    dragLayerStartTranslation = transform.translation
                    dragStartCanvasPoint = canvasPoint
                }

                guard let dragLayer else {
                    return
                }

                let delta = canvasPoint - dragStartCanvasPoint
                renderer.moveLayer(dragLayer, to: dragLayerStartTranslation + delta)
                //onCanvasInteraction()
            }
            .onEnded { _ in
                dragLayer = nil
            }
    }
}

private struct MetalCanvasArtboard: View {
    let renderer: Renderer
    let canvasSize: CGSize
    let zoomScale: CGFloat

    var body: some View {
        MetalCanvasRepresentable(renderer: renderer, canvasSize: canvasSize)
            .frame(
                width: canvasSize.width * zoomScale,
                height: canvasSize.height * zoomScale
            )
            .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }
}

private struct MetalCanvasRepresentable: NSViewRepresentable {
    let renderer: Renderer
    let canvasSize: CGSize

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(
            red: 1.0,
            green: 1.0,
            blue: 1.0,
            alpha: 1.0
        )
        view.delegate = renderer
        view.framebufferOnly = false
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.autoResizeDrawable = false
        view.layer?.magnificationFilter = .nearest
        view.layer?.minificationFilter = .nearest
        view.drawableSize = canvasSize

        renderer.configure(device: view.device)
        renderer.mtkView(view, drawableSizeWillChange: canvasSize)

        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        if nsView.drawableSize != canvasSize {
            nsView.drawableSize = canvasSize
            renderer.mtkView(nsView, drawableSizeWillChange: canvasSize)
        }
    }
}
