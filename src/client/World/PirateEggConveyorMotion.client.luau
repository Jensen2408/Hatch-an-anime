--[[ StarterPlayerScripts.PirateEggConveyorMotion (client)
River eggs are spawned by the server (PirateEggFreeConveyor) into workspace.WaterfallEggs. For smooth motion this
script hides each server egg locally (LocalTransparencyModifier / Enabled = false) and drives a local clone in
workspace.LocalRiverEggs every render frame with workspace.PirateEggConveyor.RollingMotion.
The clone carries the RiverEgg tag + RiverEggVisual attribute and mirrors the server egg's Collected attribute.
Network: the clone's ProximityPrompt fires ReplicatedStorage.CollectRiverEgg:FireServer(serverEgg); the server
validates the collect. Second half: a local gold glow on the water under Golden eggs (nothing replicates).
]]
local RunService = game:GetService("RunService")
local conveyor = workspace:WaitForChild("PirateEggConveyor")
local serverEggFolder = workspace:WaitForChild("WaterfallEggs")
local RollingMotion = require(conveyor:WaitForChild("RollingMotion"))
local collectRemote = game.ReplicatedStorage:WaitForChild("CollectRiverEgg")
local visualFolder = Instance.new("Folder")
visualFolder.Name = "LocalRiverEggs"
visualFolder.Parent = workspace
local activeRecords = {} -- [serverEgg] = { visual, connection, collectedConnection, update } (filled after anchors stream in)
local function hideServerCopy(instance)
    if instance:IsA("BasePart") then
        instance.LocalTransparencyModifier = 1
    elseif instance:IsA("BillboardGui") or instance:IsA("ProximityPrompt") then
        instance.Enabled = false
    end
end
local function onServerEggAdded(source)
    if not source:IsA("Model") or activeRecords[source] then
        return
    end
    local record = {}
    activeRecords[source] = record
    task.spawn(function()
        if
            not source:WaitForChild("LabelAnchor", 10)
            or not source:WaitForChild("CollectAnchor", 10)
            or not source.Parent
        then
            activeRecords[source] = nil
            return
        end
        -- Untag the clone while it is set up so RiverEgg listeners only see it once it is complete.
        local egg = source:Clone()
        game:GetService("CollectionService"):RemoveTag(egg, "RiverEgg")
        egg:SetAttribute("RiverEggVisual", true)
        egg:SetAttribute("Collectible", false)
        for _, descendant in egg:GetDescendants() do
            if descendant:IsA("BasePart") then
                descendant.LocalTransparencyModifier = 0
                descendant.CanCollide = false
            end
        end
        record.visual = egg
        for _, descendant in source:GetDescendants() do
            hideServerCopy(descendant)
        end
        record.connection = source.DescendantAdded:Connect(hideServerCopy)
        record.collectedConnection = source:GetAttributeChangedSignal("Collected"):Connect(function()
            egg:SetAttribute("Collected", source:GetAttribute("Collected"))
        end)
        record.update = RollingMotion(conveyor, egg)
        record.update()
        local prompt = egg.CollectAnchor:FindFirstChildOfClass("ProximityPrompt")
        if prompt then
            prompt.Triggered:Connect(function()
                collectRemote:FireServer(source)
            end)
        end
        egg.Parent = visualFolder
        game:GetService("CollectionService"):AddTag(egg, "RiverEgg")
    end)
end
serverEggFolder.ChildAdded:Connect(onServerEggAdded)
serverEggFolder.ChildRemoved:Connect(function(source)
    local record = activeRecords[source]
    if record then
        if record.connection then
            record.connection:Disconnect()
        end
        if record.collectedConnection then
            record.collectedConnection:Disconnect()
        end
        if record.visual then
            record.visual:Destroy()
        end
        activeRecords[source] = nil
    end
end)
for _, egg in serverEggFolder:GetChildren() do
    onServerEggAdded(egg)
end
RunService:BindToRenderStep("RiverEggVisualMotion", Enum.RenderPriority.Camera.Value + 1, function()
    for _, record in activeRecords do
        if record.update and record.visual.Parent then
            record.update()
        end
    end
end)
-- Local water reflection follows gold eggs without adding replicated moving parts.
local goldenEffects = {}
local function clearGoldEffect(egg)
    local effect = goldenEffects[egg]
    if effect then
        effect.host:Destroy()
        goldenEffects[egg] = nil
    end
end
local function addGoldEffect(egg)
    if not egg:IsA("Model") or not egg:GetAttribute("Golden") or goldenEffects[egg] then
        return
    end
    local host = Instance.new("Part")
    host.Name = "GoldenWaterGlow"
    host.Size = Vector3.one
    host.Transparency = 1
    host.Anchored = true
    host.CanCollide = false
    host.CanTouch = false
    host.CanQuery = false
    host.Parent = workspace
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 191, 65)
    light.Brightness = 0.8
    light.Range = 11
    light.Shadows = false
    light.Enabled = false
    light.Parent = host
    local glow = Instance.new("ParticleEmitter")
    glow.Name = "WaterShimmer"
    glow.Texture = "rbxasset://textures/particles/smoke_main.dds"
    glow.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
    glow.Rate = 0
    glow.Speed = NumberRange.new(0.015, 0.03)
    glow.EmissionDirection = Enum.NormalId.Top
    glow.Lifetime = NumberRange.new(0.65, 0.9)
    glow.LightEmission = 0.85
    glow.Color = ColorSequence.new(Color3.fromRGB(255, 191, 54))
    glow.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3.5), NumberSequenceKeypoint.new(1, 6) })
    glow.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.2, 0.72),
        NumberSequenceKeypoint.new(1, 1),
    })
    glow.Parent = host
    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "GoldFlecks"
    sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparks.Rate = 0
    sparks.Speed = NumberRange.new(0.3, 0.8)
    sparks.SpreadAngle = Vector2.new(60, 60)
    sparks.Lifetime = NumberRange.new(0.4, 0.8)
    sparks.LightEmission = 0.8
    sparks.Color = ColorSequence.new(Color3.fromRGB(255, 225, 139))
    sparks.Size = NumberSequence.new(0.12)
    sparks.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.2, 0.3),
        NumberSequenceKeypoint.new(1, 1),
    })
    sparks.Parent = host
    goldenEffects[egg] = { host = host, light = light, glow = glow, sparks = sparks }
end
visualFolder.ChildAdded:Connect(addGoldEffect)
visualFolder.ChildRemoved:Connect(clearGoldEffect)
for _, egg in visualFolder:GetChildren() do
    addGoldEffect(egg)
end
RunService.RenderStepped:Connect(function()
    for egg, effect in goldenEffects do
        if not egg.Parent then
            clearGoldEffect(egg)
        else
            local eggPosition = egg:GetPivot().Position
            local epoch = egg:GetAttribute("Epoch") or workspace:GetServerTimeNow()
            local age = workspace:GetServerTimeNow() - epoch
            local visible = age >= (conveyor:GetAttribute("DropDuration") or 1.8)
                and eggPosition.X <= (conveyor:GetAttribute("ExitX") or 235)
                and (workspace.CurrentCamera.CFrame.Position - eggPosition).Magnitude < 160
            effect.host.Position = Vector3.new(eggPosition.X, 24.5, eggPosition.Z)
            effect.light.Enabled = visible
            effect.glow.Rate = visible and 9 or 0
            effect.sparks.Rate = visible and 5 or 0
        end
    end
end)
