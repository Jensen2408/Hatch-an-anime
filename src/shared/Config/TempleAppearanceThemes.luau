--[[ ReplicatedStorage.TempleAppearanceThemes  (ModuleScript, shared)
Temple appearance themes (array order = order shown to players) and Themes.Apply, which repaints a
temple model in place and records the choice as attribute "TempleAppearance".
  Halloween: restores the HalloweenColor / HalloweenSurfaceColor attributes stored on each part.
  Original:  leaves the parts untouched.
  Gold:      metal finish + swaps each SurfaceAppearance for its ReplicatedStorage.GoldTempleSurfaces preset.
  others:    multiplies the colour (or SurfaceAppearance colour) by the theme Tint.
]]
local Themes = {
    { Id = "Halloween", Name = "Halloween", Tint = Color3.fromRGB(151, 92, 191) },
    { Id = "Original", Name = "Classic", Tint = Color3.fromRGB(255, 255, 255) },
    { Id = "Jade", Name = "Jade Garden", Tint = Color3.fromRGB(174, 235, 193) },
    { Id = "Sakura", Name = "Sakura", Tint = Color3.fromRGB(255, 188, 211) },
    { Id = "Midnight", Name = "Midnight", Tint = Color3.fromRGB(164, 189, 246) },
    { Id = "Amber", Name = "Amber", Tint = Color3.fromRGB(255, 221, 160) },
    { Id = "Gold", Name = "Royal Gold", Tint = Color3.fromRGB(255, 194, 66) },
}
-- Unknown ids fall back to Themes[2] ("Original").
function Themes.Apply(model, id)
    local theme = Themes[2]
    for _, candidate in ipairs(Themes) do
        if candidate.Id == id then
            theme = candidate
        end
    end
    model:SetAttribute("TempleAppearance", theme.Id)
    -- The Halloween decorations folder is removed for good once any other theme is applied.
    local decor = model:FindFirstChild("HalloweenDecor")
    if decor and theme.Id ~= "Halloween" then
        decor:Destroy()
    end
    if theme.Id == "Halloween" then
        for _, part in model:GetDescendants() do
            if part:IsA("BasePart") then
                local color = part:GetAttribute("HalloweenColor")
                if color then
                    part.Color = color
                end
                local surfaceAppearance = part:FindFirstChildOfClass("SurfaceAppearance")
                local tint = part:GetAttribute("HalloweenSurfaceColor")
                if surfaceAppearance and tint then
                    surfaceAppearance.Color = tint
                end
            end
        end
        return
    end

    if theme.Id == "Original" then
        return
    end
    -- Neon and Glass parts (lights, windows) keep their look in every tinted theme.
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part.Material ~= Enum.Material.Neon and part.Material ~= Enum.Material.Glass then
            local surfaceAppearance = part:FindFirstChildWhichIsA("SurfaceAppearance")
            if theme.Id == "Gold" then
                local gold = Color3.fromRGB(238, 174, 49)
                part.Material = Enum.Material.Metal
                part.Reflectance = 0.12
                part.Color = gold
                if surfaceAppearance then
                    -- Preserve the temple's UV-matched cavity normal, replacing only its finish.
                    local key = surfaceAppearance:GetAttribute("GoldSurfaceKey") or "Flat"
                    local preset = game.ReplicatedStorage.GoldTempleSurfaces:FindFirstChild(key)
                    if preset then
                        local replacement = preset:Clone()
                        replacement.Name = surfaceAppearance.Name
                        surfaceAppearance:Destroy()
                        replacement.Parent = part
                    end
                end
            elseif surfaceAppearance then
                surfaceAppearance.Color = theme.Tint
            else
                local baseColor = part.Color
                local tint = theme.Tint
                part.Color = Color3.new(baseColor.R * tint.R, baseColor.G * tint.G, baseColor.B * tint.B)
            end
        end
    end
end
return Themes
