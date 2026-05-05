# TaskImageLab

Small image editor prototype built around a lightweight ECS-style core.
`Canvas` stores layers, components, resources, and systems. Each frame runs
systems in order, so data flows through explicit update/render steps.
`RenderGraph` is used to build ordering between GPU work instead of letting
passes depend on ad-hoc call structure. A lot of the design is biased toward
caching so unchanged layers and intermediate results can avoid unnecessary work.

```text
Canvas
 |- Layers + Components
 |- Resources
 `- Systems
      |
      v
   update -> rasterize -> compose -> preview -> resetChanged
```

```swift
canvas
    .addResource(Textures(device: device))
    .addSystem(name: "updateImageTexture", updateImageTexture)

if let textures: Textures = canvas.resource() {
    // shared state
}

for (layer, transform) in canvas.query(Transform.self) {
    // per-layer component access
}
```

## Rendering Modes

### Vector Shapes
- `Fill Rasterizer (Compute)`: compute-based fill rasterization into textures.
- `Triangulation (Render Pass)`: triangulate vector geometry and draw it through a render pass.

## TODO

### Features
- Cleanup importer to use canvas queries.
- Improve property editor scalability with a more automatic editing model.
- Make triangulation rendering work with the color adjustment effect.

### Performance
- Add pooling for `GraphicsBuffers` and `Textures`, with safer command-buffer ownership tracking.
- Parallelize expensive systems such as `updateImageTexture`.
- Pre-render stable earlier layers into cached textures when later layers are edited repeatedly.
- Cut composed quads to tighter shapes to reduce wasted fragment work.
- Skip query/system work when no matching components exist, if that stays worth the complexity.
