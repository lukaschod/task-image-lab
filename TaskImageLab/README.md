# TODO
- add switch between render and compute rasterization of vector shapes
- cleanup importer to use canvas query
- graphicsbuffers and textures would need pooling and marking which command buffers own resources for safe re-use
- currently my architecture does not work well with effects that would execute in layer order
- property editor view is not very scalable would need to investigate some automatic approaches
- multi-threading for more expensive systems like updateImageTexture as they copy texture content
- currently only vector shapes gets rasterized into texture of fast composition, I think this idea with combined layers would work well, for example if user is modifying layer 5th constantly we could prerender into texture all previous 4 textures
- currently texture during composition in render rasterization uses full quad that could be cut shape to avoid wasted fragment calls
- query system could be refactored to run only, if queries actually exits saving a bit cpu, could be even more optimizied with real ECS, but not sure it is worth it
