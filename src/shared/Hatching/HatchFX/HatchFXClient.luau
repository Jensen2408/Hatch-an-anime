--[[ ReplicatedStorage.HatchFX.HatchFXClient  (ModuleScript, client)
Cosmetic hatch sequence. Started by HatchFXClientStart. Reads only what the server put on the incubator.
One shared RenderStepped loop drives every active hatch; each hatch keeps its own state (no shared conflicts).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent:WaitForChild("HatchFXConfig"))

local player = Players.LocalPlayer
local TAG = "Hatching"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SOFT = "rbxasset://textures/particles/smoke_main.dds"
local Client = {}
local jobs, seen = {}, {}
local watched = setmetatable({}, { __mode = "k" })
local loop
local rng = Random.new()

local function reduced()
    return player:GetAttribute(Config.ReducedMotionAttribute) == true
end
local function make(c, p, parent)
    local o = Instance.new(c)
    for k, v in p do
        o[k] = v
    end
    if parent then
        o.Parent = parent
    end
    return o
end
local function fxPart(props, parent)
    local p = make("Part", {
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        CastShadow = false,
        Material = Enum.Material.Neon,
        TopSurface = Enum.SurfaceType.Smooth,
        BottomSurface = Enum.SurfaceType.Smooth,
    }, nil)
    for k, v in props do
        p[k] = v
    end
    p.Parent = parent
    return p
end
local function smooth(a)
    a = math.clamp(a, 0, 1)
    return a * a * (3 - 2 * a)
end
local function eggParts(egg, skip)
    local t = {}
    for _, d in egg:GetDescendants() do
        if d:IsA("BasePart") and not (skip and skip[d]) then
            table.insert(t, d)
        end
    end
    return t
end
local function setLTM(parts, v)
    for _, p in parts do
        if p.Parent then
            p.LocalTransparencyModifier = v
        end
    end
end

---------------------------------------------------------------- camera shake (owner only, additive, no drift)
local Shake = { list = {}, bound = false }
function Shake.add(amp, dur)
    if Config.CameraShake <= 0 or reduced() then
        return
    end
    table.insert(
        Shake.list,
        { t0 = os.clock(), amp = amp * Config.CameraShake, dur = dur, seed = rng:NextNumber(0, 999) }
    )
    if Shake.bound then
        return
    end
    Shake.bound = true
    RunService:BindToRenderStep("HatchShake", Enum.RenderPriority.Camera.Value + 1, function()
        local cam, now, x, y = workspace.CurrentCamera, os.clock(), 0, 0
        for i = #Shake.list, 1, -1 do
            local s = Shake.list[i]
            local k = (now - s.t0) / s.dur
            if k >= 1 then
                table.remove(Shake.list, i)
            else
                local f = (1 - k) ^ 2
                x += math.noise(s.seed, now * 24) * s.amp * f
                y += math.noise(s.seed + 9, now * 24) * s.amp * f
            end
        end
        if cam and cam.CameraType ~= Enum.CameraType.Scriptable then
            cam.CFrame *= CFrame.new(x * 0.05, y * 0.05, 0)
        end
        if #Shake.list == 0 then
            RunService:UnbindFromRenderStep("HatchShake")
            Shake.bound = false
        end
    end)
end
player.CharacterAdded:Connect(function()
    Shake.list = {}
end)

---------------------------------------------------------------- sound
local function sound(job, slot, props)
    local id = Config.Sounds[slot]
    if not id or id == "" or player:GetAttribute(Config.MuteAttribute) or not job.att then
        return nil
    end
    local vol = (Config.SlotVolumes and Config.SlotVolumes[slot]) or Config.Volume
    local s = make("Sound", { SoundId = id, Volume = vol, RollOffMaxDistance = 80 }, job.att)
    local g = SoundService:FindFirstChild(Config.SoundGroupName)
    if g and g:IsA("SoundGroup") then
        s.SoundGroup = g
    end
    if props then
        for k, v in props do
            s[k] = v
        end
    end
    s:Play()
    if not s.Looped then
        s.Ended:Once(function()
            s:Destroy()
        end)
    end
    return s
end

---------------------------------------------------------------- cracks: snapped to the egg's real surface
-- Raycasts from outside toward the egg's axis and only accepts hits on the egg's own parts,
-- so every crack segment lies on an actual face. Prepared assets (see README) take priority.
local function buildCracks(job)
    local egg, cf, size = job.egg, job.eggCF, job.eggSize
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { egg }
    local R = math.max(size.X, size.Z)
    local axis = cf.Position
    local function surf(theta, y)
        local dir = (cf.RightVector * math.cos(theta) + cf.LookVector * math.sin(theta))
        local org = axis + cf.UpVector * y + dir * R * 1.5
        local hit = workspace:Raycast(org, -dir * R * 1.6, params)
        return hit and hit.Position, hit and hit.Normal
    end
    local w = math.max(0.035, size.Y * Config.CrackWidth * 0.5)
    local cam = workspace.CurrentCamera
    local toCam = cam and (cam.CFrame.Position - axis) or cf.LookVector
    local theta0 = math.atan2(toCam:Dot(cf.LookVector), toCam:Dot(cf.RightVector)) -- start on the side the player sees
    local segs = {}
    local function path(theta, y, dy, steps, t0, width, depth)
        local p0, n0 = surf(theta, y)
        for i = 1, steps do
            local th2, y2 = theta + rng:NextNumber(-0.22, 0.22), y + dy
            local p1, n1 = surf(th2, y2)
            if p0 and p1 and (p1 - p0).Magnitude < size.Y * 0.3 then
                local n = (n0 + n1).Unit
                local mid = (p0 + p1) / 2 + n * 0.012
                table.insert(segs, {
                    cf = CFrame.lookAt(mid, (p1 + n * 0.012), n),
                    len = (p1 - p0).Magnitude + w,
                    w = width,
                    t = t0 + i * 0.06,
                })
                if depth < 2 and rng:NextNumber() < 0.28 then
                    path(th2, y2, dy * 0.8, math.max(2, steps - i - 1), t0 + i * 0.06 + 0.15, width * 0.7, depth + 1)
                end
            end
            theta, y, p0, n0 = th2, y2, p1, n1
        end
    end
    local step = size.Y * 0.075
    path(theta0, 0, step, 5, 0, w, 0) -- first fracture, grows up
    path(theta0, 0, -step, 4, 0.25, w * 0.9, 0) -- then down
    path(theta0 + 1.3, size.Y * 0.1, step, 4, 0.5, w * 0.8, 1)
    path(theta0 - 1.2, -size.Y * 0.05, -step, 4, 0.6, w * 0.8, 1)
    local folder = make("Model", { Name = "HatchCracks" }, egg) -- inside the egg so it rocks with it
    for _, s in segs do
        s.part =
            fxPart({ Size = Vector3.new(s.w, 0.02, s.len), CFrame = s.cf, Color = job.color, Transparency = 1 }, folder)
        job.skip[s.part] = true
    end
    job.cracks = segs
    job.crackFolder = folder
end

-- prepared crack stages: egg contains Folder "HatchCracks" with Decals/SurfaceGuis/parts named Crack1, Crack2, Crack3
local function preparedCracks(job)
    local f = job.egg:FindFirstChild("HatchCracks")
    if not (f and f:IsA("Folder")) then
        return false
    end
    job.stages = {}
    for i = 1, 3 do
        local s = f:FindFirstChild("Crack" .. i)
        if s then
            table.insert(job.stages, s)
            for _, d in s:GetDescendants() do
                if d:IsA("BasePart") then
                    job.skip[d] = true
                end
            end
        end
    end
    for _, s in job.stages do
        if s:IsA("Decal") then
            s.Transparency = 1
        elseif s:IsA("BasePart") then
            s.LocalTransparencyModifier = 1
        end
    end
    return #job.stages > 0
end

---------------------------------------------------------------- shards: split from the egg's real parts
local function quadrantClone(p, sx, sz)
    local q = p:Clone()
    for _, c in q:GetChildren() do
        if not (c:IsA("Texture") or c:IsA("SurfaceAppearance")) then
            c:Destroy()
        end
    end
    q.Size = Vector3.new(p.Size.X / 2, p.Size.Y, p.Size.Z / 2)
    q.CFrame = p.CFrame * CFrame.new(sx * p.Size.X / 4, 0, sz * p.Size.Z / 4)
    q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch = true, false, false, false
    q.LocalTransparencyModifier = 0
    return q
end
local function buildShards(job)
    local cf = job.eggCF
    local folder = make("Model", { Name = "HatchShards" }, workspace)
    job.shardFolder = folder
    local groups = {}
    local prepared = job.egg:FindFirstChild("HatchShell")
    local function add(key, part, dirLocal)
        groups[key] = groups[key] or { parts = {}, dir = dirLocal }
        part.Parent = folder
        table.insert(groups[key].parts, part)
    end
    if prepared then -- your pre-cut shell: Model "HatchShell" with child Models/Parts = one shard each
        for i, s in prepared:GetChildren() do
            local c = s:Clone()
            c.Parent = folder
            local pos = s:IsA("Model") and s:GetPivot().Position or s.Position
            local d = cf:PointToObjectSpace(pos)
            for _, p in (c:IsA("BasePart") and { c } or c:GetDescendants()) do
                if p:IsA("BasePart") then
                    p.Anchored, p.CanCollide = true, false
                    p.LocalTransparencyModifier = 0
                    add(i, p, d)
                end
            end
        end
    else
        for _, p in job.parts do
            local lp = cf:PointToObjectSpace(p.Position)
            local upper = lp.Y > -job.eggSize.Y * 0.1 and 1 or 0
            if p:IsA("Part") and p.Shape == Enum.PartType.Block then
                for _, sx in { -1, 1 } do
                    for _, sz in { -1, 1 } do
                        local q = quadrantClone(p, sx, sz)
                        local qd = cf:PointToObjectSpace(q.Position)
                        local key = (qd.X > 0 and 1 or 0) + (qd.Z > 0 and 2 or 0) + upper * 4
                        add(key, q, Vector3.new(qd.X > 0 and 1 or -1, upper, qd.Z > 0 and 1 or -1))
                    end
                end
            else
                local q = p:Clone()
                q.Anchored, q.CanCollide = true, false
                q.LocalTransparencyModifier = 0
                local key = (lp.X > 0 and 1 or 0) + (lp.Z > 0 and 2 or 0) + upper * 4
                add(key, q, Vector3.new(lp.X > 0 and 1 or -1, upper, lp.Z > 0 and 1 or -1))
            end
        end
    end
    job.shards = {}
    for _, g in groups do
        local d = g.dir
        local out = (cf.RightVector * d.X + cf.LookVector * d.Z)
        out = out.Magnitude > 0 and out.Unit or cf.RightVector
        local upper = (d.Y or 0) >= 1
        local cfs = {}
        for i, p in g.parts do
            cfs[i] = p.CFrame
        end
        table.insert(job.shards, {
            parts = g.parts,
            cfs = cfs,
            center = cf.Position,
            vel = out * (upper and Config.ShardTravel or Config.ShardTravel * 0.3) / Config.ShardLife
                + cf.UpVector * (upper and 2.2 or 0.3),
            spin = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-2, 2), rng:NextNumber(-3, 3))
                * (upper and 1 or 0.3),
        })
    end
end

---------------------------------------------------------------- per-hatch job
local function cleanup(job, keepLabel)
    if job.cleaned then
        return
    end
    job.cleaned = true
    for _, c in job.conns do
        c:Disconnect()
    end
    if job.hum then
        job.hum:Destroy()
    end
    if job.currentShake then
        job.currentShake:Destroy()
    end
    for _, o in job.made do
        if o.Parent then
            o:Destroy()
        end
    end
    if job.crackFolder then
        job.crackFolder:Destroy()
    end
    if job.shardFolder then
        job.shardFolder:Destroy()
    end
    -- restore machine glow
    for p, c in job.glow do
        if p.Parent then
            p.Color = c
        end
    end
    -- egg: back to its server pose (if it still exists, i.e. cancelled before the break)
    if job.egg and job.egg.Parent then
        pcall(function()
            job.egg:PivotTo(job.eggPivot)
        end)
        if not job.broken then
            setLTM(job.parts, 0)
        end
    end
    if job.stages then
        for _, s in job.stages do
            if s:IsA("Decal") then
                s.Transparency = 1
            end
        end
    end
    -- character: exact server transform, visible
    local ch = job.char
    if ch and ch.Parent then
        if job.charPivot then
            pcall(function()
                ch:PivotTo(job.charPivot)
            end)
        end
        setLTM(eggParts(ch), 0)
    end
    if job.label and not keepLabel then
        job.label:Destroy()
    end
    jobs[job.token] = nil
    if next(jobs) == nil and loop then
        loop:Disconnect()
        loop = nil
    end
end

local function showLabel(job)
    if Config.UseExistingCharacterInfo then
        return
    end
    local ch = job.char
    if not ch or job.label then
        return
    end
    local _, size = ch:GetBoundingBox()
    local adornee = ch.PrimaryPart or ch:FindFirstChildWhichIsA("BasePart", true)
    if not adornee then
        return
    end
    local g = make("BillboardGui", {
        Name = "HatchReveal",
        Adornee = adornee,
        Size = UDim2.fromScale(7, 3),
        StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.5 + 1.8, 0),
        AlwaysOnTop = true,
        LightInfluence = 0,
        MaxDistance = 90,
        ResetOnSpawn = false,
    }, player.PlayerGui)
    job.label = g
    make("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    }, g)
    local font = Font.new("rbxasset://fonts/families/FredokaOne.json")
    local rows = {
        { job.name, Color3.new(1, 1, 1), 0.34 },
        { string.upper(job.rarity), job.color, 0.2 },
        { "POWER " .. Config.Short(job.power), Color3.fromRGB(255, 211, 77), 0.25 },
        { "$" .. Config.Short(job.income) .. "/sec", Color3.fromRGB(125, 255, 90), 0.21 },
    }
    for i, r in rows do
        local l = make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, r[3]),
            FontFace = font,
            TextScaled = true,
            Text = r[1],
            TextColor3 = r[2],
            TextTransparency = 1,
            LayoutOrder = i,
        }, g)
        local st = make("UIStroke", { Color = Color3.fromRGB(29, 20, 32), Thickness = 2.5, Transparency = 1 }, l)
        task.delay(0.12 * (i - 1), function()
            if not l.Parent then
                return
            end
            TweenService:Create(l, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
            TweenService:Create(st, TweenInfo.new(0.22), { Transparency = 0 }):Play()
        end)
    end
    task.delay(job.T.End - job.T.Settle + Config.LabelHold, function()
        if not g.Parent then
            return
        end
        for _, l in g:GetChildren() do
            if l:IsA("TextLabel") then
                TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
                local s = l:FindFirstChildOfClass("UIStroke")
                if s then
                    TweenService:Create(s, TweenInfo.new(0.4), { Transparency = 1 }):Play()
                end
            end
        end
        task.delay(0.45, function()
            g:Destroy()
        end)
    end)
end

local function doBreak(job, t)
    job.broken = true
    local level, far = job.level, job.far
    setLTM(job.parts, 1)
    if job.crackFolder then
        job.crackFolder:Destroy()
        job.crackFolder = nil
    end
    if job.stages then
        for _, s in job.stages do
            if s:IsA("Decal") then
                s.Transparency = 1
            elseif s:IsA("BasePart") then
                s.LocalTransparencyModifier = 1
            end
        end
    end
    if job.hum then
        job.hum:Destroy()
        job.hum = nil
    end
    if far or t > job.T.Break + 0.3 then
        return
    end -- late or distant: skip spectacle, reveal still happens
    buildShards(job)
    sound(job, "Reveal")
    if job.mine then
        Shake.add(1.1, 0.35)
    end
    local n = Config.Burst[level]
    if reduced() then
        n = math.ceil(n / 2)
    end
    job.burst:Emit(n)
    if level >= 3 then
        job.stars:Emit(reduced() and 6 or 12)
    end
    job.light.Brightness = Config.Light[level]
    TweenService:Create(job.light, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Brightness = 0.6 }):Play()
    local function ring(color, delay)
        task.delay(delay, function()
            if job.cleaned then
                return
            end
            local r = fxPart({
                Shape = Enum.PartType.Cylinder,
                Size = Vector3.new(0.05, 0.4, 0.4),
                Color = color,
                Transparency = 0.15,
                CFrame = CFrame.new(job.eggCF.Position - job.eggCF.UpVector * job.eggSize.Y * 0.3)
                    * job.eggCF.Rotation
                    * CFrame.Angles(0, 0, math.pi / 2),
            }, workspace)
            table.insert(job.made, r)
            local d = math.min(Config.RingMax, job.eggSize.Y * 3)
            TweenService
                :Create(
                    r,
                    TweenInfo.new(0.35, Enum.EasingStyle.Quad),
                    { Size = Vector3.new(0.05, d, d), Transparency = 1 }
                )
                :Play()
        end)
    end
    ring(job.color, 0)
    if level >= 3 then
        ring(Config.JackpotAccent, 0.12)
    end
end

local function step(job, now)
    local t = now - job.start
    local T = job.T
    if t >= T.End + 0.2 then
        cleanup(job, true)
        return
    end
    local egg = job.egg
    local amp = reduced() and 0.5 or 1
    -- egg rocking around its bottom contact point
    if not job.broken and egg and egg.Parent then
        local rx, rz = 0, 0
        if t >= T.Twitch and t < T.Twitch + 0.18 then
            rz = math.sin((t - T.Twitch) / 0.18 * math.pi * 2) * math.rad(3)
            if not job.twitched then
                job.twitched = true
                sound(job, "Twitch")
            end
        elseif t >= T.Build and t < T.Crack then
            local k = (t - T.Build) / (T.Crack - T.Build)
            local local_t, gap, len, i = t - T.Build, 0.38, 0.2, 0
            while local_t > len + gap and i < 12 do
                local_t -= len + gap
                gap = math.max(0.06, gap * 0.72)
                i += 1
            end
            if local_t < len then
                local a = math.rad(4 + 5 * k) * math.sin(local_t / len * math.pi * 3) * (1 - local_t / len * 0.3)
                if i % 2 == 0 then
                    rz = a
                else
                    rx = a
                end
                if job.lastShake ~= i then
                    job.lastShake = i
                    if job.currentShake and job.currentShake.Parent then
                        job.currentShake:Destroy()
                    end
                    job.currentShake = sound(job, "Shake", { PlaybackSpeed = 0.95 + (i % 2) * 0.15 })
                    if job.mine then
                        Shake.add(0.12, 0.12)
                    end
                end
            end
        elseif t >= T.Crack and t < T.Tension then
            rz = math.rad(1.6) * math.sin(t * 47)
            rx = math.rad(1.1) * math.sin(t * 39)
        elseif t >= T.Tension and t < T.Break then
            local u = t - T.Tension
            if u < 0.24 then
                rz = math.rad(11) * math.sin(u / 0.12 * math.pi)
                if not job.tensed then
                    job.tensed = true
                    if job.mine then
                        Shake.add(0.5, 0.25)
                    end
                end
            end
            if job.hum then
                job.hum:Destroy()
                job.hum = nil
            end -- audio pause before the reveal
            if not job.pulled then
                job.pulled = true
                job.inward.Enabled = true
            end
        end
        local b = job.bottom
        egg:PivotTo(b * CFrame.Angles(rx * amp, 0, rz * amp) * b:Inverse() * job.eggPivot)
        if job.hum then
            job.hum.PlaybackSpeed = 0.9 + 0.3 * smooth(t / T.Tension)
        end
    end
    if t >= T.Break - 0.05 and job.inward.Enabled then
        job.inward.Enabled = false
    end
    -- machine glow + inner light build
    local glowK = smooth(t / 0.8) * (t < T.End - 0.5 and 1 or smooth((T.End - t) / 0.5))
    for p, c in job.glow do
        p.Color = c:Lerp(Color3.new(1, 1, 1), 0.35 * glowK)
    end
    if not job.broken then
        job.light.Brightness = 0.4 + 1.2 * smooth((t - T.Crack) / (T.Break - T.Crack))
    end
    -- cracks grow, leak light
    if job.cracks and t >= T.Crack and not job.broken then
        local ct = t - T.Crack
        local heat = smooth(ct / (T.Break - T.Crack))
        for _, s in job.cracks do
            if ct >= s.t then
                local a = smooth((ct - s.t) / 0.12)
                s.part.Transparency = 1 - a
                s.part.Color = job.color:Lerp(Color3.new(1, 1, 1), 0.2 + 0.5 * heat)
                if not s.snd then
                    s.snd = true
                    if (s.t * 10) % 3 < 1 then
                        sound(job, "Crack")
                    end
                end
            end
        end
    elseif job.stages and t >= T.Crack and not job.broken then
        local k = (t - T.Crack) / (T.Break - T.Crack)
        for i, s in job.stages do
            if k >= (i - 1) / #job.stages then
                if s:IsA("Decal") then
                    s.Transparency = 0
                elseif s:IsA("BasePart") then
                    s.LocalTransparencyModifier = 0
                end
            end
        end
    end
    -- break + reveal
    if not job.broken and t >= T.Break then
        doBreak(job, t)
    end
    if job.shards then
        local u = t - T.Break
        local k = math.clamp(u / Config.ShardLife, 0, 1)
        local parts, cfs = {}, {}
        for _, s in job.shards do
            local off = s.vel * u + Vector3.new(0, -9 * u * u, 0)
            local rot = CFrame.Angles(s.spin.X * u, s.spin.Y * u, s.spin.Z * u)
            for i, p in s.parts do
                local base = s.cfs[i]
                local rel = CFrame.new(s.center):ToObjectSpace(base)
                table.insert(parts, p)
                table.insert(cfs, CFrame.new(s.center + off) * rot * rel)
                p.LocalTransparencyModifier = smooth((k - 0.45) / 0.55)
            end
        end
        if #parts > 0 then
            workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
        end
        if k >= 1 then
            job.shardFolder:Destroy()
            job.shardFolder = nil
            job.shards = nil
        end
    end
    -- character: hidden until the break, then a small settle bounce
    local ch = job.char
    if ch and ch.Parent then
        if not job.charPivot then
            job.charPivot = ch:GetPivot()
        end
        if t < T.Break then
            setLTM(job.charParts, 1)
        else
            if not job.revealed then
                job.revealed = true
                setLTM(job.charParts, 0)
                showLabel(job)
                sound(job, "Settle")
            end
            local u = (t - T.Break) / (T.Settle - T.Break + 0.4)
            if u < 1 and not reduced() then
                local y = 0.28 * math.abs(math.sin(u * math.pi * 2)) * (1 - u) ^ 2
                ch:PivotTo(job.charPivot * CFrame.new(0, y, 0))
            elseif not job.settled then
                job.settled = true
                ch:PivotTo(job.charPivot)
            end
        end
    end
end

local function begin(inc)
    local token = inc:GetAttribute("HatchToken")
    if not token or token == "" or seen[token] then
        return
    end
    seen[token] = true
    local start = inc:GetAttribute("HatchStart") or workspace:GetServerTimeNow()
    local roll = inc:GetAttribute("HatchRoll")
    local T = Config.Timeline(roll, inc:GetAttribute("HatchRarity"))
    if workspace:GetServerTimeNow() - start > T.End then
        return
    end
    local ev = inc:WaitForChild("HatchEgg", 3)
    local egg = ev and ev.Value
    if not egg then
        local t0 = os.clock()
        repeat
            task.wait(0.1)
            egg = ev and ev.Value
        until egg or os.clock() - t0 > 2
    end
    if not egg or not egg.Parent then
        return
    end
    local rarity = inc:GetAttribute("HatchRarity") or "Common"
    local job = {
        token = token,
        inc = inc,
        egg = egg,
        start = start,
        T = T,
        level = Config.Level(roll),
        rarity = rarity,
        color = Config.RarityColor[rarity] or Config.RarityColor.Common,
        name = inc:GetAttribute("HatchName") or "",
        power = inc:GetAttribute("HatchPower") or 0,
        income = inc:GetAttribute("HatchIncome") or 0,
        mine = inc:GetAttribute("HatchOwner") == player.UserId,
        conns = {},
        made = {},
        glow = {},
        skip = {},
        charParts = {},
    }
    job.eggPivot = egg:GetPivot()
    job.eggCF, job.eggSize = egg:GetBoundingBox()
    job.bottom = job.eggCF * CFrame.new(0, -job.eggSize.Y / 2, 0)
    local cam = workspace.CurrentCamera
    job.far = cam and (cam.CFrame.Position - job.eggCF.Position).Magnitude > Config.EffectsDistance
    if not preparedCracks(job) and not job.far then
        buildCracks(job)
    end
    job.parts = eggParts(egg, job.skip)
    -- light + emitters at the egg centre
    local holder = fxPart(
        { Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(job.eggCF.Position) },
        workspace
    )
    table.insert(job.made, holder)
    job.att = make("Attachment", {}, holder)
    job.light = make(
        "PointLight",
        { Color = job.color, Brightness = 0, Range = math.max(8, job.eggSize.Y * 3), Shadows = false },
        job.att
    )
    job.burst = make("ParticleEmitter", {
        Texture = SPARK,
        Rate = 0,
        Color = ColorSequence.new(job.color, Color3.new(1, 1, 1)),
        LightEmission = 0.8,
        LightInfluence = 0,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
        Speed = NumberRange.new(4, 8),
        SpreadAngle = Vector2.new(180, 180),
        Lifetime = NumberRange.new(0.35, 0.6),
        Drag = 6,
    }, job.att)
    job.stars = make("ParticleEmitter", {
        Texture = SPARK,
        Rate = 0,
        Color = ColorSequence.new(Config.JackpotAccent),
        LightEmission = 1,
        LightInfluence = 0,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }),
        Speed = NumberRange.new(2, 4),
        SpreadAngle = Vector2.new(180, 180),
        Lifetime = NumberRange.new(0.6, 0.9),
        Drag = 3,
        RotSpeed = NumberRange.new(-90, 90),
    }, job.att)
    job.inward = make("ParticleEmitter", {
        Texture = SOFT,
        Rate = reduced() and 12 or 26,
        Enabled = false,
        Color = ColorSequence.new(job.color),
        LightEmission = 0.7,
        LightInfluence = 0,
        Shape = Enum.ParticleEmitterShape.Sphere,
        ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
        ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
        Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05) }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.3, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Speed = NumberRange.new(job.eggSize.Y * 2.2),
        Lifetime = NumberRange.new(0.32),
    }, job.att)
    holder.Size = Vector3.new(1, 1, 1) * job.eggSize.Y * 1.6 -- inward sphere radius follows the egg
    -- machine lights
    for _, d in inc:GetDescendants() do
        if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
            for _, n in Config.MachineGlowNames do
                if d.Name:find(n, 1, true) then
                    job.glow[d] = d.Color
                    break
                end
            end
        end
    end
    -- character arrives just before the break; hide it locally until then
    local cv = inc:FindFirstChild("HatchCharacter")
    local function setChar(ch)
        if not ch then
            return
        end
        job.char = ch
        job.charParts = eggParts(ch)
        job.charPivot = nil
        if workspace:GetServerTimeNow() - start < T.Break then
            setLTM(job.charParts, 1)
        end
        table.insert(
            job.conns,
            ch.DescendantAdded:Connect(function(d)
                if d:IsA("BasePart") then
                    table.insert(job.charParts, d)
                    if not job.revealed then
                        d.LocalTransparencyModifier = 1
                    end
                end
            end)
        )
    end
    if cv then
        setChar(cv.Value)
        table.insert(job.conns, cv.Changed:Connect(setChar))
    end
    -- cancellation / removal
    table.insert(
        job.conns,
        inc:GetAttributeChangedSignal("HatchToken"):Connect(function()
            if inc:GetAttribute("HatchToken") ~= token then
                cleanup(job)
            end
        end)
    )
    table.insert(
        job.conns,
        inc.AncestryChanged:Connect(function(_, p)
            if not p then
                cleanup(job)
            end
        end)
    )
    table.insert(
        job.conns,
        egg.AncestryChanged:Connect(function(_, p)
            if not p and not job.broken then
                cleanup(job, true)
            end
        end)
    )
    if not job.far then
        job.hum = sound(job, "Hum", { Looped = true, Volume = Config.Volume * 0.5, PlaybackSpeed = 0.9 })
    end
    jobs[token] = job
    if not loop then
        loop = RunService.RenderStepped:Connect(function()
            local now = workspace:GetServerTimeNow()
            for _, j in jobs do
                local ok, err = pcall(step, j, now)
                if not ok then
                    warn("[HatchFX] animation error, restoring:", err)
                    cleanup(j)
                end
            end
        end)
    end
end

function Client.Start()
    local function watch(inc)
        if watched[inc] then
            return
        end
        watched[inc] = true
        task.spawn(begin, inc)
        inc:GetAttributeChangedSignal("HatchToken"):Connect(function()
            task.spawn(begin, inc)
        end)
    end
    for _, inc in CollectionService:GetTagged(TAG) do
        watch(inc)
    end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
end

return Client
