# FarVolcano (distant voxel volcano)

Made with the same pipeline as the far voxel trees (`Downloads/voxel_far_trees/source`): coarse 10-stud blocks, one solid shell,
banded colours, shared stud pieces with bright rims, split into parts by colour band. Generator: `tools/volcano/build_volcano.py`.

Revision 4 (2026-11-03): about 870 x 680 x 890 studs, 24,000 triangles, 9 parts. Cooler, lighter colours (aerial perspective baked in), no
flat skirt, smoothed slopes. **No lava is painted on the cone** (an earlier version had baked brown/orange lava strips, which stayed
visible after the event) and the caldera lake is baked as dark, cooled rock. All the lava is the event's: the glowing lake comes from the
emissive masks (`FarVolcano_S#_emissive.png`, ids in `emissive_ids.json`), whose strength `VolcanoEventClient` ramps from 0 while the event
runs, and the flows down the cone are drawn by the event too.

- `FarVolcano.glb`: import this (textures embedded). `preview.png`: rough software render.
- Studio set-up (done in the tester): each MeshPart anchored, CanCollide / CanTouch / CastShadow off, CanQuery on (the flows are laid by
  raycasting against it), Material Plastic + MaterialVariant "Incubator One Stud Cavity", SurfaceAppearance.EmissiveMaskContent from
  `emissive_ids.json`, EmissiveTint (255,150,60), EmissiveStrength 0; the model carries the attribute `ManualPlace = true` (keeps your
  placement; without it `VolcanoEventService` moves it to `VolcanoConfig.Position`) and is `Persistent`.
