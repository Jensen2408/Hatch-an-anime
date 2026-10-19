-- StarterPlayerScripts.WaterfallRiverMotion (client only)
-- Soft wake ring around river eggs, following the new winding WaterfallRiver.
-- Follows the local visual eggs (workspace.LocalRiverEggs, made by PirateEggConveyorMotion); falls back to the
-- server eggs in workspace.WaterfallEggs if that folder doesn't appear within 15 s. Each egg gets 22 thin parts
-- in an EggWake folder, shown only while the egg sits on the water surface between START_X and END_X.
local RunService = game:GetService("RunService")
local RiverPath = require(game.ReplicatedStorage:WaitForChild("WaterfallRiver"):WaitForChild("RiverPath"))
local riverRoot = workspace:WaitForChild("WaterfallRiver")
local eggFolder = workspace:WaitForChild("LocalRiverEggs", 15) or workspace:WaitForChild("WaterfallEggs")
local wakeRecords = {}
local SURFACE_Y = RiverPath.SurfaceY
local function addWake(egg)
    if not egg:IsA("Model") then
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = "EggWake"
    folder.Parent = riverRoot
    local segments = {}
    for i = 1, 22 do
        local segment = Instance.new("Part")
        segment.Name = "WaterWake"
        segment.Size = Vector3.new(0.6, 0.009, 0.075)
        segment.Anchored = true
        segment.CanCollide = false
        segment.CanTouch = false
        segment.CanQuery = false
        segment.CastShadow = false
        segment.Material = Enum.Material.SmoothPlastic
        segment.Color = Color3.fromRGB(189, 238, 242)
        segment.Transparency = 1
        segment.Parent = folder
        segments[i] = segment
    end
    local box, size = egg:GetBoundingBox()
    wakeRecords[egg] = {
        folder = folder,
        segments = segments,
        size = size,
        offset = egg:GetPivot():ToObjectSpace(box),
        visible = false,
    }
end
eggFolder.ChildAdded:Connect(addWake)
eggFolder.ChildRemoved:Connect(function(egg)
    local wake = wakeRecords[egg]
    if wake then
        wake.folder:Destroy()
        wakeRecords[egg] = nil
    end
end)
for _, egg in eggFolder:GetChildren() do
    addWake(egg)
end
local START_X = RiverPath.At(RiverPath.LandDistance + 2).X
local END_X = RiverPath.At(RiverPath.Total - 4).X
local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
    elapsed += dt
    if elapsed < 1 / 30 then
        return
    end
    elapsed = 0
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    for egg, wake in wakeRecords do
        if egg.Parent then
            local boxCFrame, size = egg:GetPivot() * wake.offset, wake.size
            local pos = boxCFrame.Position
            local bottom = pos.Y - size.Y / 2
            local visible = math.abs(bottom - SURFACE_Y) < 1.6
                and pos.X > START_X
                and pos.X < END_X
                and (camera.CFrame.Position - pos).Magnitude < 180
            if not visible then
                if wake.visible then
                    for _, segment in ipairs(wake.segments) do
                        segment.Transparency = 1
                    end
                end
                wake.visible = false
                continue
            end
            wake.visible = true
            for i, segment in wake.segments do
                local angle = 0.35 + (i - 1) / 21 * (math.pi * 2 - 0.7)
                local radius = 2.65
                segment.CFrame = CFrame.new(
                    pos.X + math.cos(angle) * radius - 0.15,
                    SURFACE_Y + 0.06,
                    pos.Z + math.sin(angle) * radius * 0.78
                ) * CFrame.Angles(0, -angle + math.pi / 2, 0)
                segment.Transparency = visible and (0.45 + 0.25 * math.abs(i - 11.5) / 11.5) or 1
            end
        end
    end
end)
