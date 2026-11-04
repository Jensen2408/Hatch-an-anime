-- ServerScriptService.RiverWater (server Script)
-- Server half of the river water system (client renderer: StarterPlayerScripts.RiverWater).
--   1. Clears the terrain water of the river channel and the cliff-top channel above the falls at startup (runtime
--      only, the place file keeps it), so the animated mesh water is the only surface. Set the script attribute ClearTerrainWater = false to keep the terrain water.
--      Skipped when the experience can't create EditableMeshes (Game Settings > Security), since the clients then
--      have no mesh water to show.
--   2. Runs the high tide clock (HighTideService) ~10x per second and announces scheduled tides.
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local riverAssets = ReplicatedStorage:WaitForChild("WaterfallRiver")
local Config = require(riverAssets:WaitForChild("RiverConfig"))
local Path = require(riverAssets:WaitForChild("RiverPath"))
local HighTideService = require(script.Parent:WaitForChild("HighTideService"))

local meshApiOk, probe = pcall(AssetService.CreateEditableMesh, AssetService)
if meshApiOk and probe then
    probe:Destroy()
else
    warn("[RiverWater] EditableMesh is unavailable, keeping the river's terrain water:", probe)
end
workspace:SetAttribute("RiverMeshWater", meshApiOk and probe ~= nil)

if meshApiOk and probe and script:GetAttribute("ClearTerrainWater") ~= false then
    -- The river channel around the still water level, and the channel on top of the cliff that feeds the falls
    -- (WaterfallCurtain draws mesh water along it).
    local margin = Config.Meander + Config.RiverWidth + Config.PoolExtraWidth
    local topY = Config.Origin.Y + Config.FallHeight
    local regions = {
        Region3.new(
            Vector3.new(Config.Origin.X - 12, Path.SurfaceY - Config.WaterDepth - 4, Config.Origin.Z - margin),
            Vector3.new(Config.Origin.X + Config.Length + 12, Path.SurfaceY + 4, Config.Origin.Z + margin)
        ),
        Region3.new(
            Vector3.new(Config.Origin.X - Config.CliffDepth - 12, topY - 8, Config.Origin.Z - Config.FallWidth),
            Vector3.new(Config.Origin.X + 4, topY + 6, Config.Origin.Z + Config.FallWidth)
        ),
    }
    for _, region in regions do
        local ok, err = pcall(function()
            workspace.Terrain:ReplaceMaterial(region:ExpandToGrid(4), 4, Enum.Material.Water, Enum.Material.Air)
        end)
        if not ok then
            warn("[RiverWater] could not clear terrain water:", err)
        end
    end
end

local announceEvent
task.spawn(function()
    local panel = ReplicatedStorage:WaitForChild("OwnerPanel", 60)
    announceEvent = panel and panel:WaitForChild("Announcement", 60)
end)

while true do
    local _, startedNow = HighTideService.Update(workspace:GetServerTimeNow())
    if startedNow and announceEvent then
        announceEvent:FireAllClients({
            title = "HIGH TIDE!",
            text = "The waterfall burst — huge waves and a flood of eggs are racing down the river!",
            color = "tide",
            by = "Server",
        })
    end
    task.wait(0.1)
end
