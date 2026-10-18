-- GoldFXClient (LocalScript, StarterPlayerScripts)
-- Animates the "GoldFX" rig that the server's GoldCharacterFX builds inside every model tagged "GoldCharacter":
-- a periodic shine sweep across the ShineBoxes textures, a highlight / warm light pulse, and a ground ring burst at
-- the middle of each sweep. Sweep timing comes from ReplicatedStorage.GoldShineConfig attributes
-- (Duration, Period, OffsetSign) and is phased on server time (+ model attribute GoldFXPhase) so all clients agree.
-- Everything is switched off beyond 120 studs from the camera; particle rates share a budget of 8 models.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local shineConfig = game.ReplicatedStorage:WaitForChild("GoldShineConfig")

local activeModels = {} -- [model] = per-model FX state (see trackModel)

-- Waits (up to 10 s per child) for the GoldFX rig, then starts animating the model. Yields; run via spawn/defer.
local function trackModel(model)
    if activeModels[model] then
        return
    end
    local fx = model:WaitForChild("GoldFX", 10)
    if not fx then
        return
    end
    local shineBoxes = fx:WaitForChild("ShineBoxes", 10)
    local emitterPart = fx:WaitForChild("GoldFX_Emitter", 10)
    local groundPart = fx:WaitForChild("GroundRing", 10)
    if not shineBoxes or not emitterPart or not groundPart then
        return
    end
    local light = emitterPart:WaitForChild("WarmLight", 10)
    local ring = groundPart:WaitForChild("RingBurst", 10)
    local highlight = fx:WaitForChild("GoldShine", 10)
    local textures = {}
    for _, descendant in ipairs(shineBoxes:GetDescendants()) do
        if descendant:IsA("Texture") then
            table.insert(textures, { texture = descendant, box = descendant.Parent, sideCycle = -1, sideStart = -1 })
        end
    end
    local root = model:FindFirstChild("HumanoidRootPart", true) or model:FindFirstChild("Torso", true)
    if not root then
        return
    end
    activeModels[model] = {
        fx = fx,
        root = root,
        boxes = shineBoxes:GetChildren(),
        textures = textures,
        light = light,
        ring = ring,
        highlight = highlight,
        start = workspace:GetServerTimeNow() - (model:GetAttribute("GoldFXPhase") or 0),
        burstCycle = -1, -- last sweep cycle that already fired the ring burst
    }
end

CollectionService:GetInstanceAddedSignal("GoldCharacter"):Connect(function(model)
    task.defer(trackModel, model)
end)
CollectionService:GetInstanceRemovedSignal("GoldCharacter"):Connect(function(model)
    activeModels[model] = nil
end)
for _, model in ipairs(CollectionService:GetTagged("GoldCharacter")) do
    task.spawn(trackModel, model)
end

RunService.RenderStepped:Connect(function()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local now = workspace:GetServerTimeNow()
    local duration = shineConfig:GetAttribute("Duration") or 0.9
    local period = math.max(shineConfig:GetAttribute("Period") or 3.2, duration + 0.1)
    local offsetSign = shineConfig:GetAttribute("OffsetSign") or 1
    local modelCount = 0
    for _ in pairs(activeModels) do
        modelCount += 1
    end
    local particleBudget = math.min(1, 8 / math.max(1, modelCount))
    for model, data in pairs(activeModels) do
        if not model:IsDescendantOf(workspace) or not data.fx.Parent then
            activeModels[model] = nil
        else
            local near = (camera.CFrame.Position - data.root.Position).Magnitude < 120
            local elapsed = math.max(0, now - data.start)
            local cycle = math.floor(elapsed / period)
            local phase = elapsed % period
            local sweeping = near and phase < duration
            local progress = math.clamp(phase / duration, 0, 1)
            -- triangle 0 -> 1 -> 0 over the sweep, peaking at mid-sweep
            local pulse = sweeping and math.max(0, 1 - math.abs(phase - duration * 0.5) / (duration * 0.5)) or 0
            if data.highlight then
                data.highlight.Enabled = near
                data.highlight.FillTransparency = 0.86 - 0.44 * pulse * pulse
            end
            if data.light then
                data.light.Enabled = near
                data.light.Brightness = 1.4 + 0.25 * math.sin(elapsed * 2) + 1.6 * pulse
            end
            if sweeping and phase >= duration * 0.5 and data.burstCycle ~= cycle then
                data.burstCycle = cycle
                if data.ring then
                    data.ring:Emit(math.floor(40 * particleBudget))
                end
            end
            for _, emitter in ipairs(data.fx.GoldFX_Emitter:GetChildren()) do
                if emitter:IsA("ParticleEmitter") then
                    emitter.Enabled = near
                    emitter.Rate = (emitter:GetAttribute("BaseRate") or 10) * particleBudget
                end
            end
            for _, shell in ipairs(data.fx.ShineShells:GetChildren()) do
                if shell:IsA("BasePart") then
                    shell.Transparency = 1
                end
            end
            if sweeping then
                -- The sweep travels along the root's RightVector. Project every ShineBox corner on it to get the
                -- sweep range (padded by 3 studs) and the top Y used to align the texture vertically.
                local rightVector = data.root.CFrame.RightVector
                local minRight, maxRight, topY = math.huge, -math.huge, -math.huge
                for _, box in ipairs(data.boxes) do
                    for _, x in ipairs({ -0.5, 0.5 }) do
                        for _, y in ipairs({ -0.5, 0.5 }) do
                            for _, z in ipairs({ -0.5, 0.5 }) do
                                local corner = box.CFrame:PointToWorldSpace(
                                    Vector3.new(box.Size.X * x, box.Size.Y * y, box.Size.Z * z)
                                )
                                local projected = corner:Dot(rightVector)
                                minRight = math.min(minRight, projected)
                                maxRight = math.max(maxRight, projected)
                                topY = math.max(topY, corner.Y)
                            end
                        end
                    end
                end
                minRight -= 3
                maxRight += 3
                -- smoothstep position of the sweep line along rightVector
                local sweepPosition = minRight + (maxRight - minRight) * (progress * progress * (3 - 2 * progress))
                local fade = math.min(1, progress / 0.1, (1 - progress) / 0.1)
                for _, entry in ipairs(data.textures) do
                    local texture, box = entry.texture, entry.box
                    -- faceU: direction of increasing texture U on this face; faceNormal: outward normal
                    local faceU, faceNormal, faceWidth
                    if texture.Face == Enum.NormalId.Front then
                        faceU = -box.CFrame.RightVector
                        faceNormal = box.CFrame.LookVector
                        faceWidth = box.Size.X
                    elseif texture.Face == Enum.NormalId.Back then
                        faceU = box.CFrame.RightVector
                        faceNormal = -box.CFrame.LookVector
                        faceWidth = box.Size.X
                    elseif texture.Face == Enum.NormalId.Left then
                        faceU = box.CFrame.LookVector
                        faceNormal = -box.CFrame.RightVector
                        faceWidth = box.Size.Z
                    else
                        faceU = -box.CFrame.LookVector
                        faceNormal = box.CFrame.RightVector
                        faceWidth = box.Size.Z
                    end
                    local depth = (texture.Face == Enum.NormalId.Front or texture.Face == Enum.NormalId.Back)
                            and box.Size.Z
                        or box.Size.X
                    local faceCenter = box.Position + faceNormal * depth * 0.5
                    local origin = faceCenter - faceU * faceWidth * 0.5 + box.CFrame.UpVector * box.Size.Y * 0.5
                    local alignment = faceU:Dot(rightVector)
                    local band
                    if math.abs(alignment) > 0.8 then
                        -- face runs along the sweep: place the band where the sweep line crosses it
                        band = (sweepPosition - origin:Dot(rightVector)) / alignment
                    else
                        -- side face: play a short 0.25 s wipe once the sweep line reaches the face centre
                        if entry.sideCycle ~= cycle then
                            entry.sideCycle = cycle
                            entry.sideStart = -1
                        end
                        if entry.sideStart < 0 and math.abs(sweepPosition - faceCenter:Dot(rightVector)) <= 0.6 then
                            entry.sideStart = phase
                        end
                        if entry.sideStart >= 0 and phase - entry.sideStart <= 0.25 then
                            band = -1 + (faceWidth + 2) * math.clamp((phase - entry.sideStart) / 0.25, 0, 1)
                        end
                    end
                    if band then
                        texture.OffsetStudsU = offsetSign * (8 - band)
                        texture.OffsetStudsV = topY - (box.Position.Y + box.Size.Y * 0.5)
                        texture.Transparency = 1 - 0.9 * fade
                    else
                        texture.Transparency = 1
                    end
                end
            else
                for _, entry in ipairs(data.textures) do
                    entry.texture.Transparency = 1
                end
            end
        end
    end
end)
