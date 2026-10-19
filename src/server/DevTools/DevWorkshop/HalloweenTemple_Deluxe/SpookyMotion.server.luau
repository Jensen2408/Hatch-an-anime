-- ServerStorage.DevWorkshop.HalloweenTemple_Deluxe.SpookyMotion (server Script, dev model)
-- Inert in ServerStorage; runs only if the temple model is placed in Workspace. An older copy is archived under
-- archive/_ARCHIVE/HalloweenTemple_BeforeVoxelPass_1791847385.
local RunService = game:GetService("RunService")
local templeModel = script.Parent
local flickerLights = {} -- { l = PointLight, b = base Brightness, s = noise seed }
-- candle-style flicker: old pumpkin "Rib" lights plus any light inside a voxel *_Glow part (jack-o'-lanterns, candles)
local function trackLight(light)
    if
        light:IsA("PointLight")
        and (light.Parent.Name == "Rib" or light.Parent.Name:find("_Glow") or light:GetAttribute("Flicker"))
    then
        table.insert(flickerLights, { l = light, b = light.Brightness, s = math.random() * 100 })
    end
end
for _, descendant in templeModel:GetDescendants() do
    trackLight(descendant)
end
templeModel.DescendantAdded:Connect(trackLight)
RunService.Heartbeat:Connect(function()
    local now = os.clock()
    for _, entry in flickerLights do
        if entry.l.Parent then
            entry.l.Brightness = entry.b * (0.75 + 0.25 * math.noise(now * 6, entry.s))
        end
    end
end)
