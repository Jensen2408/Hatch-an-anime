-- HatchLiquidVisuals (LocalScript, StarterPlayerScripts)
-- Client-only dressing for every "PlotHatchChamber"-tagged incubator: chamber gas mist, the nozzle
-- inlet, a teleport puff + white flash, and positional sound cues. Driven entirely by attributes
-- the server sets on the chamber model:
--   Status         "Loading" | "Incubating" | "Loaded" | other  -> door / gas / ready sounds, bubble loop
--   TeleportPulse  any change                                    -> puff (+ white flash while Loading)
--   Venting        true                                          -> steam sound
--   NewIncubatorDesign (bool) selects the offsets for the new vs legacy model layout.
-- ClientEffectsReady (set locally) guards against building the effects twice for one chamber.
local _RunService = game:GetService("RunService")
local function setupChamber(chamber)
    if not chamber:IsDescendantOf(workspace) or chamber:GetAttribute("ClientEffectsReady") then
        return
    end
    chamber:SetAttribute("ClientEffectsReady", true)
    local chamberFrame = chamber:GetPivot()
    if not chamber:GetAttribute("NewIncubatorDesign") then
        -- legacy model: pivot sits off-centre, shift to the reference point the offsets below expect
        chamberFrame = chamberFrame * CFrame.new(-22.75, -26, -92)
    end
    -- WaitForChild yields; re-check the chamber still exists and allow a retry if anything is missing
    local liquidSystem = chamber:WaitForChild("LiquidSystemAndTrim", 3)
    if not liquidSystem or not chamber:IsDescendantOf(workspace) then
        chamber:SetAttribute("ClientEffectsReady", nil)
        return
    end
    local nozzle = liquidSystem:WaitForChild("InjectorNozzle", 3)
    if not nozzle or not chamber:IsDescendantOf(workspace) then
        chamber:SetAttribute("ClientEffectsReady", nil)
        return
    end
    -- invisible anchor inside the chamber for the mist emitters and sounds
    local holder = Instance.new("Part")
    holder.Name = "LocalChamberGas"
    holder.Size = Vector3.new(0.1, 0.1, 0.1)
    holder.Transparency = 1
    holder.Anchored = true
    holder.CanCollide = false
    holder.CanTouch = false
    holder.CanQuery = false
    holder.CFrame = chamber:GetAttribute("NewIncubatorDesign") and chamberFrame * CFrame.new(0, 3.5, -1.5)
        or chamberFrame * CFrame.new(22.75, 34.125, 92)
    holder.Parent = liquidSystem
    -- pale green smoke emitter (Rate 0: callers Emit or change it)
    local function makeSmoke(parent, name, size, lifetime)
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = name
        emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
        emitter.Color = ColorSequence.new(Color3.fromRGB(207, 242, 157), Color3.fromRGB(143, 195, 119))
        emitter.LightEmission = 0.12
        emitter.LightInfluence = 0.6
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, size * 0.6),
            NumberSequenceKeypoint.new(0.5, size),
            NumberSequenceKeypoint.new(1, size * 0.9),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.58),
            NumberSequenceKeypoint.new(0.7, 0.72),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Lifetime = NumberRange.new(lifetime * 0.8, lifetime)
        emitter.Speed = NumberRange.new(0)
        emitter.Rotation = NumberRange.new(0, 360)
        emitter.RotSpeed = NumberRange.new(-18, 18)
        emitter.Rate = 0
        emitter.Parent = parent
        return emitter
    end
    -- teleport puff: white, bright variant of the smoke
    local puff = makeSmoke(holder, "TeleportPuff", 2.4, 0.55)
    puff.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(0.3, 0.5),
        NumberSequenceKeypoint.new(1, 1),
    })
    local TweenService = game:GetService("TweenService")
    puff.Color = ColorSequence.new(Color3.new(1, 1, 1))
    puff.LightEmission = 1
    puff.LightInfluence = 0
    local whiteFlash = Instance.new("Part")
    whiteFlash.Name = "TeleportWhiteFlash"
    whiteFlash.Shape = Enum.PartType.Ball
    whiteFlash.Size = Vector3.one * 0.25
    whiteFlash.CFrame = chamber:GetAttribute("NewIncubatorDesign") and chamberFrame * CFrame.new(0, 4.3, -1.5)
        or chamberFrame * CFrame.new(22.75, 35, 92)
    whiteFlash.Color = Color3.new(1, 1, 1)
    whiteFlash.Material = Enum.Material.Neon
    whiteFlash.Transparency = 1
    whiteFlash.Anchored = true
    whiteFlash.CanCollide = false
    whiteFlash.CanTouch = false
    whiteFlash.CanQuery = false
    whiteFlash.CastShadow = false
    whiteFlash.Parent = liquidSystem
    local flashTween
    local pulseConnection = chamber:GetAttributeChangedSignal("TeleportPulse"):Connect(function()
        puff:Emit(9)
        if chamber:GetAttribute("Status") ~= "Loading" then
            return
        end
        if flashTween then
            flashTween:Cancel()
        end
        whiteFlash.Size = Vector3.one * 0.25
        whiteFlash.Transparency = 0.4
        flashTween = TweenService:Create(
            whiteFlash,
            TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            { Transparency = 1, Size = Vector3.one * 3.2 }
        )
        flashTween:Play()
    end)

    -- gas inlet under the injector nozzle
    local intakeAttachment = Instance.new("Attachment")
    intakeAttachment.Position = Vector3.new(0, -0.35, 0)
    intakeAttachment.Parent = nozzle
    local intake = makeSmoke(intakeAttachment, "GasInlet", 0.7, 0.65)
    intake.EmissionDirection = Enum.NormalId.Bottom
    intake.Speed = NumberRange.new(1.5, 2)
    intake.SpreadAngle = Vector2.new(12, 12)
    -- 4 mist layers x 4 corners inside the chamber (only referenced here, never read back)
    local _chamberMistLayers = {}
    for layer = 1, 4 do
        for _, offsetX in { -0.65, 0.65 } do
            for _, offsetZ in { -0.5, 0.5 } do
                local mistAttachment = Instance.new("Attachment")
                mistAttachment.Position = Vector3.new(offsetX, 33.5 + (layer - 1) * 0.9 - 34.125, offsetZ)
                mistAttachment.Parent = holder
                table.insert(
                    _chamberMistLayers,
                    { emitter = makeSmoke(mistAttachment, "ChamberMist" .. layer, 1.1, 1.2), layer = layer }
                )
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

    -- one-shot positional sound on the holder, removed after 4 s
    local function playCue(name, soundId, volume, pitch)
        local cueSound = Instance.new("Sound")
        cueSound.Name = name
        cueSound.SoundId = soundId
        cueSound.Volume = volume
        cueSound.PlaybackSpeed = pitch or 1
        cueSound.RollOffMinDistance = 5
        cueSound.RollOffMaxDistance = 45
        cueSound.Parent = holder
        cueSound:Play()
        Debris:AddItem(cueSound, 4)
    end
    local statusConnection = chamber:GetAttributeChangedSignal("Status"):Connect(function()
        local state = chamber:GetAttribute("Status")
        if state == "Loading" then
            playCue("DoorSlide", SFX_DOOR, 0.28, 1.25)
        elseif state == "Incubating" then
            playCue("GasFill", SFX_FLUSH, 0.22, 1.0)
            if not bubbleLoop.Playing then
                bubbleLoop:Play()
            end
        elseif state == "Loaded" then
            if bubbleLoop.Playing then
                bubbleLoop:Stop()
            end
            playCue("ReadyPing", SFX_READY, 0.32, 1.08)
        else
            if bubbleLoop.Playing and state ~= "Incubating" then
                bubbleLoop:Stop()
            end
        end
    end)
    local ventingConnection = chamber:GetAttributeChangedSignal("Venting"):Connect(function()
        if chamber:GetAttribute("Venting") == true then
            playCue("SteamVent", SFX_STEAM, 0.24, 1.0)
        end
    end)
    chamber.Destroying:Connect(function()
        -- Known issue: `heartbeatConnection` is never declared, so this reads a nil global (left over
        -- from a removed Heartbeat loop). The nil entry is skipped by the loop; the other three disconnect.
        for _, connection in { heartbeatConnection, pulseConnection, statusConnection, ventingConnection } do
            if connection then
                connection:Disconnect()
            end
        end
        if bubbleLoop.Parent then
            bubbleLoop:Destroy()
        end
    end)
end
local CollectionService = game:GetService("CollectionService")
-- setupChamber yields (WaitForChild), so each chamber gets its own thread
CollectionService:GetInstanceAddedSignal("PlotHatchChamber"):Connect(function(chamber)
    task.spawn(setupChamber, chamber)
end)
for _, chamber in CollectionService:GetTagged("PlotHatchChamber") do
    task.spawn(setupChamber, chamber)
end
