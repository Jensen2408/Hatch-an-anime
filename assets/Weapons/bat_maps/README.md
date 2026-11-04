# Bat tier texture maps (2026-11-02)

Made from the WoodenBat's SurfaceAppearance colour map (`wood_ColorMap.png`, 512x512) by `tools/weapons/bat_texture_server.js`:
the wood map's luminance is mapped through a shadow / mid / highlight gradient per tier, so the stud pattern, the grip swatches
and the collar stay readable in the tier's colour. The normal map is the wood bat's own.

| Tier | Colour map (uploaded) | Roughness | Metalness |
|---|---|---|---|
| Iron | rbxassetid://72957821521051 | smooth_rough.png = rbxassetid://125695872041779 (wood roughness x0.5) | metal.png = rbxassetid://107827331979590 (16x16, 215) |
| Gold | rbxassetid://121153076879293 | same | same |
| Diamond | rbxassetid://97683963145498 | same | same |
| Oni | rbxassetid://75292626258952 | wood's own | wood's own (plastic) |

Scripts cannot write SurfaceAppearance maps at runtime, so the tier templates (`ServerStorage.Weapons.IronBat` / `GoldenBat` /
`DiamondBat` / `OniBat`) are built in Studio edit mode with `tools/weapons/build_bat_templates.luau` and saved in the place.
Uploaded under the Studio user's creator (Velm Studio), the same as the shop art.
