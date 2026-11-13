# Temple LOD and particle budget

## Temple LOD (`StarterPlayerScripts.TempleLOD`, `src/client/Temple/TempleLOD.client.luau`)

Client-only. Distance is from the camera to the nearest point of each plot temple's bounding box, with 12 studs of
hysteresis. Low graphics quality (levels 1-3) scales the distances by 0.65.

| Level | Distance | What changes |
| --- | --- | --- |
| LOD 0 | < 140 | everything |
| LOD 1 | 140-300 | lights parked (Parent = nil, never `Enabled`: `TempleOccupancy` owns it), lanterns / Halloween decor and parts under 2 studs hidden |
| LOD 2 | > 300 | parts under 4 studs and string lights hidden, parts under 8 studs stop casting shadows, **temple swapped for its proxy** |

Parts are hidden with `LocalTransparencyModifier`, so server `Transparency` is never touched.

### The proxy (`ReplicatedStorage.TempleProxy`, `src/shared/Temple/TempleProxy.luau`)

The temple MeshParts are voxel meshes cut into one quad per texture tile (a 44 x 50 floor slab is 749 triangles), and
each MeshPart has its own SurfaceAppearance. A far temple therefore costs ~20k triangles and ~260 draw calls.

At LOD 2 the temple is drawn as one vertex-coloured MeshPart (`workspace.TempleLODProxies`, local), built from
`ReplicatedStorage.TempleProxyMeshes`:

- Per MeshId, the mesh's faces are grouped by plane (sloped roof planes included), rasterised on the plane's own vertex
  grid and merged into rectangles of similar colour. The outline stays: roof tiers, posts, rafters, steps.
- Each rectangle is coloured with the average of its texture tile, multiplied at runtime by the theme tint
  (`SurfaceAppearance.Color`). Royal Gold (Metal + gold Color) uses the tile luminance times the gold colour.
- Plain block Parts are added as boxes in their own colour. Parts under 4 studs are hidden, not drawn.
- MeshParts with no baked record (new meshes not baked yet) stay visible as they are. A missing bake costs savings, not looks.

The proxy is built the first time a temple reaches LOD 2. It is thrown away and rebuilt after 3 quiet seconds when the
temple changes: parts added or removed (upgrade, build animation) or the `TempleAppearance` attribute (theme).
Debug attributes on the script: `ProxiesActive`, `ProxyTriangles`.

### Baking `TempleProxyMeshes` (`tools/temple_lod/bake_temple_proxies.luau`)

Game scripts cannot read SurfaceAppearance maps, so the tile colours are baked in Studio Edit mode from the ColorMap
images (`AssetService:CreateEditableImageAsync`), and the meshes from `CreateEditableMeshAsync`. Run the tool as a
ModuleScript from the command bar or MCP; its header has the exact calls (~1 mesh/s, ~15 min for all temples plus
`ServerStorage.TempleUpgradeTemplates`).

`TempleProxyMeshes` is **generated Studio data** with children `Chunk1..N`, because Studio caps a script's Source at
200,000 characters. It is not a Rojo file. Like a model, it lives in the place; `$ignoreUnknownInstances` keeps Rojo
off it. **Re-bake after changing temple meshes, their textures, or the upgrade templates.**

## Particle budget (`StarterPlayerScripts.ParticleBudget`, `src/client/Effects/ParticleBudget.client.luau`)

A flat cut with no distance LOD: every `ParticleEmitter` in the workspace runs at 0.5 x its Rate, or 0.3 x on low
graphics quality.

- Whenever anyone else sets Rate (server replication, Arena / Volcano / portal / Gold FX scripts), that value becomes
  the new base and is cut again. Our own writes are told apart by value, so this works with deferred signals.
- The unscaled base is kept in the attribute `ParticleBudgetBase`. Scripts that cache an emitter's Rate must read that
  first (`WaterfallCurtain` does), or the cut compounds.
- To opt an emitter out, give it the attribute `FullParticleRate = true`.
- `:Emit()` bursts are not affected.
