--[[ StarterPlayerScripts.UpgradeCameraShake  (LocalScript, DISABLED in default.project.json)
Legacy ground-assembly effect for models tagged "UpgradeAssembly" by ServerScriptService.UpgradeEffects:
a ring of dust/debris emitters around the footprint, thump sounds, earth chips on the final pulse and, for
the purchaser (BuildOwner), a trauma-based camera shake. Timing is anchored to the model's BuildStart
(server time); effects are skipped when the build is older than 3.4 s or the camera is > 200 studs away.
Superseded by ConstructionClient (which has its own shake); kept for reference.
]]
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local localPlayer = game.Players.LocalPlayer
local activeModels = {}
local trauma = 0 -- 0..0.65; shake strength is trauma^2, decays 0.9 per second
local lastOffset = CFrame.identity
-- Undo only our previous offset before Roblox updates its camera.
RunService:BindToRenderStep("ConstructionShakeReset", Enum.RenderPriority.Camera.Value - 1, function()
    local camera = workspace.CurrentCamera
    if camera then
        camera.CFrame = camera.CFrame * lastOffset:Inverse()
    end
    lastOffset = CFrame.identity
end)
RunService:BindToRenderStep("LegacyUpgradeCameraShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
    trauma = math.max(0, trauma - dt * 0.9)
    local camera = workspace.CurrentCamera
    if not camera or trauma <= 0 then
        return
    end
    local t = os.clock() * 19
    local amount = trauma * trauma
    lastOffset = CFrame.new(math.noise(t, 0) * 0.12 * amount, math.noise(0, t) * 0.09 * amount, 0)
        * CFrame.Angles(0, 0, math.noise(t, t) * math.rad(0.4) * amount)
    camera.CFrame = camera.CFrame * lastOffset
end)
local function playAssemblyEffects(model)
    if activeModels[model] or not model:IsDescendantOf(workspace) then
        return
    end
    local buildStart = model:GetAttribute("BuildStart")
    if not buildStart or workspace:GetServerTimeNow() > buildStart + 3.4 then
        return
    end
    local pivot = model:GetPivot()
    -- During construction the model pivot can be below ground; use its authored anchor.
    local ground = model:GetAttribute("BuildGround")
    local center = (model:GetAttribute("BuildCenter") or Vector3.new(pivot.X, ground, pivot.Z))
        + Vector3.new(0, 0.06, 0)
    local footprint = model:GetAttribute("BuildFootprint") or Vector3.new(16, 0, 16)
    local rng = Random.new(math.floor(buildStart * 1000) % 100000)
    local camera = workspace.CurrentCamera
    if not camera or (camera.CFrame.Position - center).Magnitude > 200 then
        return
    end
    activeModels[model] = true
    local isOwner = model:GetAttribute("BuildOwner") == localPlayer.UserId
    local _radius = math.clamp(model:GetAttribute("BuildRadius") or 8, 4, 34)
    local host = Instance.new("Part")
    host.Name = "ConstructionGroundFX"
    host.Anchored = true
    host.Transparency = 1
    host.CanCollide = false
    host.CanTouch = false
    host.CanQuery = false
    host.Size = Vector3.one
    host.Position = center
    host.Parent = workspace
    Debris:AddItem(host, 6.5)
    local emitters = {}
    for i = 1, 20 do
        local angle = i / 20 * math.pi * 2
        local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
        local edge = Vector3.new(outward.X * (footprint.X * 0.52 + 1), 0, outward.Z * (footprint.Z * 0.52 + 1))
        -- push the point out to the footprint's bounding square
        local factor = 1 / math.max(math.abs(outward.X), math.abs(outward.Z))
        edge *= factor
        local attachment = Instance.new("Attachment")
        attachment.CFrame = CFrame.lookAt(edge, edge + outward + Vector3.new(0, 0.12, 0))
        attachment.Parent = host
        local dust = Instance.new("ParticleEmitter")
        dust.Name = "GroundDust"
        dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
        dust.Rate = 0
        dust.EmissionDirection = Enum.NormalId.Front
        dust.Speed = NumberRange.new(4, 8)
        dust.Drag = 2
        dust.Acceleration = Vector3.new(0, 0.4, 0)
        dust.SpreadAngle = Vector2.new(22, 35)
        dust.Lifetime = NumberRange.new(0.6, 1.25)
        dust.Rotation = NumberRange.new(0, 360)
        dust.RotSpeed = NumberRange.new(-18, 18)
        dust.Color = ColorSequence.new(Color3.fromRGB(170, 154, 130), Color3.fromRGB(204, 191, 165))
        dust.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.6),
            NumberSequenceKeypoint.new(0.4, 2.5),
            NumberSequenceKeypoint.new(1, 2.8),
        })
        dust.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.7),
            NumberSequenceKeypoint.new(0.2, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        })
        dust.Parent = attachment
        local grit = Instance.new("ParticleEmitter")
        grit.Name = "TinyDebris"
        grit.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        grit.Rate = 0
        grit.LightEmission = 0
        grit.Color = ColorSequence.new(Color3.fromRGB(102, 92, 73))
        grit.Size = NumberSequence.new(0.09)
        grit.Speed = NumberRange.new(2, 4)
        grit.Acceleration = Vector3.new(0, -18, 0)
        grit.Lifetime = NumberRange.new(0.25, 0.5)
        grit.SpreadAngle = Vector2.new(55, 55)
        grit.Parent = attachment
        table.insert(emitters, { dust, grit })
    end
    local function pulse(strength, isFinal)
        if not host.Parent then
            return
        end
        for _, pair in emitters do
            pair[1]:Emit(isFinal and 5 or 2)
            pair[2]:Emit(isFinal and 2 or 1)
        end
        if isOwner then
            trauma = math.min(0.65, trauma + strength)
        end
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3"
        sound.Volume = isFinal and 0.26 or 0.12
        sound.PlaybackSpeed = isFinal and 0.42 or 0.58
        sound.RollOffMinDistance = 8
        sound.RollOffMaxDistance = 100
        sound.Parent = host
        local equalizer = Instance.new("EqualizerSoundEffect")
        equalizer.LowGain = 5
        equalizer.MidGain = -5
        equalizer.HighGain = -18
        equalizer.Parent = sound
        sound:Play()
        Debris:AddItem(sound, 1.5)
        -- A few solid earth chips tumble out with the final pressure release.
        if isFinal then
            for i = 1, 14 do
                local attachment = emitters[(i * 3) % #emitters + 1][1].Parent
                local origin = attachment.WorldPosition
                local direction = (origin - center).Unit
                local chip = Instance.new("Part")
                chip.Name = "EarthChip"
                chip.Size = Vector3.new(rng:NextNumber(0.15, 0.35), 0.16, rng:NextNumber(0.18, 0.4))
                chip.Material = Enum.Material.Slate
                chip.Color = Color3.fromRGB(106, 87, 61)
                chip.Anchored = true
                chip.CanCollide = false
                chip.CanTouch = false
                chip.CanQuery = false
                chip.CastShadow = false
                chip.CFrame = CFrame.new(origin)
                chip.Parent = host
                local landing = origin + direction * rng:NextNumber(1, 2.8)
                TweenService
                    :Create(chip, TweenInfo.new(0.17, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                        CFrame = CFrame.new((origin + landing) * 0.5 + Vector3.new(0, rng:NextNumber(0.35, 0.8), 0))
                            * CFrame.Angles(0.5, 0, 0.7),
                    })
                    :Play()
                task.delay(0.17, function()
                    if not chip.Parent then
                        return
                    end
                    TweenService
                        :Create(
                            chip,
                            TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                            { CFrame = CFrame.new(landing) * CFrame.Angles(1, 0, 1.4), Transparency = 1 }
                        )
                        :Play()
                end)
                Debris:AddItem(chip, 0.5)
            end
        end
    end
    -- Runs callback at BuildStart + delaySeconds (server time), if the model and effect host still exist.
    local function schedule(delaySeconds, callback)
        task.delay(math.max(0, buildStart + delaySeconds - workspace:GetServerTimeNow()), function()
            if model.Parent and host.Parent then
                callback()
            end
        end)
    end
    schedule(0, function()
        pulse(0.22, false)
    end)
    for step = 1, 10 do
        schedule(step * 0.24, function()
            for i, pair in emitters do
                if (i + step) % 3 ~= 0 then
                    pair[1]:Emit(rng:NextInteger(1, 3))
                end
            end
        end)
    end
    schedule(1.1, function()
        pulse(0.15, false)
    end)
    schedule(1.65, function()
        pulse(0.12, false)
    end)
    schedule(2.25, function()
        pulse(0.12, false)
    end)
    schedule(3.05, function()
        for _, pair in emitters do
            pair[1].Rate = 0
        end
        pulse(0.38, true)
    end)
    task.delay(5.5, function()
        activeModels[model] = nil
        if host.Parent then
            host:Destroy()
        end
    end)
end
CollectionService:GetInstanceAddedSignal("UpgradeAssembly"):Connect(function(model)
    task.spawn(playAssemblyEffects, model)
end)
for _, model in CollectionService:GetTagged("UpgradeAssembly") do
    task.spawn(playAssemblyEffects, model)
end
