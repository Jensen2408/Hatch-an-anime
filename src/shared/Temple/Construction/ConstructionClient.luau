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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent:WaitForChild("ConstructionConfig"))
local TAG = "Constructing"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local player = Players.LocalPlayer

local Client = {}
local jobs = {} -- [model] = job
local stepConn
local rng = Random.new()

---------------------------------------------------------------- helpers
local function ease(a, style, dir)
    return TweenService:GetValue(math.clamp(a, 0, 1), style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out)
end
local function quality()
    local q = Config.Effects.Quality
    if q == "High" then
        return 1
    elseif q == "Low" then
        return 0.4
    end
    local ok, lvl = pcall(function()
        return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
    end)
    if not ok or lvl == 0 then
        return 0.8
    end -- 0 = automatic
    return math.clamp(lvl / 10, 0.35, 1)
end
local function reducedMotion()
    return player:GetAttribute("ReducedMotion") == true
end

---------------------------------------------------------------- camera shake (additive, decaying, no drift)
local Shake = { impulses = {}, bound = false, last = CFrame.identity }
function Shake.add(amp, dur)
    if Config.Effects.CameraShake <= 0 or reducedMotion() then
        return
    end
    table.insert(
        Shake.impulses,
        { t0 = os.clock(), amp = amp * Config.Effects.CameraShake, dur = dur, seed = rng:NextNumber(0, 1000) }
    )
    if not Shake.bound then
        Shake.bound = true
        RunService:BindToRenderStep("ConstructionShake", Enum.RenderPriority.Camera.Value + 1, Shake.step)
    end
end
function Shake.step()
    local cam = workspace.CurrentCamera
    local now = os.clock()
    local x, y, r = 0, 0, 0
    for i = #Shake.impulses, 1, -1 do
        local s = Shake.impulses[i]
        local k = (now - s.t0) / s.dur
        if k >= 1 then
            table.remove(Shake.impulses, i)
        else
            local fall = (1 - k) ^ 2
            x += math.noise(s.seed, now * 22) * s.amp * fall
            y += math.noise(s.seed + 7, now * 22) * s.amp * fall
            r += math.noise(s.seed + 13, now * 18) * s.amp * 0.4 * fall
        end
    end
    -- the default camera controller rewrites CFrame each frame before us, so offsets never accumulate
    if cam and cam.CameraType ~= Enum.CameraType.Scriptable then
        cam.CFrame *= CFrame.new(x * 0.06, y * 0.06, 0) * CFrame.Angles(0, 0, math.rad(r * 0.5))
    end
    if #Shake.impulses == 0 then
        RunService:UnbindFromRenderStep("ConstructionShake")
        Shake.bound = false
    end
end

---------------------------------------------------------------- sounds
local function play(job, slot, vol, gapKey)
    local id = Config.Sounds[slot]
    if not id or id == "" or not job.fx then
        return
    end
    if gapKey then
        local now = os.clock()
        if job[gapKey] and now - job[gapKey] < Config.PlaceSoundGap then
            return
        end
        job[gapKey] = now
    end
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = (vol or 1) * Config.Effects.Volume
    s.RollOffMaxDistance = 140
    s.Parent = job.fx
    s:Play()
    s.Ended:Once(function()
        s:Destroy()
    end)
end

---------------------------------------------------------------- dust (pooled per construction)
local function groundColor(pos, ignore)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignore
    local hit = workspace:Raycast(pos + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params)
    if not hit then
        return Color3.fromRGB(176, 160, 136), pos.Y
    end
    local c = hit.Instance:IsA("Terrain") and workspace.Terrain:GetMaterialColor(hit.Material) or hit.Instance.Color
    return c:Lerp(Color3.fromRGB(200, 188, 168), 0.35), hit.Position.Y
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
    local col, gy = groundColor(job.base, { job.model, job.retireModel, player.Character })
    job.dustColor, job.groundY = col, gy
    for i = 1, Config.Effects.MaxDustPerConstruction do
        local a = Instance.new("Attachment")
        a.Parent = holder
        local e = Instance.new("ParticleEmitter")
        e.Texture = SMOKE
        e.Rate = 0
        e.Color = ColorSequence.new(col)
        e.LightInfluence = 1
        e.LightEmission = 0
        e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 2.6) })
        e.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.55),
            NumberSequenceKeypoint.new(0.3, 0.7),
            NumberSequenceKeypoint.new(1, 1),
        })
        e.Lifetime = NumberRange.new(0.7, 1.2)
        e.Speed = NumberRange.new(2.5, 5)
        e.SpreadAngle = Vector2.new(80, 10)
        e.EmissionDirection = Enum.NormalId.Top
        e.Acceleration = Vector3.new(0, -1.5, 0)
        e.Drag = 3
        e.RotSpeed = NumberRange.new(-30, 30)
        e.Rotation = NumberRange.new(0, 360)
        e.Parent = a
        job.emitters[i] = { att = a, em = e }
    end
    job.nextEm = 1
end
local function puff(job, pos, count, spread)
    if not job.fx or job.far then
        return
    end
    local slot = job.emitters[job.nextEm]
    job.nextEm = job.nextEm % #job.emitters + 1
    slot.att.WorldPosition = Vector3.new(pos.X, job.groundY + 0.2, pos.Z)
    slot.em.SpreadAngle = Vector2.new(spread or 80, 10)
    slot.em:Emit(math.max(1, math.floor(count * Config.Effects.DustDensity * job.q + 0.5)))
end
local function footprintPuff(job, count)
    local cf, size = job.boxCF, job.boxSize
    for _, c in
        {
            Vector3.new(-0.5, 0, -0.5),
            Vector3.new(0.5, 0, -0.5),
            Vector3.new(-0.5, 0, 0.5),
            Vector3.new(0.5, 0, 0.5),
            Vector3.new(0, 0, 0.5),
            Vector3.new(0, 0, -0.5),
        }
    do
        puff(job, (cf * CFrame.new(c.X * size.X * 0.9, 0, c.Z * size.Z * 0.9)).Position, count, 85)
    end
end

---------------------------------------------------------------- per-construction setup
local function hide(job, part)
    if job.state[part] then
        return
    end
    local batch = part:GetAttribute("Cx_Batch")
    local retire = part:GetAttribute("Cx_Retire") == true
    if not batch and not retire then
        return
    end
    local st = {
        final = part.CFrame,
        size = part.Size,
        batch = batch,
        retire = retire,
        fromCF = part:GetAttribute("Cx_FromCF"),
        fromSize = part:GetAttribute("Cx_FromSize"),
        ltm = part.LocalTransparencyModifier,
    }
    job.state[part] = st
    if batch then
        local b = job.batches[batch]
        if not b then
            b = { parts = {}, stage = part:GetAttribute("Cx_Stage") or 1, landed = false }
            job.batches[batch] = b
        end
        table.insert(b.parts, part)
        if not st.fromCF then
            part.LocalTransparencyModifier = 1
        end -- hidden until its wave
    else
        table.insert(job.retirees, part)
    end
end

local function batchOffsets(job, i, b)
    local k = Config.Kinds[job.kind]
    local r = Random.new(i * 7919 + (job.seed or 0))
    local first = b.stage == 1
    local rise = first and k.RiseDistance or k.UpperRise
    local side = (i % 2 == 0) and 1 or -1
    b.offset = Vector3.new(
        first and 0 or side * r:NextNumber(0.2, 1) * k.Lateral,
        -rise,
        first and 0 or r:NextNumber(-0.5, 0.5) * k.Lateral
    )
    b.tilt = first and CFrame.identity
        or CFrame.Angles(
            math.rad(r:NextNumber(-1, 1) * k.Tilt),
            math.rad(r:NextNumber(-1, 1) * k.Tilt * 0.6),
            math.rad(r:NextNumber(-1, 1) * k.Tilt)
        )
    -- pivot each batch around its own bottom-centre so rotations look like a block settling
    local sum, minY, n = Vector3.zero, math.huge, 0
    for _, p in b.parts do
        local s = job.state[p]
        sum += s.final.Position
        minY = math.min(minY, s.final.Position.Y - s.size.Y / 2)
        n += 1
    end
    local c = n > 0 and sum / n or job.base
    b.center = Vector3.new(c.X, minY, c.Z)
end

local function silhouette(job)
    if job.q < 0.5 or job.far then
        return
    end
    -- largest parts only: previews the real shape without cloning the whole model
    local list = {}
    for p, s in job.state do
        if s.batch and not s.fromCF then
            table.insert(list, p)
        end
    end
    table.sort(list, function(a, b)
        local sa, sb = a.Size, b.Size
        return sa.X * sa.Y * sa.Z > sb.X * sb.Y * sb.Z
    end)
    local folder = Instance.new("Folder")
    folder.Name = "ConstructionSilhouette"
    folder.Parent = workspace
    job.sil = folder
    for i = 1, math.min(36, #list) do
        local src = list[i]
        local g = Instance.new("Part")
        g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
        g.Material = Enum.Material.SmoothPlastic
        g.Color = Color3.fromRGB(255, 244, 222)
        g.Size = src.Size * 0.995
        g.CFrame = job.state[src].final
        g.Transparency = 1
        g.Parent = folder
    end
end

local function snapAll(job)
    local parts, cfs = {}, {}
    for p, s in job.state do
        if p.Parent and not s.retire then
            table.insert(parts, p)
            table.insert(cfs, s.final)
            if s.fromSize then
                p.Size = s.size
            end
            p.LocalTransparencyModifier = s.ltm or 0
        elseif p.Parent and s.retire then
            p.LocalTransparencyModifier = 1
        end
    end
    if #parts > 0 then
        workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
    end
end

local function cleanup(job)
    if job.cleaned then
        return
    end
    job.cleaned = true
    snapAll(job)
    if job.conns then
        for _, c in job.conns do
            c:Disconnect()
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
    local t = now - job.start
    local tl, k = job.tl, Config.Kinds[job.kind]
    if t >= tl.total or job.far then
        cleanup(job)
        return
    end
    local parts, cfs = {}, {}
    local mine = job.isMine

    -- retire (replacement / removed parts): sink and fade
    if #job.retirees > 0 then
        local a = math.clamp(t / math.max(tl.retireEnd, 0.3), 0, 1)
        local e = ease(a, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        for _, p in job.retirees do
            if p.Parent then
                local s = job.state[p]
                table.insert(parts, p)
                table.insert(cfs, s.final - Vector3.new(0, 1.2 * e, 0))
                p.LocalTransparencyModifier = math.max(s.ltm or 0, e)
            end
        end
        if not job.retirePuff and t > 0.05 then
            job.retirePuff = true
            footprintPuff(job, 3)
        end
    end

    -- anticipation
    if not job.antDone and t >= tl.retireEnd then
        job.antDone = true
        play(job, "Rumble", 0.7)
        if mine then
            Shake.add(0.5, k.Anticipation + 0.15)
        end
        footprintPuff(job, 2)
        silhouette(job)
    end
    if job.sil then
        local a = (t - tl.retireEnd) / math.max(k.Anticipation, 0.05)
        local tr = a < 0.35 and 1 - 0.18 * (a / 0.35) or 0.82 + 0.18 * math.clamp((a - 0.35) / 0.65, 0, 1)
        for _, g in job.sil:GetChildren() do
            g.Transparency = tr
        end
        if a >= 1 then
            job.sil:Destroy()
            job.sil = nil
        end
    end

    -- batches
    for i = 1, job.n do
        local b = job.batches[i]
        if b then
            if not b.offset then
                batchOffsets(job, i, b)
            end
            local bs = tl.batchStart(i)
            local a = (t - bs) / k.BatchMove
            if a >= 0 and not b.done then
                local e = ease(a, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
                local rot = CFrame.identity:Lerp(b.tilt, 1 - e)
                local off = b.offset * (1 - e)
                local fadeIn = math.clamp(a / 0.25, 0, 1)
                for _, p in b.parts do
                    local s = job.state[p]
                    if p.Parent then
                        if s.fromCF then
                            local cf = s.fromCF:Lerp(s.final, e)
                            table.insert(parts, p)
                            table.insert(cfs, cf)
                            if s.fromSize then
                                p.Size = s.fromSize:Lerp(s.size, e)
                            end
                        else
                            local rel = CFrame.new(b.center):ToObjectSpace(s.final)
                            table.insert(parts, p)
                            table.insert(cfs, CFrame.new(b.center + off) * rot * rel)
                            p.LocalTransparencyModifier = (b.stage == 1) and (s.ltm or 0)
                                or (1 - fadeIn) * (1 - (s.ltm or 0)) + (s.ltm or 0)
                        end
                    end
                end
                if a >= 1 then
                    b.done = true
                    -- exact final transform
                    for _, p in b.parts do
                        local s = job.state[p]
                        if p.Parent then
                            table.insert(parts, p)
                            table.insert(cfs, s.final)
                            if s.fromSize then
                                p.Size = s.size
                            end
                            p.LocalTransparencyModifier = s.ltm or 0
                        end
                    end
                    if b.stage == 1 then
                        puff(job, b.center, 4, 85)
                        play(job, "Place", 0.8, "_placeT")
                        if mine then
                            Shake.add(0.25, 0.18)
                        end
                    elseif i % 3 == 0 then
                        puff(job, b.center, 1, 60)
                    end
                    if b.stage > 1 then
                        play(job, k.Mechanical and "Click" or "Place", 0.5, "_placeT")
                    end
                end
            end
        end
    end
    if #parts > 0 then
        workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
    end

    -- lock-in
    if not job.locked and t >= tl.landed then
        job.locked = true
        play(job, "Impact", 1)
        if mine then
            Shake.add(0.8, 0.35)
        end
        footprintPuff(job, 5)
        if Config.Effects.SweepStrength > 0 and not job.far and job.q >= 0.4 then
            local hl = Instance.new("Highlight")
            hl.Adornee = job.model
            hl.DepthMode = Enum.HighlightDepthMode.Occluded
            hl.FillColor = Color3.fromRGB(255, 240, 210)
            hl.OutlineColor = Color3.fromRGB(255, 236, 196)
            hl.FillTransparency, hl.OutlineTransparency = 1, 1
            hl.Parent = job.fx
            job.hl = hl
            local sp = Instance.new("Part")
            sp.Anchored, sp.CanCollide, sp.CanQuery, sp.CanTouch, sp.Transparency = true, false, false, false, 1
            sp.Size = Vector3.new(0.2, 0.2, 0.2)
            sp.CFrame = CFrame.new(job.base)
            sp.Parent = workspace
            local light = Instance.new("PointLight")
            light.Color = Color3.fromRGB(255, 232, 190)
            light.Range = math.max(job.boxSize.X, job.boxSize.Z) * 0.8
            light.Brightness = 0
            light.Shadows = false
            light.Parent = sp
            job.sweepPart, job.sweepLight = sp, light
        end
    end
    if job.hl then
        local a = (t - tl.landed) / k.LockIn
        local pulse = math.sin(math.clamp(a, 0, 1) * math.pi)
        local str = Config.Effects.SweepStrength
        job.hl.OutlineTransparency = 1 - 0.55 * pulse * str
        job.hl.FillTransparency = 1 - 0.08 * pulse * str
        job.sweepPart.CFrame = CFrame.new(
            job.base + Vector3.new(0, job.boxSize.Y * ease(a, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), 0)
        )
        job.sweepLight.Brightness = 2.2 * pulse * str
        if a >= 1 then
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
local function begin(model)
    if jobs[model] or not model:IsA("Model") then
        return
    end
    local start = model:GetAttribute("Cx_Start")
    if not start then
        return
    end
    local kind = model:GetAttribute("Cx_Kind") or "Temple"
    local n = model:GetAttribute("Cx_Batches") or 1
    local replace = model:GetAttribute("Cx_Replace") == true
    local tl = Config.Timeline(kind, n, replace)
    local now = workspace:GetServerTimeNow()
    local job = {
        model = model,
        kind = kind,
        n = n,
        start = start,
        tl = tl,
        state = {},
        batches = {},
        retirees = {},
        isMine = model:GetAttribute("Cx_Owner") == player.UserId,
        seed = #model.Name,
        conns = {},
    }
    for _, d in model:GetDescendants() do
        if d:IsA("BasePart") then
            hide(job, d)
        end
    end
    -- late arrivals (StreamingEnabled) are hidden too
    table.insert(
        job.conns,
        model.DescendantAdded:Connect(function(d)
            if d:IsA("BasePart") then
                task.defer(hide, job, d)
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
        model.AncestryChanged:Connect(function(_, p)
            if not p then
                cleanup(job)
            end
        end)
    )
    local cf, size = model:GetBoundingBox()
    job.boxCF, job.boxSize = cf * CFrame.new(0, -size.Y / 2, 0), size
    job.base = job.boxCF.Position
    local cam = workspace.CurrentCamera
    local dist = cam and (cam.CFrame.Position - job.base).Magnitude or 0
    job.q = quality() * (dist > Config.Effects.EffectsDistance and 0 or 1)
    job.far = dist > Config.Effects.AnimateDistance or now - start >= tl.total
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

function Client.Start()
    for _, m in CollectionService:GetTagged(TAG) do
        task.spawn(begin, m)
    end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(begin)
end

return Client
