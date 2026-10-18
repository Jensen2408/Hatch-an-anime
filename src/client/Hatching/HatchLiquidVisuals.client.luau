local RunService = game:GetService("RunService")
local function setup(h)
    if not h:IsDescendantOf(workspace) or h:GetAttribute("ClientEffectsReady") then
        return
    end
    h:SetAttribute("ClientEffectsReady", true)
    local frame = h:GetPivot()
    if not h:GetAttribute("NewIncubatorDesign") then
        frame = frame * CFrame.new(-22.75, -26, -92)
    end
    local m = h:WaitForChild("LiquidSystemAndTrim", 3)
    if not m or not h:IsDescendantOf(workspace) then
        h:SetAttribute("ClientEffectsReady", nil)
        return
    end
    local nozzle = m:WaitForChild("InjectorNozzle", 3)
    if not nozzle or not h:IsDescendantOf(workspace) then
        h:SetAttribute("ClientEffectsReady", nil)
        return
    end
    local holder = Instance.new("Part")
    holder.Name = "LocalChamberGas"
    holder.Size = Vector3.new(0.1, 0.1, 0.1)
    holder.Transparency = 1
    holder.Anchored = true
    holder.CanCollide = false
    holder.CanTouch = false
    holder.CanQuery = false
    holder.CFrame = h:GetAttribute("NewIncubatorDesign") and frame * CFrame.new(0, 3.5, -1.5)
        or frame * CFrame.new(22.75, 34.125, 92)
    holder.Parent = m
    local function smoke(parent, name, size, lifetime)
        local e = Instance.new("ParticleEmitter")
        e.Name = name
        e.Texture = "rbxasset://textures/particles/smoke_main.dds"
        e.Color = ColorSequence.new(Color3.fromRGB(207, 242, 157), Color3.fromRGB(143, 195, 119))
        e.LightEmission = 0.12
        e.LightInfluence = 0.6
        e.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, size * 0.6),
            NumberSequenceKeypoint.new(0.5, size),
            NumberSequenceKeypoint.new(1, size * 0.9),
        })
        e.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.58),
            NumberSequenceKeypoint.new(0.7, 0.72),
            NumberSequenceKeypoint.new(1, 1),
        })
        e.Lifetime = NumberRange.new(lifetime * 0.8, lifetime)
        e.Speed = NumberRange.new(0)
        e.Rotation = NumberRange.new(0, 360)
        e.RotSpeed = NumberRange.new(-18, 18)
        e.Rate = 0
        e.Parent = parent
        return e
    end
    local puff = smoke(holder, "TeleportPuff", 2.4, 0.55)
    puff.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.3, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    local TweenService = game:GetService("TweenService")
    puff.Color = ColorSequence.new(Color3.new(1, 1, 1))
    puff.LightEmission = 1
    puff.LightInfluence = 0
    local flash = Instance.new("Part")
    flash.Name = "TeleportWhiteFlash"
    flash.Shape = Enum.PartType.Ball
    flash.Size = Vector3.one * 0.25
    flash.CFrame = h:GetAttribute("NewIncubatorDesign") and frame * CFrame.new(0, 4.3, -1.5)
        or frame * CFrame.new(22.75, 35, 92)
    flash.Color = Color3.new(1, 1, 1)
    flash.Material = Enum.Material.Neon
    flash.Transparency = 1
    flash.Anchored = true
    flash.CanCollide = false
    flash.CanTouch = false
    flash.CanQuery = false
    flash.CastShadow = false
    flash.Parent = m
    local fade
    local pulseConnection = h:GetAttributeChangedSignal("TeleportPulse"):Connect(function()
        puff:Emit(9)
        if h:GetAttribute("Status") ~= "Loading" then
            return
        end
        if fade then
            fade:Cancel()
        end
        flash.Size = Vector3.one * 0.25
        flash.Transparency = 0.4
        fade = TweenService:Create(
            flash,
            TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Transparency = 1, Size = Vector3.one * 3.2 }
        )
        fade:Play()
    end)

    local intakeAttachment = Instance.new("Attachment")
    intakeAttachment.Position = Vector3.new(0, -0.35, 0)
    intakeAttachment.Parent = nozzle
    local intake = smoke(intakeAttachment, "GasInlet", 0.7, 0.65)
    intake.EmissionDirection = Enum.NormalId.Bottom
    intake.Speed = NumberRange.new(1.5, 2)
    intake.SpreadAngle = Vector2.new(12, 12)
    local layers = {}
    for layer = 1, 4 do
        for _, x in { -0.65, 0.65 } do
            for _, z in { -0.5, 0.5 } do
                local a = Instance.new("Attachment")
                a.Position = Vector3.new(x, 33.5 + (layer - 1) * 0.9 - 34.125, z)
                a.Parent = holder
                table.insert(layers, { emitter = smoke(a, "ChamberMist" .. layer, 1.1, 1.2), layer = layer })
            end
        end
    end
    local Debris = game:GetService("Debris")
    local SFX_DOOR = "rbxassetid://9118297953" -- Robot Pneumatics Sweeping Piston Slides 6 (ProSoundEffects)
    local SFX_FLUSH = "rbxassetid://9125498766" -- Drain Bubbling Liquid Gurgle Emptying Drain 1 (ProSoundEffects)
    local SFX_BUBBLES = "rbxassetid://9112752570" -- Bubbles Dribble Small Bloops 1 (ProSoundEffects)
    local SFX_READY = "rbxassetid://9116394545" -- Magic Glows Soft Clusters Of Chiming Hits 1 (ProSoundEffects)
    local SFX_STEAM = "rbxassetid://9119625292" -- Steam Piston Pump 34 (ProSoundEffects)

    local bubbleLoop = Instance.new("Sound")
    bubbleLoop.Name = "IncubatorBubbles"
    bubbleLoop.SoundId = SFX_BUBBLES
    bubbleLoop.Volume = 0.16
    bubbleLoop.Looped = true
    bubbleLoop.RollOffMinDistance = 4
    bubbleLoop.RollOffMaxDistance = 35
    bubbleLoop.Parent = holder

    local function cue(name, id, volume, pitch)
        local s = Instance.new("Sound")
        s.Name = name
        s.SoundId = id
        s.Volume = volume
        s.PlaybackSpeed = pitch or 1
        s.RollOffMinDistance = 5
        s.RollOffMaxDistance = 45
        s.Parent = holder
        s:Play()
        Debris:AddItem(s, 4)
    end
    local statusConnection = h:GetAttributeChangedSignal("Status"):Connect(function()
        local state = h:GetAttribute("Status")
        if state == "Loading" then
            cue("DoorSlide", SFX_DOOR, 0.28, 1.25)
        elseif state == "Incubating" then
            cue("GasFill", SFX_FLUSH, 0.22, 1.0)
            if not bubbleLoop.Playing then
                bubbleLoop:Play()
            end
        elseif state == "Loaded" then
            if bubbleLoop.Playing then
                bubbleLoop:Stop()
            end
            cue("ReadyPing", SFX_READY, 0.32, 1.08)
        else
            if bubbleLoop.Playing and state ~= "Incubating" then
                bubbleLoop:Stop()
            end
        end
    end)
    local ventingConnection = h:GetAttributeChangedSignal("Venting"):Connect(function()
        if h:GetAttribute("Venting") == true then
            cue("SteamVent", SFX_STEAM, 0.24, 1.0)
        end
    end)
    h.Destroying:Connect(function()
        for _, c in { heartbeatConnection, pulseConnection, statusConnection, ventingConnection } do
            if c then
                c:Disconnect()
            end
        end
        if bubbleLoop.Parent then
            bubbleLoop:Destroy()
        end
    end)
end
local collection = game:GetService("CollectionService")
collection:GetInstanceAddedSignal("PlotHatchChamber"):Connect(function(h)
    task.spawn(setup, h)
end)
for _, h in collection:GetTagged("PlotHatchChamber") do
    task.spawn(setup, h)
end
