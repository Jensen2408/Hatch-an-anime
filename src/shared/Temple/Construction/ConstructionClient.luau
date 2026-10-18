--[[ ReplicatedStorage.Construction.ConstructionClient  (ModuleScript, client)
Cosmetic side of construction. Mirrors the server's authoritative final state:
  • hides animated parts the moment they replicate (LocalTransparencyModifier — local only)
  • one shared RenderStepped loop for every active construction (no per-part tweens or loops)
  • moves parts with workspace:BulkMoveTo, easing via TweenService:GetValue
  • pooled dust emitters, throttled sounds, additive camera shake for the purchaser only
  • every part is snapped back to its exact server CFrame / Size at the end or on any error
Start it once:  require(ReplicatedStorage.Construction.ConstructionClient).Start()
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local _ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent:WaitForChild("ConstructionConfig"))
local TAG = "Constructing"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local localPlayer = Players.LocalPlayer

local ConstructionClient = {}
-- [model] = job. A job holds: state[part] = { final, size, batch, retire, fromCF, fromSize, ltm },
-- batches[i] = { parts, stage, offset, tilt, center, done }, retirees, timeline (tl), quality factor (q),
-- far (skip animation) and its effect instances (fx, sil, hl, sweepPart).
local jobs = {}
local stepConn -- the single RenderStepped connection; disconnected when no job is left
local rng = Random.new()

---------------------------------------------------------------- helpers
local function ease(alpha, style, direction)
    return TweenService:GetValue(
        math.clamp(alpha, 0, 1),
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
end
local function quality()
    local setting = Config.Effects.Quality
    if setting == "High" then
        return 1
    elseif setting == "Low" then
        return 0.4
    end
    local ok, qualityLevel = pcall(function()
        return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
    end)
    if not ok or qualityLevel == 0 then
        return 0.8
    end -- 0 = automatic
    return math.clamp(qualityLevel / 10, 0.35, 1)
end
local function reducedMotion()
    return localPlayer:GetAttribute("ReducedMotion") == true
end

---------------------------------------------------------------- camera shake (additive, decaying, no drift)
local Shake = { impulses = {}, bound = false, last = CFrame.identity }
function Shake.add(amplitude, duration)
    if Config.Effects.CameraShake <= 0 or reducedMotion() then
        return
    end
    table.insert(Shake.impulses, {
        t0 = os.clock(),
        amp = amplitude * Config.Effects.CameraShake,
        dur = duration,
        seed = rng:NextNumber(0, 1000),
    })
    if not Shake.bound then
        Shake.bound = true
        RunService:BindToRenderStep("ConstructionShake", Enum.RenderPriority.Camera.Value + 1, Shake.step)
    end
end
function Shake.step()
    local camera = workspace.CurrentCamera
    local now = os.clock()
    local offsetX, offsetY, roll = 0, 0, 0
    for i = #Shake.impulses, 1, -1 do
        local impulse = Shake.impulses[i]
        local progress = (now - impulse.t0) / impulse.dur
        if progress >= 1 then
            table.remove(Shake.impulses, i)
        else
            local falloff = (1 - progress) ^ 2
            offsetX += math.noise(impulse.seed, now * 22) * impulse.amp * falloff
            offsetY += math.noise(impulse.seed + 7, now * 22) * impulse.amp * falloff
            roll += math.noise(impulse.seed + 13, now * 18) * impulse.amp * 0.4 * falloff
        end
    end
    -- the default camera controller rewrites CFrame each frame before us, so offsets never accumulate
    if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
        camera.CFrame *= CFrame.new(offsetX * 0.06, offsetY * 0.06, 0) * CFrame.Angles(0, 0, math.rad(roll * 0.5))
    end
    if #Shake.impulses == 0 then
        RunService:UnbindFromRenderStep("ConstructionShake")
        Shake.bound = false
    end
end

---------------------------------------------------------------- sounds
local function playSound(job, soundName, volume, gapKey)
    local soundId = Config.Sounds[soundName]
    if not soundId or soundId == "" or not job.fx then
        return
    end
    if gapKey then
        local now = os.clock()
        if job[gapKey] and now - job[gapKey] < Config.PlaceSoundGap then
            return
        end
        job[gapKey] = now
    end
    local sound = Instance.new("Sound")
    sound.SoundId = soundId
    sound.Volume = (volume or 1) * Config.Effects.Volume
    sound.RollOffMaxDistance = 140
    sound.Parent = job.fx
    sound:Play()
    sound.Ended:Once(function()
        sound:Destroy()
    end)
end

---------------------------------------------------------------- dust (pooled per construction)
local function groundColor(position, ignoreList)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignoreList
    local hit = workspace:Raycast(position + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
    if not hit then
        return Color3.fromRGB(176, 160, 136), position.Y
    end
    local surfaceColor = hit.Instance:IsA("Terrain") and workspace.Terrain:GetMaterialColor(hit.Material)
        or hit.Instance.Color
    return surfaceColor:Lerp(Color3.fromRGB(200, 188, 168), 0.35), hit.Position.Y
end
local function makeFx(job)
    local holder = Instance.new("Part")
    holder.Name = "ConstructionFX"
    holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.CastShadow =
        true, false, false, false, false
    holder.Transparency = 1
    holder.Size = Vector3.new(0.2, 0.2, 0.2)
    holder.CFrame = CFrame.new(job.base)
    holder.Parent = workspace
    job.fx = holder
    job.emitters = {}
    local dustColor, groundY = groundColor(job.base, { job.model, job.retireModel, localPlayer.Character })
    job.dustColor, job.groundY = dustColor, groundY
    for i = 1, Config.Effects.MaxDustPerConstruction do
        local attachment = Instance.new("Attachment")
        attachment.Parent = holder
        local emitter = Instance.new("ParticleEmitter")
        emitter.Texture = SMOKE
        emitter.Rate = 0
        emitter.Color = ColorSequence.new(dustColor)
        emitter.LightInfluence = 1
        emitter.LightEmission = 0
        emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 2.6) })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.55),
            NumberSequenceKeypoint.new(0.3, 0.7),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Lifetime = NumberRange.new(0.7, 1.2)
        emitter.Speed = NumberRange.new(2.5, 5)
        emitter.SpreadAngle = Vector2.new(80, 10)
        emitter.EmissionDirection = Enum.NormalId.Top
        emitter.Acceleration = Vector3.new(0, -1.5, 0)
        emitter.Drag = 3
        emitter.RotSpeed = NumberRange.new(-30, 30)
        emitter.Rotation = NumberRange.new(0, 360)
        emitter.Parent = attachment
        job.emitters[i] = { att = attachment, em = emitter }
    end
    job.nextEm = 1
end
local function puff(job, position, count, spread)
    if not job.fx or job.far then
        return
    end
    local emitterSlot = job.emitters[job.nextEm]
    job.nextEm = job.nextEm % #job.emitters + 1
    emitterSlot.att.WorldPosition = Vector3.new(position.X, job.groundY + 0.2, position.Z)
    emitterSlot.em.SpreadAngle = Vector2.new(spread or 80, 10)
    emitterSlot.em:Emit(math.max(1, math.floor(count * Config.Effects.DustDensity * job.q + 0.5)))
end
local function footprintPuff(job, count)
    local boxCFrame, size = job.boxCF, job.boxSize
    for _, corner in
        {
            Vector3.new(-0.5, 0, -0.5),
            Vector3.new(0.5, 0, -0.5),
            Vector3.new(-0.5, 0, 0.5),
            Vector3.new(0.5, 0, 0.5),
            Vector3.new(0, 0, 0.5),
            Vector3.new(0, 0, -0.5),
        }
    do
        puff(job, (boxCFrame * CFrame.new(corner.X * size.X * 0.9, 0, corner.Z * size.Z * 0.9)).Position, count, 85)
    end
end

---------------------------------------------------------------- per-construction setup
-- Registers a Cx_* tagged part with the job and hides it locally until its batch animates in.
local function hide(job, part)
    if job.state[part] then
        return
    end
    local batch = part:GetAttribute("Cx_Batch")
    local retire = part:GetAttribute("Cx_Retire") == true
    if not batch and not retire then
        return
    end
    local partState = {
        final = part.CFrame,
        size = part.Size,
        batch = batch,
        retire = retire,
        fromCF = part:GetAttribute("Cx_FromCF"),
        fromSize = part:GetAttribute("Cx_FromSize"),
        ltm = part.LocalTransparencyModifier,
    }
    job.state[part] = partState
    if batch then
        local batchInfo = job.batches[batch]
        if not batchInfo then
            batchInfo = { parts = {}, stage = part:GetAttribute("Cx_Stage") or 1, landed = false }
            job.batches[batch] = batchInfo
        end
        table.insert(batchInfo.parts, part)
        if not partState.fromCF then
            part.LocalTransparencyModifier = 1
        end -- hidden until its wave
    else
        table.insert(job.retirees, part)
    end
end

-- Lazily computes a batch's start offset/tilt (deterministic per batch index + model seed).
local function batchOffsets(job, batchIndex, batchInfo)
    local kindConfig = Config.Kinds[job.kind]
    local random = Random.new(batchIndex * 7919 + (job.seed or 0))
    local first = batchInfo.stage == 1
    local rise = first and kindConfig.RiseDistance or kindConfig.UpperRise
    local side = (batchIndex % 2 == 0) and 1 or -1
    batchInfo.offset = Vector3.new(
        first and 0 or side * random:NextNumber(0.2, 1) * kindConfig.Lateral,
        -rise,
        first and 0 or random:NextNumber(-0.5, 0.5) * kindConfig.Lateral
    )
    batchInfo.tilt = first and CFrame.identity
        or CFrame.Angles(
            math.rad(random:NextNumber(-1, 1) * kindConfig.Tilt),
            math.rad(random:NextNumber(-1, 1) * kindConfig.Tilt * 0.6),
            math.rad(random:NextNumber(-1, 1) * kindConfig.Tilt)
        )
    -- pivot each batch around its own bottom-centre so rotations look like a block settling
    local sum, minY, partCount = Vector3.zero, math.huge, 0
    for _, part in batchInfo.parts do
        local partState = job.state[part]
        sum += partState.final.Position
        minY = math.min(minY, partState.final.Position.Y - partState.size.Y / 2)
        partCount += 1
    end
    local centre = partCount > 0 and sum / partCount or job.base
    batchInfo.center = Vector3.new(centre.X, minY, centre.Z)
end

local function silhouette(job)
    if job.q < 0.5 or job.far then
        return
    end
    -- largest parts only: previews the real shape without cloning the whole model
    local largestParts = {}
    for part, partState in job.state do
        if partState.batch and not partState.fromCF then
            table.insert(largestParts, part)
        end
    end
    table.sort(largestParts, function(partA, partB)
        local sizeA, sizeB = partA.Size, partB.Size
        return sizeA.X * sizeA.Y * sizeA.Z > sizeB.X * sizeB.Y * sizeB.Z
    end)
    local folder = Instance.new("Folder")
    folder.Name = "ConstructionSilhouette"
    folder.Parent = workspace
    job.sil = folder
    for i = 1, math.min(36, #largestParts) do
        local sourcePart = largestParts[i]
        local ghost = Instance.new("Part")
        ghost.Anchored, ghost.CanCollide, ghost.CanQuery, ghost.CanTouch, ghost.CastShadow =
            true, false, false, false, false
        ghost.Material = Enum.Material.SmoothPlastic
        ghost.Color = Color3.fromRGB(255, 244, 222)
        ghost.Size = sourcePart.Size * 0.995
        ghost.CFrame = job.state[sourcePart].final
        ghost.Transparency = 1
        ghost.Parent = folder
    end
end

-- Puts every part at its exact server transform (used at the end and on any error).
local function snapAll(job)
    local parts, cframes = {}, {}
    for part, partState in job.state do
        if part.Parent and not partState.retire then
            table.insert(parts, part)
            table.insert(cframes, partState.final)
            if partState.fromSize then
                part.Size = partState.size
            end
            part.LocalTransparencyModifier = partState.ltm or 0
        elseif part.Parent and partState.retire then
            part.LocalTransparencyModifier = 1
        end
    end
    if #parts > 0 then
        workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
    end
end

local function cleanup(job)
    if job.cleaned then
        return
    end
    job.cleaned = true
    snapAll(job)
    if job.conns then
        for _, connection in job.conns do
            connection:Disconnect()
        end
    end
    if job.sil then
        job.sil:Destroy()
    end
    if job.sweepPart then
        job.sweepPart:Destroy()
    end
    if job.hl then
        job.hl:Destroy()
    end
    if job.fx then
        local fx = job.fx
        task.delay(1.5, function()
            fx:Destroy()
        end)
    end -- let dust finish drifting
    jobs[job.model] = nil
    if next(jobs) == nil and stepConn then
        stepConn:Disconnect()
        stepConn = nil
    end
end

---------------------------------------------------------------- the shared step
local function stepJob(job, now)
    local elapsed = now - job.start
    local timeline, kindConfig = job.tl, Config.Kinds[job.kind]
    if elapsed >= timeline.total or job.far then
        cleanup(job)
        return
    end
    local parts, cframes = {}, {}
    local isMine = job.isMine

    -- retire (replacement / removed parts): sink and fade
    if #job.retirees > 0 then
        local alpha = math.clamp(elapsed / math.max(timeline.retireEnd, 0.3), 0, 1)
        local eased = ease(alpha, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        for _, part in job.retirees do
            if part.Parent then
                local partState = job.state[part]
                table.insert(parts, part)
                table.insert(cframes, partState.final - Vector3.new(0, 1.2 * eased, 0))
                part.LocalTransparencyModifier = math.max(partState.ltm or 0, eased)
            end
        end
        if not job.retirePuff and elapsed > 0.05 then
            job.retirePuff = true
            footprintPuff(job, 3)
        end
    end

    -- anticipation
    if not job.antDone and elapsed >= timeline.retireEnd then
        job.antDone = true
        playSound(job, "Rumble", 0.7)
        if isMine then
            Shake.add(0.5, kindConfig.Anticipation + 0.15)
        end
        footprintPuff(job, 2)
        silhouette(job)
    end
    if job.sil then
        local alpha = (elapsed - timeline.retireEnd) / math.max(kindConfig.Anticipation, 0.05)
        local transparency = alpha < 0.35 and 1 - 0.18 * (alpha / 0.35)
            or 0.82 + 0.18 * math.clamp((alpha - 0.35) / 0.65, 0, 1)
        for _, ghost in job.sil:GetChildren() do
            ghost.Transparency = transparency
        end
        if alpha >= 1 then
            job.sil:Destroy()
            job.sil = nil
        end
    end

    -- batches
    for i = 1, job.n do
        local batchInfo = job.batches[i]
        if batchInfo then
            if not batchInfo.offset then
                batchOffsets(job, i, batchInfo)
            end
            local batchStart = timeline.batchStart(i)
            local alpha = (elapsed - batchStart) / kindConfig.BatchMove
            if alpha >= 0 and not batchInfo.done then
                local eased = ease(alpha, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
                local rotation = CFrame.identity:Lerp(batchInfo.tilt, 1 - eased)
                local offset = batchInfo.offset * (1 - eased)
                local fadeIn = math.clamp(alpha / 0.25, 0, 1)
                for _, part in batchInfo.parts do
                    local partState = job.state[part]
                    if part.Parent then
                        if partState.fromCF then
                            local cframe = partState.fromCF:Lerp(partState.final, eased)
                            table.insert(parts, part)
                            table.insert(cframes, cframe)
                            if partState.fromSize then
                                part.Size = partState.fromSize:Lerp(partState.size, eased)
                            end
                        else
                            local relative = CFrame.new(batchInfo.center):ToObjectSpace(partState.final)
                            table.insert(parts, part)
                            table.insert(cframes, CFrame.new(batchInfo.center + offset) * rotation * relative)
                            part.LocalTransparencyModifier = (batchInfo.stage == 1) and (partState.ltm or 0)
                                or (1 - fadeIn) * (1 - (partState.ltm or 0)) + (partState.ltm or 0)
                        end
                    end
                end
                if alpha >= 1 then
                    batchInfo.done = true
                    -- exact final transform
                    for _, part in batchInfo.parts do
                        local partState = job.state[part]
                        if part.Parent then
                            table.insert(parts, part)
                            table.insert(cframes, partState.final)
                            if partState.fromSize then
                                part.Size = partState.size
                            end
                            part.LocalTransparencyModifier = partState.ltm or 0
                        end
                    end
                    if batchInfo.stage == 1 then
                        puff(job, batchInfo.center, 4, 85)
                        playSound(job, "Place", 0.8, "_placeT")
                        if isMine then
                            Shake.add(0.25, 0.18)
                        end
                    elseif i % 3 == 0 then
                        puff(job, batchInfo.center, 1, 60)
                    end
                    if batchInfo.stage > 1 then
                        playSound(job, kindConfig.Mechanical and "Click" or "Place", 0.5, "_placeT")
                    end
                end
            end
        end
    end
    if #parts > 0 then
        workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
    end

    -- lock-in
    if not job.locked and elapsed >= timeline.landed then
        job.locked = true
        playSound(job, "Impact", 1)
        if isMine then
            Shake.add(0.8, 0.35)
        end
        footprintPuff(job, 5)
        if Config.Effects.SweepStrength > 0 and not job.far and job.q >= 0.4 then
            local highlight = Instance.new("Highlight")
            highlight.Adornee = job.model
            highlight.DepthMode = Enum.HighlightDepthMode.Occluded
            highlight.FillColor = Color3.fromRGB(255, 240, 210)
            highlight.OutlineColor = Color3.fromRGB(255, 236, 196)
            highlight.FillTransparency, highlight.OutlineTransparency = 1, 1
            highlight.Parent = job.fx
            job.hl = highlight
            local sweepPart = Instance.new("Part")
            sweepPart.Anchored, sweepPart.CanCollide, sweepPart.CanQuery, sweepPart.CanTouch, sweepPart.Transparency =
                true, false, false, false, 1
            sweepPart.Size = Vector3.new(0.2, 0.2, 0.2)
            sweepPart.CFrame = CFrame.new(job.base)
            sweepPart.Parent = workspace
            local light = Instance.new("PointLight")
            light.Color = Color3.fromRGB(255, 232, 190)
            light.Range = math.max(job.boxSize.X, job.boxSize.Z) * 0.8
            light.Brightness = 0
            light.Shadows = false
            light.Parent = sweepPart
            job.sweepPart, job.sweepLight = sweepPart, light
        end
    end
    if job.hl then
        local alpha = (elapsed - timeline.landed) / kindConfig.LockIn
        local pulse = math.sin(math.clamp(alpha, 0, 1) * math.pi)
        local sweepStrength = Config.Effects.SweepStrength
        job.hl.OutlineTransparency = 1 - 0.55 * pulse * sweepStrength
        job.hl.FillTransparency = 1 - 0.08 * pulse * sweepStrength
        job.sweepPart.CFrame = CFrame.new(
            job.base + Vector3.new(0, job.boxSize.Y * ease(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), 0)
        )
        job.sweepLight.Brightness = 2.2 * pulse * sweepStrength
        if alpha >= 1 then
            job.hl:Destroy()
            job.hl = nil
            job.sweepPart:Destroy()
            job.sweepPart = nil
        end
    end
end

local function step()
    local now = workspace:GetServerTimeNow()
    for _, job in jobs do
        local ok, err = pcall(stepJob, job, now)
        if not ok then
            warn("[Construction] animation error, snapping:", err)
            cleanup(job)
        end
    end
end

---------------------------------------------------------------- tag handling
-- Called for every model tagged "Constructing" (incl. ones already tagged when Start runs).
local function begin(model)
    if jobs[model] or not model:IsA("Model") then
        return
    end
    local startTime = model:GetAttribute("Cx_Start")
    if not startTime then
        return
    end
    local kind = model:GetAttribute("Cx_Kind") or "Temple"
    local batchCount = model:GetAttribute("Cx_Batches") or 1
    local replace = model:GetAttribute("Cx_Replace") == true
    local timeline = Config.Timeline(kind, batchCount, replace)
    local now = workspace:GetServerTimeNow()
    local job = {
        model = model,
        kind = kind,
        n = batchCount,
        start = startTime,
        tl = timeline,
        state = {},
        batches = {},
        retirees = {},
        isMine = model:GetAttribute("Cx_Owner") == localPlayer.UserId,
        seed = #model.Name,
        conns = {},
    }
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            hide(job, descendant)
        end
    end
    -- late arrivals (StreamingEnabled) are hidden too
    table.insert(
        job.conns,
        model.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("BasePart") then
                task.defer(hide, job, descendant)
            end
        end)
    )
    table.insert(
        job.conns,
        model:GetAttributeChangedSignal("ConstructionCancelled"):Connect(function()
            if model:GetAttribute("ConstructionCancelled") then
                cleanup(job)
            end
        end)
    )
    table.insert(
        job.conns,
        model.AncestryChanged:Connect(function(_, newParent)
            if not newParent then
                cleanup(job)
            end
        end)
    )
    local boxCFrame, size = model:GetBoundingBox()
    job.boxCF, job.boxSize = boxCFrame * CFrame.new(0, -size.Y / 2, 0), size
    job.base = job.boxCF.Position
    local camera = workspace.CurrentCamera
    local distance = camera and (camera.CFrame.Position - job.base).Magnitude or 0
    job.q = quality() * (distance > Config.Effects.EffectsDistance and 0 or 1)
    job.far = distance > Config.Effects.AnimateDistance or now - startTime >= timeline.total
    jobs[model] = job
    if job.far then
        cleanup(job)
        return
    end
    makeFx(job)
    if not stepConn then
        stepConn = RunService.RenderStepped:Connect(step)
    end
end

function ConstructionClient.Start()
    for _, model in CollectionService:GetTagged(TAG) do
        task.spawn(begin, model)
    end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(begin)
end

return ConstructionClient
