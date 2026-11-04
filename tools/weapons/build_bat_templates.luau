--[[ Run in Studio EDIT mode (command bar / Studio MCP execute_luau). Scripts cannot write SurfaceAppearance maps at
runtime ("lacking capability Plugin"), so the textured bat tiers are built here and saved in the place:
ServerStorage.Weapons.<key> = a clone of WoodenBat whose SurfaceAppearance has the tier's tinted colour map (and the
roughness / metalness maps) from ReplicatedStorage.ShopSystem.ShopConfig.Weapons. Re-run after changing a tier's
maps: it replaces the existing tier templates. WeaponGiver (runtime) adds the stats attributes and uses these templates;
the attribute TintedMaps = true tells it the textures are already in place.
The tinted maps come from tools/weapons/bat_texture_server.js (wood colour map -> luminance -> tier gradient).
]]
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShopConfig = require(ReplicatedStorage.ShopSystem.ShopConfig)
local weapons = ServerStorage.Weapons
local base = weapons:FindFirstChild(ShopConfig.DefaultWeapon or "WoodenBat")
assert(base, "WoodenBat template missing")
local MAPS = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }
local built = {}
for _, weapon in ShopConfig.Weapons do
    if weapon.key ~= base.Name and weapon.colorMap then
        local old = weapons:FindFirstChild(weapon.key)
        if old then
            old:Destroy()
        end
        local tool = base:Clone()
        tool.Name = weapon.key
        local handle = tool.Handle
        local surface = handle:FindFirstChildOfClass("SurfaceAppearance")
        surface.ColorMap = weapon.colorMap
        if weapon.roughnessMap then
            surface.RoughnessMap = weapon.roughnessMap
        end
        if weapon.metalnessMap then
            surface.MetalnessMap = weapon.metalnessMap
        end
        for _, map in MAPS do
            surface:SetAttribute("Preload" .. map, surface[map]) -- WeaponPreloadClient reads these
        end
        handle.Color = weapon.tint
        handle.Material = weapon.material or Enum.Material.SmoothPlastic
        tool:SetAttribute("TintedMaps", true)
        tool.Parent = weapons
        table.insert(built, weapon.key)
    end
end
return "built " .. table.concat(built, ", ")
