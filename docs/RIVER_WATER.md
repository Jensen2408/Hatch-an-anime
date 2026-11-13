# River Water and High Tide

Animated mesh water for the waterfall river, adapted from the MIC SIDEWAYS! ocean (`CustomWaterWaves` v4, source in the Obsidian vault at `MIC SIDEWAYS!/water-system-client.luau`). It uses river-style waves and its own textures, and adds a high tide event.

## Scripts

| Instance | Source | Role |
| --- | --- | --- |
| `ReplicatedStorage.WaterfallRiver.RiverWaves` | `src/shared/World/WaterfallRiver/RiverWaves.luau` | Shared wave field and tide state. Uses only server time and workspace attributes. |
| `StarterPlayerScripts.RiverWater` | `src/client/World/RiverWater.client.luau` | Renderer: EditableMesh chunks, flowing textures, foam swap and surge crest beams. |
| `ServerScriptService.RiverWater` | `src/server/World/RiverWater.server.luau` | Clears the channel's terrain water at runtime and runs the high tide clock. |
| `ServerScriptService.HighTideService` | `src/server/Services/HighTideService.luau` | Tide schedule, publishing and staff triggers. |

Changes to existing scripts:
- `RollingMotion`: eggs ride the wave field, rise with the tide and pitch over surges.
- `WaterfallRiverMotion` (egg wakes) and `WaterFX` (waterfall ripples) follow the raised water.
- `RiverFlow` only runs as a fallback when mesh water is off.

## How it works

- **Mesh:** a ribbon follows `RiverPath`, with rows every 2 studs and 8 quads across. It reaches 0.8 studs past each wall and is cut into 9 chunks of 60 studs. Chunks near the camera update every frame, mid-range chunks every 2 frames, and far ones every 6.
- **Base layer:** translucent water (`WaterColor` or `RiverConfig.Terrain.WaterColor`), using `RiverFlowAppearance` (flow ripple normal and roughness maps). Its UVs slide downstream at 7.5 studs/s.
- **Foam layer:** a copy of the mesh 0.045 studs higher, using `RiverFoamAppearance`. U runs wall to wall: bank foam sits at both edges, with streaks midstream. It drifts at 5.5 studs/s.
- **Waves:** three short trains run downstream, two of them skewed so they cross into V-shaped chop. Slow standing riffles sit on top, and the plunge pool gets extra chop and rings.
- **Tide fallback:** if `AssetService:CreateEditableMesh` fails, the server keeps the terrain water and sets `workspace.RiverMeshWater = false`. RiverFlow's beams then show the current.

## Waterfall (`StarterPlayerScripts.WaterfallCurtain`, `src/client/World/WaterfallCurtain.client.luau`)

- **Sheet:** a curved two-layer EditableMesh sheet replaces the flat `FallLayer` slabs, which are hidden locally. It runs 3 studs over the cliff top, pours off the lip and arcs out under gravity into the pool. The shape comes from the `FallFX` attributes: `FrontX`, `TopY`, `Z0` and `Z1`.
- **Layers:** the body (`WaterfallBodyAppearance`) sits behind a white streak veil (`WaterfallVeilAppearance`, 0.35 studs in front). Both scroll down the sheet's real length at 16 studs/s.
- **Splash:** the emitters, the `Impact`/`SplashBase` parts and the fall sound follow the arc's landing point.

## High tide

- **Schedule:** every 7 minutes, offset by 150 s from the night cycle, for 50 s. The water takes 8 s to rise and 10 s to fall.
- **Burst:** the waterfall bursts. The arc is thrown far out and the sheet widens about 45%. Every splash emitter fires a burst, a low rumble plays, and nearby cameras shake. The burst eases off over about 2.4 s. After it, the falls keep pouring wider, thicker and faster for the rest of the tide.
- **Water:** the river rises 0.75 studs and its chop roughens. The foam swaps to `RiverTideFoamAppearance`, with wider churned bands.
- **Fast current:** the current runs up to 2.5× (`RiverWaves.FlowBoost`). Ripples and foam race downstream, and the eggs ride it too. `RiverWaves.FlowTime` integrates the boost in closed form, so the server and clients agree and nothing jumps. An egg sped up by the tide reaches the end early and stays sunk until its normal despawn.
- **Egg shower:** while `HighTideActive` is set, `PirateEggFreeConveyor` spawns an egg every 1 s instead of `SpawnInterval`, using the normal rarity and mutation rolls.
- **Surges:** waves pour off the waterfall foot every 5 s and race downstream at 24 studs/s to the east wall. The first one leaves 1.5 s after the burst and is the biggest. Each has a steep foam-lipped front facing downstream (a beam using `tide_crest_foam`) and a train of smaller waves behind it. Every third surge is bigger.
- **Height limits:** the water stays at most 1.4 studs high at the walls, below the 1.6-stud banks. Surge crests can mound up to 2.3 studs mid-channel.
- **Announcements:** scheduled tides show a "HIGH TIDE!" banner in the new `tide` colour.
- **Staff controls:** the panel has START HIGH TIDE and End High Tide buttons. The terminal has `/tide` and `/lowtide`. Both use the actions `StartHighTide {seconds}` and `StopHighTide`.

Tuning constants are at the top of `RiverWaves.luau` (tide and surges) and `RiverWater.client.luau` (mesh, texture speeds and LOD). The schedule constants are at the top of `HighTideService.luau`.

## Place-owned pieces (not in Rojo)

- **Game Settings → Security → Allow Mesh / Image APIs** must be on for EditableMesh.
- **`ReplicatedStorage.WaterfallRiver.WaterTemplates`** holds five SurfaceAppearances: river flow, foam, tide foam, waterfall body and veil. Scripts can't set their maps. The folder also carries their ids as attributes, used for preloading: `CrestFoamTexture`, `TideFoamTexture`, `FoamTexture`, `WaterfallBodyTexture` and `WaterfallVeilTexture`.

## Current look (studded pieces + realistic wave layers)

This replaces the "stud layer + pixel flow layer" and "stud-tile pixels" sections below. The generator's last block, `studPieces`, builds it.

The pieces have no outlines (`BEVEL = 0`), so neighbouring pieces read as one studded surface. Each piece keeps its stud.

There is also an added layer of realistic water waves, like the second ripple layer of the original ocean:
- **River:** a third, translucent mesh (`RiverWaves1..9`, transparency 0.6, water colour) floats 0.1 studs above the pieces. It uses `RiverWaveAppearance`, the first textures' fine ripple normal map `135929536722264`. Its ripples run 32° off the current, so they cross the base layer's.
- **Waterfall:** a third sheet (`WaterfallWaves`, using `WaterfallWaveAppearance`) sits 0.6 studs in front of the pieces, with the same ripples racing down at a slight slant.
- **Cost:** the extra layer brings the river script to about 2.7 ms per frame, up from about 1.8.

Latest tuning:
- **Less foam, more water.** On the river, foam is a thin broken line along the banks plus the odd fleck (`foamCut` .58, band .08); the rest is light, deep and highlight water pieces. On the falls, only the brightest streaks become foam.
- **Gloss without reflection.** Every water layer uses the roughness map `98198092682633` (`water_gloss_roughness.png`, about 0.06 to 0.14). Parts keep Reflectance 0, so there are no mirror reflections.
- **Waterfall back layer.** It no longer uses the old streaked sheet. It's glossy water in the river's colour (transparency 0.15) with the river's realistic ripple map stretched down the fall.
- **Animation.** River pieces sway gently across the current as they drift (`SWAY`, a sine rolling downstream). The wave layers are stronger (transparency 0.5).

### Geometry LOD (2026-11-13, supersedes the river table below)

Before this, every chunk kept the full grid (rows every 2 studs, 8 quads across) at every distance; LOD only changed how often it was updated. Now each 60-stud chunk owns three mesh sets and shows one:

| LOD | Distance (nearest water in the chunk) | Mesh | Updates |
| --- | --- | --- | --- |
| 0 | under 120 studs | Full grid, 3 layers (water, foam, ripple sheen) | Waves every frame |
| 1 | 120 to 280 studs | Rows up to 8 studs apart (fewer on bends, edges within 0.15 studs of the full ribbon), 2 quads across; water + foam | Textures slide every 2 frames |
| 2 | beyond 280 studs | Rows up to 30 studs apart (edges within 0.3 studs), 1 quad across; water + foam | Textures slide every 6 frames |

- **No seams:** every level keeps the full 9-vertex end rows and zips them to its coarse interior, so neighbours share identical seam vertices at any mix of levels (no T-junction cracks).
- **No popping:** waves fade to flat by 120 studs, and a chunk only leaves LOD 0 once all its water is at least 120 studs away (10-stud hysteresis before going coarser). A level is brought up to date in the frame it is switched to, and every chunk of a level updates on the same frames, so the sliding textures line up across seams.
- **Near savings:** a full-grid vertex already faded flat writes only its UVs; chunks whose bounding sphere is fully outside the camera view are not updated.
- **Other scripts:** the full parts keep their names (`RiverWater<i>`, `RiverFoam<i>`, `RiverWaves<i>`) and stay parented, hidden by Transparency, because VolcanoEventClient builds its lava overlay from them. Coarse parts are `RiverCoarseWater<lod>_<i>` / `RiverCoarseFoam<lod>_<i>`; they copy the full parts' LocalTransparencyModifier (tide foam fade, volcano fade), rise with the tide, and get the tide foam swap.
- **Debug attributes** on `workspace.WaterfallRiver`: `RiverWaterTriangles` (triangles on show, all layers) and `RiverWaterVertexWrites` (mesh writes in the sampled frame), plus the existing `RiverWaterLOD`.
- **Measured** (Studio Play, same session, scripted cameras; frame times are noisy): far overview 8,640 → 356 triangles on show, mesh writes ~50k/s → ~4k/s; near, same 5/3/1 LOD split, writes ~12.5k → ~6.8k per frame, river script 1.70 → 1.33–1.45 ms. Simple Water near: 768 triangles, 0.19 ms.

### Waterfall geometry LOD (2026-11-13, supersedes the waterfall table below)

The falls are one sheet, so there are no seams. Each body and veil layer now has three meshes; the ripple sheen exists only at LOD 0.

| LOD | Distance | Mesh (body + veil) | Updates |
| --- | --- | --- | --- |
| 0 | under 140 studs | Full sheet, 39 rows x 8 quads, plus sheen | Reshaped every frame (wobble) |
| 1 | 140 to 320 studs | Every 2nd row and column (20 x 4 quads) | Reshaped only when the tide or burst moves the arc; textures every 2 frames |
| 2 | beyond 320 studs | About every 4th row (keeps the lip), every 4th column (12 x 2 quads) | As LOD 1, every 6 frames |

- Every level samples the same sheet function at a subset of the full grid's rows and columns, always including the edges, the lip row and the foot. Texture V always comes from the full sheet's length, so the streaks don't move on a switch.
- The level switched to is reshaped in the same frame, before it shows. There is 10-stud hysteresis before going coarser.
- The full parts keep their names (`WaterfallBody`, `WaterfallVeil`, `WaterfallWaves`); the coarse parts are `WaterfallBodyLod1/2` and `WaterfallVeilLod1/2` in the same `WaterfallCurtainLocal` folder. VolcanoEventClient fades every MeshPart in that folder and builds its overlay from `WaterfallBody`.
- Debug attributes on `workspace.WaterfallRiver`: `WaterfallLOD`, `WaterfallTriangles`, `WaterfallWrites`, `WaterfallMs`.
- Measured in Studio Play: triangles on show 1,824 / 304 / 88 at LOD 0/1/2 (before: 1,824 / 1,216 / 1,216). Texture writes per update frame 200 at LOD 1 and 72 at LOD 2 (before: 702). During a burst at LOD 1, 600 writes per reshape (before: 2,106).

### Volcano lava and the geometry LOD (2026-11-13)

VolcanoEventClient's lava overlays share their water mesh. Far away that is now the coarse mesh, because the full mesh is hidden and no longer updated. So each coarse level gets its own lava overlay, built from `RiverCoarseWater<lod>_<i>` or `WaterfallBodyLod<lod>` and named `VolcanoLava<i>Lod<lod>` / `VolcanoLavaFallLod<lod>`. Only the overlay on the level that is showing is visible. The full overlay keeps the chunk's light, steam and sounds. The curtain fade skips every `VolcanoLava*` part.

Checked in Studio Play by jumping into the lava phase:
- River chunks at LOD 0/1/2 each showed exactly the matching lava overlay.
- The waterfall lava followed the falls through LOD 0/1/2 at 40, 200 and 400 studs.
- The lava was continuous across a LOD 0/1 boundary.
- After the event, every overlay was removed.

### Level of detail and Simple Water (2026-10-26, written in source, not yet synced)

Playtested by pasting the client scripts into a Play session (checksum-verified). River script time from the same river view: old 3.51 ms, Detailed 1.70 ms, Simple 0.30 ms. Forced high tide burst worked with no errors. The Settings switch UI was not tested (Studio's `MusicSettings` is a newer version than this copy).

**River LOD** (`RiverWater.client.luau`): each chunk picks a level from the camera's distance to its nearest end.

| LOD | Distance | What updates |
| --- | --- | --- |
| 0 | under 120 studs | Full waves on all three layers, every frame. Wave height fades to flat by 120 studs, so neighbouring chunks meet without a step. |
| 1 | 120 to 280 studs | One flatten pass, then only the textures slide (2 writes per vertex instead of 9), every 2 frames. The ripple sheen layer is hidden. |
| 2 | beyond 280 studs | As LOD 1, every 6 frames. |

- **Off-screen:** chunks more than 45 studs behind the camera plane aren't updated.
- **Tide:** the tide level now moves the chunk parts (3 CFrame writes per chunk, only while the level changes) instead of every vertex. The tide therefore shows at every LOD.
- **Debug attributes** on `workspace.WaterfallRiver`: `RiverWaterLOD` (chunks at LOD 0/1/2) and `RiverWaterSimple`.

**Waterfall LOD** (`WaterfallCurtain.client.luau`):

| LOD | Distance | What updates |
| --- | --- | --- |
| 0 | under 140 studs | The shape is rebuilt every frame (wobble and run swell). |
| 1 | 140 to 320 studs | The wobble is frozen and the shape is rebuilt only when the tide or the burst changes the arc. Otherwise only the textures slide, every 2 frames. The ripple sheen is hidden. |
| 2 | beyond 320 studs | As LOD 1, every 6 frames. |

The falls skip updates entirely while they're behind the camera. The splash emitters and sound keep running.

**Simple Water** (Settings → "Detailed water" off):
- **Saving:** the switch writes the player attribute `SimpleWater`, saved through `PlayerDataService` (`SETTING_TYPES.SimpleWater`). `ReplicatedStorage.WaterfallRiver.WaterQuality.IsSimple(player)` decides.
- **Default:** before the player chooses, Roblox graphics quality 1–3 starts on Simple Water.
- **Effect:** every river chunk and the falls are capped at LOD 1. The water is flat but still flows, the tide still rises, surge crest beams lie on the flat surface, and the ripple sheen is off.
- **Eggs:** they still bob on the full wave field, which is computed on the server.

### Current: studded pixel water (supersedes everything below)

This is the pixel-waterfall look: translucent pixel water, pixel foam with clear gaps, and some pixels shinier than others, all sliding smoothly with no flipbook.
- **Pixel size.** Every pixel is 1 stud, matching the ground's tile size, and carries the game's stud.
- **River base** (`RiverFlowAppearance`, Overlay on the translucent water colour):
  - 16 × 16 pixels per 16-stud tile.
  - Light and dark pixel shades come from the first ripple map, with stud rims, stud and facet normals.
  - Roughness is set per pixel: most pixels are satin (0.18 to 0.42), about one in five is near-mirror (0.04), and stud rims are rougher.
- **River foam** (`RiverFoamAppearance` / `RiverTideFoamAppearance`): 14 pixels wall to wall × 32 per 32-stud tile, with clear gaps. It slides at 5.5 studs/s.
- **Waterfall** (`WaterfallBodyAppearance` / `WaterfallVeilAppearance`): 16 × 32 pixels of blue streaks with white front streaks, studs, and the same per-pixel roughness. The front layer slides 1.35 times as fast as the body.
- **Wave layers.** Kept as a faint sheen (transparency 0.82, pale tint).
- **Generator.** The last block of `tools/water/river-water-textures.js` (`pixelRoughness` plus `studTiles`) makes `river_px_*`, `river_foam_px*`, `waterfall_*_px*` and `tide_crest_px_studs`.

### Solid, shiny, animated pieces (superseded)

- **Solid pieces.** Every piece is fully opaque, and there are no see-through gaps. Cells with no ripple or foam become a light-blue fill piece. The piece templates use Overlay mode, so they render as solid surfaces.
- **Shine.** Pieces use `piece_shine_roughness.png` (`129055264185934`, roughness about 0.02 to 0.05). Reflectance stays 0.
- **Pixel animation (flipbook).** Each piece set has 4 frames, each sampling the ripple and foam fields at a small cell offset. The scripts swap the SurfaceAppearance on each frame change: `RiverPieces1..4`, `RiverTidePieces1..4` during high tide, and `WaterfallPieces1..4`.
  - Speed: about 5 fps on the river and 6 on the falls, faster as the current speeds up.
  - All frames are preloaded from the templates folder's `PreloadTextures` attribute.
- **Wave layers.** They're now pale (200, 244, 252) and more see-through (0.72), so they add ripple glints without darkening the pieces.
- **Templates.** All 16 SurfaceAppearances are defined in `WaterTemplates.model.json` and synced by Rojo.

- **Studded pieces:** the water and foam are 1-stud pieces. Each one is a crisp square with a bevelled edge and the game's stud on it, so the studs belong to the pieces. There are four kinds: white foam, highlight, light water and deep water.
  - **River:** the pieces are the piece layer (`RiverFoamAppearance`, high tide version `RiverTideFoamAppearance`). They drift downstream at 6 studs/s, faster at high tide, and the pattern repeats every 32 studs.
  - **Waterfall:** they are the front layer (`WaterfallVeilAppearance`), sliding down the sheet.
  - **Crests:** the surge crests use foam pieces too.
- **Gaps:** gaps between pieces show the realistic water. That includes the foam's bubbles, which come out as square, stud-sized holes. The patterns come from the first textures: bank lace and streaks, the crossing V ripples, and the waterfall streaks.
- **Realistic waves under the pieces:**
  - **River:** the first, smooth river ripple map (`RiverFlowAppearance`: normal `130231786534226`, roughness `98622498250671`) slides downstream at 7.5 studs/s.
  - **Waterfall:** an unpixelated streaked sheet (`WaterfallBodyAppearance`) slides down behind the pieces.
- **Old waterfall removed:** the slab parts are now in `ServerStorage.RiverBackups.OldSlabWaterfall`. The streak parts in `WaterfallFallMotion` are gone, and its foam-boil bubbles are whole-stud blocks in the ground's stud material, bobbing on the water.
- **Templates in Rojo:** `src/shared/World/WaterfallRiver/WaterTemplates.model.json` now defines `ReplicatedStorage.WaterfallRiver.WaterTemplates`, including its texture-id attributes, so it no longer depends on saving the place.

| Map | Asset |
| --- | --- |
| River pieces (colour / normal) | `135356985807466` / `120254642247312` |
| River pieces, high tide (colour / normal) | `74281091003179` / `78390342477313` |
| Waterfall pieces (colour / normal) | `123377541100160` / `97335977804544` |
| Waterfall realistic sheet (colour; normal `135929536722264`) | `74698928121109` |
| Surge crest pieces (beam) | `126053038287983` |

## Stud layer + pixel flow layer (superseded)

- **Studs** sit on the layer that never moves. The ground's studs are 1 stud apart in 4-stud panels, laid out from the `RiverGround` part's centre (measured in Studio: stud centres at x ≈ .40, z ≈ .55).
  - The river's base layer uses the stud maps (`source/stud_normal.png` and `stud_shade.png`, one 4-stud panel each) with UVs `(world - RiverGround.Position) / 4`. They are set once, so the water studs match the ground's studs in size and position.
  - The waterfall body carries the same studs, fixed to the sheet.
- **Motion** comes from a separate layer of 1-stud pixels with no studs, so it can slide smoothly. Its patterns come from the first textures: crossing V-ripples in light and dark shades, bank foam and streaks, the tide churn, and the waterfall streaks.
  - The river's second mesh scrolls it downstream at 7 studs/s, faster at high tide.
  - The waterfall's front layer scrolls it down the sheet.
- **Cliff-top channel:** the terrain water on top of the cliff is cleared at runtime by `ServerScriptService.RiverWater`. The waterfall sheet now starts 31.5 studs back at x −314 and runs along that channel at y 57.97 before pouring off the lip. The values can be overridden with the `FallFX` attributes `PoolBackX` and `PoolSurfaceY`.

| Map | Asset |
| --- | --- |
| Stud normal (river base, waterfall body) | `rbxassetid://129405936087447` |
| Stud rim overlay (river base, Overlay) | `rbxassetid://79587342856591` |
| Stud roughness (river base) | `rbxassetid://122583763239415` |
| Waterfall stud colour | `rbxassetid://87036116261840` |
| River flow pixels | `rbxassetid://126730161723838` |
| River flow pixels, high tide | `rbxassetid://100122876834655` |
| Surge crest pixels (beam) | `rbxassetid://110432278605164` |
| Waterfall flow pixels | `rbxassetid://88670308709624` |

The generator's last block writes these (`river_flow_px*.png`, `tide_crest_px.png`, `waterfall_flow_px.png`, `waterfall_stud_color.png`). The stud maps come from `tools/water/stud-water-maps.js`.

## Texture assets (stud-tile pixels, superseded)

Generator: `tools/water/river-water-textures.js`. Run it with `node tools/water/river-water-textures.js assets/water`; it writes the PNGs and previews to `assets/water/`. It reads the game's stud maps from `assets/water/source/stud_normal.png` and `stud_shade.png`.

Every pixel of every texture is one ground tile: 2 × 2 studs with a stud cavity in it, the same size and look as the "Incubator One Stud Cavity" ground (8 studs per 4-stud tile). The generator's `studTiles` pass does this:
1. It averages each source map into cells.
2. It snaps each cell's colour, alpha (0, 0.5, 0.85 or 1) and facet tilt to a few steps.
3. It draws each cell with the stud's relief and dark cavity rim.

The textures are mapped at one cell per 2 studs:

| Texture | Grid | Area covered |
| --- | --- | --- |
| River ripples | 8 × 8 cells | 16 studs |
| Foam | 7 × 18 cells | wall to wall × 36 studs |
| Waterfall | 8 × 16 cells | 16 × 32 studs |

The scripts scroll the textures in whole tiles, so the water hops like pixel art instead of sliding. The river ripple tiles go light or dark with the ripples underneath.

| Map | Asset |
| --- | --- |
| Ripple tile normal | `rbxassetid://77632638194193` |
| Ripple tile colour (Overlay: light and dark tiles, stud rims) | `rbxassetid://119274068933172` |
| Ripple tile roughness | `rbxassetid://121790585508744` |
| Foam stud normal (foam layers) | `rbxassetid://137158672505811` |
| River foam | `rbxassetid://86541543059465` |
| Tide foam | `rbxassetid://91728556383903` |
| Surge crest foam (beam) | `rbxassetid://128049068624460` |
| Waterfall body | `rbxassetid://137404775284955` |
| Waterfall veil | `rbxassetid://113700273052241` |
| Waterfall stud normal | `rbxassetid://120646466353755` |

Earlier versions are no longer used. That covers the smooth maps, the first pixel maps, and the separate stud layer (`tools/water/stud-water-maps.js`, `RiverStudAppearance`), whose studs now live inside the pixels.

## Cost (Studio Play, camera mid-river)

| Water | Script time |
| --- | --- |
| Calm | about 1.9 ms per frame |
| High tide | about 2.1 ms per frame |

The first build was 5.6 ms per frame. Each vertex's wave terms are now computed once at startup, and the grid is coarser.

## 2026-11-06 subject wakes

Egg rings removed. WaterfallRiverMotion now uses an eight-frame pixel foam atlas (135265028807430) with broken V edges and animated eddies. One SurfaceGui carrier per nearby subject; no ordinary wake Trails/Beams. Pixelated resampling, corrected top-face orientation, 32-subject cap and 190-stud culling. Impact rings remain separate. Short water splash sounds follow animated foot reversals instead of a continuous loop. Build and fresh Studio Play checks passed; no formal FPS benchmark or place publication.

V4 follow-up: separate egg/player atlases (97974454229539 / 102403119137953), larger 32x48 logical pixels, widened egg hull foam with subject at 30% of length, 7.5x8.5 player wash. Splash 133191168318787 has no dark outline. Cube-like particle sprite 102688400056466: six per planted foot, 18 on jump, 12–36 on landing. Source art: tools/water/wake-detail.js. Build/sync/Play verified; jump and landing observed. Initial asset generation delays cleared for visible tests. No FPS benchmark or place publication.

V5 supersedes the sprite art: no rings or sprites. Six solid foam flecks per egg, four per player. Shared 160-cube pool simulates ballistic splashes; river contact spawns two smaller nonrecursive droplets. Footsteps/jumps/impacts retain audio. Build/compile/sync and runtime contact test passed; no FPS benchmark or place publication. Old texture candidates are unused.

V6 supersedes V5: restored burst-only particle splashes, analytically timed secondary water spray, and outline-free player impact rings. Eggs remain ring-free. Wakes use 24 egg / 16 player solid foam segments in open shoulders and fading tails, no sprite animation. Build/sync/compile/Play passed; particles and player ring observed, egg wakes image-free; no FPS benchmark or place publication.

V7: visible part wakes are prohibited by user preference. Static pixel textures replace all foam geometry; invisible positioning carrier only, no frame animation. Egg/player assets 84805120069288 / 92452745065673; redesigned pale double broken ring 128865490482400 for player impacts only. Particle splashes retained. Generator tools/water/wake-static.js. Build/compile/sync and structural runtime verified, visual approval pending.

V8: Minecraft reference-inspired open hull foam 137166137844169 + static textured Trail 130272470799897 retaining curved movement history; no sprite frames/visible foam Parts. Player lifetime 1.15 s / max 14 studs, eggs 1.5 s / 22 studs. Narrow particle packets get analytic landing spray/contact decals (not exact per-particle collision). Build, sync, compile, Play screenshots and filtered error check passed. No FPS benchmark/place publication.

V9: coarse binary-alpha foam textures 109788613874435/76004795890424. History now uses 10 surface-reprojected Beam spans per subject (Trail old heights clipped moving waves), +0.24 clearance. Hull surrounding samples +0.25. Rapids crest had +0.08 beneath sheen +0.10; replaced broad plane with six shorter strips +0.22. Build/sync/compile/high-tide runtime passed. More spans/samples; FPS and every camera/LOD not verified. Not place-published.

V10: history texture repeat follows hull diameter, zero texture speed, cumulative-distance UV phase. Width 94–100% diameter matches square hull pixel cells. Egg hull 11% tighter (radius factor 2.85), stern offset .28 radius. Build/sync/compile/Play sample checked; not published.

V11: egg diameter factor 2.65 (~7% smaller). Rapids restored to full Stretch crest image, no strip offsets/repetition; endpoint/interior wave samples determine clearance. V9 strip mapping was broken. Build/sync/compile/high-tide Play verified, not published.

V12: dry dark-board visual tests with player/small egg/large egg; matched painted foam widths via .70/.67 ratio rather than transparent image bounds. Live leading history span removes sample gap; zero-length spans disabled. Build/diff/source execution and compile verified; test board removed, not published.

V13: grounded player wake emission, no live airborne head; history 1.8s with adaptive spacing and progressive fade. Coarse 32-cell circular splash 77297633636595, dry-tested at two sizes. Build/dry tests/Play checked; not published.

V14: static origin texture 120435341960932 replaces round bubble with rounded nose/open parallel shoulders; stern starts diameter*.15+.1 at shoulder end row .65. Dry player/egg before/after views and asset preload passed; build/compile/source sync checked; preview cleaned, not published.

V15: continuous ellipse front cap, shorter forward reach, closed-nose asset 110842520915298. Build/compile/Play preload pass; dry cap visibility inconclusive, user review pending. No publication.
