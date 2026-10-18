--[[
	WeaponPreloadClient
	Preloads each weapon Tool (mesh, SurfaceAppearance, sounds, trail) in the
	background the moment it lands in the Backpack, so it is already textured
	when the player equips it instead of showing up gray.
]]

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local preloaded = setmetatable({}, { __mode = "k" })

local MAPS = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }

-- PreloadAsync skips SurfaceAppearance maps and game scripts cannot read them,
-- so the ids are stamped on each SurfaceAppearance as Preload<Map> attributes
-- (re-stamp in Studio if a weapon's textures change) and fetched via Decals.
local function surfaceProxies(tool)
    local proxies = {}
    for _, d in ipairs(tool:GetDescendants()) do
        if d:IsA("SurfaceAppearance") then
            for _, map in ipairs(MAPS) do
                local id = d:GetAttribute("Preload" .. map)
                if type(id) == "string" and id ~= "" then
                    local decal = Instance.new("Decal")
                    decal.Texture = id
                    table.insert(proxies, decal)
                end
            end
        end
    end
    return proxies
end

local function preload(tool)
    if not tool:IsA("Tool") or preloaded[tool] then
        return
    end
    preloaded[tool] = true
    task.spawn(function()
        local proxies = surfaceProxies(tool)
        local list = table.clone(proxies)
        table.insert(list, tool)
        pcall(function()
            ContentProvider:PreloadAsync(list)
        end)
        for _, decal in ipairs(proxies) do
            decal:Destroy()
        end
    end)
end

local function watch(container)
    for _, child in ipairs(container:GetChildren()) do
        preload(child)
    end
    container.ChildAdded:Connect(preload)
end

local function onBackpack(backpack)
    if backpack:IsA("Backpack") then
        watch(backpack)
    end
end

player.ChildAdded:Connect(onBackpack)
local backpack = player:FindFirstChildOfClass("Backpack")
if backpack then
    onBackpack(backpack)
end

player.CharacterAdded:Connect(watch)
if player.Character then
    watch(player.Character)
end
