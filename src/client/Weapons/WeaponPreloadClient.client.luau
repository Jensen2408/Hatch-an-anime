--[[
	StarterPlayerScripts.WeaponPreloadClient (client only, no remotes)
	Preloads each weapon Tool (mesh, SurfaceAppearance, sounds, trail) in the
	background the moment it lands in the Backpack, so it is already textured
	when the player equips it instead of showing up gray.
]]

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")

local localPlayer = Players.LocalPlayer
local preloadedTools = setmetatable({}, { __mode = "k" })

local SURFACE_MAPS = { "ColorMap", "NormalMap", "RoughnessMap", "MetalnessMap" }

-- PreloadAsync skips SurfaceAppearance maps and game scripts cannot read them,
-- so the ids are stamped on each SurfaceAppearance as Preload<Map> attributes
-- (re-stamp in Studio if a weapon's textures change) and fetched via Decals.
local function makeSurfaceProxies(tool)
    local proxies = {}
    for _, descendant in ipairs(tool:GetDescendants()) do
        if descendant:IsA("SurfaceAppearance") then
            for _, map in ipairs(SURFACE_MAPS) do
                local assetId = descendant:GetAttribute("Preload" .. map)
                if type(assetId) == "string" and assetId ~= "" then
                    local decal = Instance.new("Decal")
                    decal.Texture = assetId
                    table.insert(proxies, decal)
                end
            end
        end
    end
    return proxies
end

local function preloadTool(tool)
    if not tool:IsA("Tool") or preloadedTools[tool] then
        return
    end
    preloadedTools[tool] = true
    task.spawn(function()
        local proxies = makeSurfaceProxies(tool)
        local preloadList = table.clone(proxies)
        table.insert(preloadList, tool)
        pcall(function()
            ContentProvider:PreloadAsync(preloadList)
        end)
        for _, decal in ipairs(proxies) do
            decal:Destroy()
        end
    end)
end

local function watchContainer(container)
    for _, child in ipairs(container:GetChildren()) do
        preloadTool(child)
    end
    container.ChildAdded:Connect(preloadTool)
end

local function onBackpack(backpack)
    if backpack:IsA("Backpack") then
        watchContainer(backpack)
    end
end

localPlayer.ChildAdded:Connect(onBackpack)
local backpack = localPlayer:FindFirstChildOfClass("Backpack")
if backpack then
    onBackpack(backpack)
end

localPlayer.CharacterAdded:Connect(watchContainer)
if localPlayer.Character then
    watchContainer(localPlayer.Character)
end
