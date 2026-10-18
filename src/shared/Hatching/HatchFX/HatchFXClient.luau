--[[ ReplicatedStorage.HatchFX.HatchFXClient  (ModuleScript, client)
Cosmetic hatch sequence. Started by HatchFXClientStart. Reads only what the server put on the incubator.
One shared RenderStepped loop drives every active hatch; each hatch keeps its own state (no shared conflicts).

Replicated contract (written by ServerScriptService.HatchFX.HatchFXServer on the incubator):
  tag "Hatching"; attributes HatchToken (set last, "" when done), HatchStart, HatchRoll, HatchRarity,
  HatchName, HatchPower, HatchIncome, HatchOwner; ObjectValues HatchEgg / HatchCharacter.
Timing comes from HatchFXConfig.Timeline(roll, rarity), the same table the server uses, so the
client-side break / reveal lines up with the server spawning the character.
Everything here is local-only: LocalTransparencyModifier, client-made parts and sounds; the egg and
character are restored to their server pose on cleanup.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent:WaitForChild("HatchFXConfig"))

local player = Players.LocalPlayer
local TAG = "Hatching"
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local Client = {}
local jobs, seenTokens = {}, {} -- jobs: [token] = job; seenTokens: tokens already started (never replayed)
local watchedIncubators = setmetatable({}, { __mode = "k" })
local renderConnection -- shared RenderStepped loop, connected while at least one job is active
local rng = Random.new()

---------------------------------------------------------------- helpers
local function isReducedMotion()
    return player:GetAttribute(Config.ReducedMotionAttribute) == true
end
local function make(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end
-- anchored, non-interactive neon part; parented last so all props apply before replication/render
local function fxPart(props, parent)
    local part = make("Part", {
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        CastShadow = false,
        Material = Enum.Material.Neon,
        TopSurface = Enum.SurfaceType.Smooth,
        BottomSurface = Enum.SurfaceType.Smooth,
    }, nil)
    for key, value in props do
        part[key] = value
    end
    part.Parent = parent
    return part
end
local function smooth(alpha)
    alpha = math.clamp(alpha, 0, 1)
    return alpha * alpha * (3 - 2 * alpha)
end
-- every BasePart under `model`, except those in the optional `skip` set
local function eggParts(model, skip)
    local found = {}
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") and not (skip and skip[descendant]) then
            table.insert(found, descendant)
        end
    end
    return found
end
local function setLTM(parts, value)
    for _, part in parts do
        if part.Parent then
            part.LocalTransparencyModifier = value
        end
    end
end

---------------------------------------------------------------- camera shake (owner only, additive, no drift)
local Shake = { list = {}, bound = false }
function Shake.add(amp, dur)
    if Config.CameraShake <= 0 or isReducedMotion() then
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
    -- unbinds itself once every shake has decayed
    RunService:BindToRenderStep("HatchShake", Enum.RenderPriority.Camera.Value + 1, function()
        local cam, now, offsetX, offsetY = workspace.CurrentCamera, os.clock(), 0, 0
        for i = #Shake.list, 1, -1 do
            local entry = Shake.list[i]
            local progress = (now - entry.t0) / entry.dur
            if progress >= 1 then
                table.remove(Shake.list, i)
            else
                local falloff = (1 - progress) ^ 2
                offsetX += math.noise(entry.seed, now * 24) * entry.amp * falloff
                offsetY += math.noise(entry.seed + 9, now * 24) * entry.amp * falloff
            end
        end
        -- a Scriptable camera belongs to a cinematic; never nudge it
        if cam and cam.CameraType ~= Enum.CameraType.Scriptable then
            cam.CFrame *= CFrame.new(offsetX * 0.05, offsetY * 0.05, 0)
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
-- Plays Config.Sounds[slot] on the job's attachment. Returns nil when muted / unset / no attachment.
-- One-shot sounds destroy themselves when they end; looped ones are owned by the caller.
local function sound(job, slot, props)
    local soundId = Config.Sounds[slot]
    if not soundId or soundId == "" or player:GetAttribute(Config.MuteAttribute) or not job.att then
        return nil
    end
    local volume = (Config.SlotVolumes and Config.SlotVolumes[slot]) or Config.Volume
    local snd = make("Sound", { SoundId = soundId, Volume = volume, RollOffMaxDistance = 80 }, job.att)
    local soundGroup = SoundService:FindFirstChild(Config.SoundGroupName)
    if soundGroup and soundGroup:IsA("SoundGroup") then
        snd.SoundGroup = soundGroup
    end
    if props then
        for key, value in props do
            snd[key] = value
        end
    end
    snd:Play()
    if not snd.Looped then
        snd.Ended:Once(function()
            snd:Destroy()
        end)
    end
    return snd
end

---------------------------------------------------------------- cracks: snapped to the egg's real surface
-- Raycasts from outside toward the egg's axis and only accepts hits on the egg's own parts,
-- so every crack segment lies on an actual face. Prepared assets (see README) take priority.
local function buildCracks(job)
    local egg, eggCF, size = job.egg, job.eggCF, job.eggSize
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { egg }
    local radius = math.max(size.X, size.Z)
    local axis = eggCF.Position
    -- surface point + normal at angle `theta` around the egg's up axis, `y` studs above its centre
    local function surfacePoint(theta, y)
        local dir = (eggCF.RightVector * math.cos(theta) + eggCF.LookVector * math.sin(theta))
        local origin = axis + eggCF.UpVector * y + dir * radius * 1.5
        local hit = workspace:Raycast(origin, -dir * radius * 1.6, params)
        return hit and hit.Position, hit and hit.Normal
    end
    local baseWidth = math.max(0.035, size.Y * Config.CrackWidth * 0.5)
    local cam = workspace.CurrentCamera
    local toCam = cam and (cam.CFrame.Position - axis) or eggCF.LookVector
    local theta0 = math.atan2(toCam:Dot(eggCF.LookVector), toCam:Dot(eggCF.RightVector)) -- start on the side the player sees
    local segments = {}
    -- random-walk a crack over the surface; may branch (up to depth 2). Segment `t` = reveal delay after T.Crack.
    local function growCrack(theta, y, dy, steps, t0, width, depth)
        local prevPoint, prevNormal = surfacePoint(theta, y)
        for i = 1, steps do
            local nextTheta, nextY = theta + rng:NextNumber(-0.22, 0.22), y + dy
            local point, normal = surfacePoint(nextTheta, nextY)
            -- skip gaps (missed rays) and jumps across the silhouette
            if prevPoint and point and (point - prevPoint).Magnitude < size.Y * 0.3 then
                local segmentNormal = (prevNormal + normal).Unit
                local mid = (prevPoint + point) / 2 + segmentNormal * 0.012
                table.insert(segments, {
                    cf = CFrame.lookAt(mid, (point + segmentNormal * 0.012), segmentNormal),
                    len = (point - prevPoint).Magnitude + baseWidth,
                    w = width,
                    t = t0 + i * 0.06,
                })
                if depth < 2 and rng:NextNumber() < 0.28 then
                    growCrack(
                        nextTheta,
                        nextY,
                        dy * 0.8,
                        math.max(2, steps - i - 1),
                        t0 + i * 0.06 + 0.15,
                        width * 0.7,
                        depth + 1
                    )
                end
            end
            theta, y, prevPoint, prevNormal = nextTheta, nextY, point, normal
        end
    end
    local stepHeight = size.Y * 0.075
    growCrack(theta0, 0, stepHeight, 5, 0, baseWidth, 0) -- first fracture, grows up
    growCrack(theta0, 0, -stepHeight, 4, 0.25, baseWidth * 0.9, 0) -- then down
    growCrack(theta0 + 1.3, size.Y * 0.1, stepHeight, 4, 0.5, baseWidth * 0.8, 1)
    growCrack(theta0 - 1.2, -size.Y * 0.05, -stepHeight, 4, 0.6, baseWidth * 0.8, 1)
    local folder = make("Model", { Name = "HatchCracks" }, egg) -- inside the egg so it rocks with it
    for _, segment in segments do
        segment.part = fxPart({
            Size = Vector3.new(segment.w, 0.02, segment.len),
            CFrame = segment.cf,
            Color = job.color,
            Transparency = 1,
        }, folder)
        job.skip[segment.part] = true
    end
    job.cracks = segments
    job.crackFolder = folder
end

-- prepared crack stages: egg contains Folder "HatchCracks" with Decals/SurfaceGuis/parts named Crack1, Crack2, Crack3
local function preparedCracks(job)
    local folder = job.egg:FindFirstChild("HatchCracks")
    if not (folder and folder:IsA("Folder")) then
        return false
    end
    job.stages = {}
    for i = 1, 3 do
        local stage = folder:FindFirstChild("Crack" .. i)
        if stage then
            table.insert(job.stages, stage)
            for _, descendant in stage:GetDescendants() do
                if descendant:IsA("BasePart") then
                    job.skip[descendant] = true
                end
            end
        end
    end
    for _, stage in job.stages do
        if stage:IsA("Decal") then
            stage.Transparency = 1
        elseif stage:IsA("BasePart") then
            stage.LocalTransparencyModifier = 1
        end
    end
    return #job.stages > 0
end

---------------------------------------------------------------- shards: split from the egg's real parts
-- one quarter (in X/Z) of a block part, keeping only its Textures / SurfaceAppearance
local function quadrantClone(part, signX, signZ)
    local quadrant = part:Clone()
    for _, child in quadrant:GetChildren() do
        if not (child:IsA("Texture") or child:IsA("SurfaceAppearance")) then
            child:Destroy()
        end
    end
    quadrant.Size = Vector3.new(part.Size.X / 2, part.Size.Y, part.Size.Z / 2)
    quadrant.CFrame = part.CFrame * CFrame.new(signX * part.Size.X / 4, 0, signZ * part.Size.Z / 4)
    quadrant.Anchored, quadrant.CanCollide, quadrant.CanQuery, quadrant.CanTouch = true, false, false, false
    quadrant.LocalTransparencyModifier = 0
    return quadrant
end
-- Groups clones of the egg into shards (by octant, or the pre-cut "HatchShell"), each with a start
-- velocity and spin. step() then moves them analytically from T.Break.
local function buildShards(job)
    local eggCF = job.eggCF
    local folder = make("Model", { Name = "HatchShards" }, workspace)
    job.shardFolder = folder
    local groups = {}
    local prepared = job.egg:FindFirstChild("HatchShell")
    local function addToGroup(key, part, dirLocal)
        groups[key] = groups[key] or { parts = {}, dir = dirLocal }
        part.Parent = folder
        table.insert(groups[key].parts, part)
    end
    if prepared then -- your pre-cut shell: Model "HatchShell" with child Models/Parts = one shard each
        for i, shellPiece in prepared:GetChildren() do
            local clone = shellPiece:Clone()
            clone.Parent = folder
            local pos = shellPiece:IsA("Model") and shellPiece:GetPivot().Position or shellPiece.Position
            local localOffset = eggCF:PointToObjectSpace(pos)
            for _, part in (clone:IsA("BasePart") and { clone } or clone:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Anchored, part.CanCollide = true, false
                    part.LocalTransparencyModifier = 0
                    addToGroup(i, part, localOffset)
                end
            end
        end
    else
        for _, part in job.parts do
            local localPos = eggCF:PointToObjectSpace(part.Position)
            local upper = localPos.Y > -job.eggSize.Y * 0.1 and 1 or 0
            -- key = octant: bit 1 = +X, bit 2 = +Z, bit 4 = upper half
            if part:IsA("Part") and part.Shape == Enum.PartType.Block then
                for _, signX in { -1, 1 } do
                    for _, signZ in { -1, 1 } do
                        local quadrant = quadrantClone(part, signX, signZ)
                        local quadrantLocal = eggCF:PointToObjectSpace(quadrant.Position)
                        local key = (quadrantLocal.X > 0 and 1 or 0) + (quadrantLocal.Z > 0 and 2 or 0) + upper * 4
                        addToGroup(
                            key,
                            quadrant,
                            Vector3.new(quadrantLocal.X > 0 and 1 or -1, upper, quadrantLocal.Z > 0 and 1 or -1)
                        )
                    end
                end
            else
                local clone = part:Clone()
                clone.Anchored, clone.CanCollide = true, false
                clone.LocalTransparencyModifier = 0
                local key = (localPos.X > 0 and 1 or 0) + (localPos.Z > 0 and 2 or 0) + upper * 4
                addToGroup(key, clone, Vector3.new(localPos.X > 0 and 1 or -1, upper, localPos.Z > 0 and 1 or -1))
            end
        end
    end
    job.shards = {}
    for _, group in groups do
        local dir = group.dir
        local outward = (eggCF.RightVector * dir.X + eggCF.LookVector * dir.Z)
        outward = outward.Magnitude > 0 and outward.Unit or eggCF.RightVector
        local upper = (dir.Y or 0) >= 1
        local startCFrames = {}
        for i, part in group.parts do
            startCFrames[i] = part.CFrame
        end
        table.insert(job.shards, {
            parts = group.parts,
            cfs = startCFrames,
            center = eggCF.Position,
            vel = outward * (upper and Config.ShardTravel or Config.ShardTravel * 0.3) / Config.ShardLife
                + eggCF.UpVector * (upper and 2.2 or 0.3),
            spin = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-2, 2), rng:NextNumber(-3, 3))
                * (upper and 1 or 0.3),
        })
    end
end

---------------------------------------------------------------- per-hatch job
-- Idempotent. Restores everything the job touched locally; keepLabel leaves the reveal billboard
-- to fade out on its own timer.
local function cleanup(job, keepLabel)
    if job.cleaned then
        return
    end
    job.cleaned = true
    for _, connection in job.conns do
        connection:Disconnect()
    end
    if job.hum then
        job.hum:Destroy()
    end
    if job.currentShake then
        job.currentShake:Destroy()
    end
    for _, instance in job.made do
        if instance.Parent then
            instance:Destroy()
        end
    end
    if job.crackFolder then
        job.crackFolder:Destroy()
    end
    if job.shardFolder then
        job.shardFolder:Destroy()
    end
    -- restore machine glow
    for part, color in job.glow do
        if part.Parent then
            part.Color = color
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
        for _, stage in job.stages do
            if stage:IsA("Decal") then
                stage.Transparency = 1
            end
        end
    end
    -- character: exact server transform, visible
    local character = job.char
    if character and character.Parent then
        if job.charPivot then
            pcall(function()
                character:PivotTo(job.charPivot)
            end)
        end
        setLTM(eggParts(character), 0)
    end
    if job.label and not keepLabel then
        job.label:Destroy()
    end
    jobs[job.token] = nil
    if next(jobs) == nil and renderConnection then
        renderConnection:Disconnect()
        renderConnection = nil
    end
end

-- Billboard over the revealed character: name / rarity / power / income rows fade in one by one,
-- then everything fades out LabelHold seconds after the job ends.
local function showLabel(job)
    if Config.UseExistingCharacterInfo then
        return
    end
    local character = job.char
    if not character or job.label then
        return
    end
    local _, size = character:GetBoundingBox()
    local adornee = character.PrimaryPart or character:FindFirstChildWhichIsA("BasePart", true)
    if not adornee then
        return
    end
    local billboard = make("BillboardGui", {
        Name = "HatchReveal",
        Adornee = adornee,
        Size = UDim2.fromScale(7, 3),
        StudsOffsetWorldSpace = Vector3.new(0, size.Y * 0.5 + 1.8, 0),
        AlwaysOnTop = true,
        LightInfluence = 0,
        MaxDistance = 90,
        ResetOnSpawn = false,
    }, player.PlayerGui)
    job.label = billboard
    make("UIListLayout", {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    }, billboard)
    local font = Font.new("rbxasset://fonts/families/FredokaOne.json")
    local rows = { -- { text, color, height scale }
        { job.name, Color3.new(1, 1, 1), 0.34 },
        { string.upper(job.rarity), job.color, 0.2 },
        { "POWER " .. Config.Short(job.power), Color3.fromRGB(255, 211, 77), 0.25 },
        { "$" .. Config.Short(job.income) .. "/sec", Color3.fromRGB(125, 255, 90), 0.21 },
    }
    for i, row in rows do
        local textLabel = make("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, row[3]),
            FontFace = font,
            TextScaled = true,
            Text = row[1],
            TextColor3 = row[2],
            TextTransparency = 1,
            LayoutOrder = i,
        }, billboard)
        local stroke =
            make("UIStroke", { Color = Color3.fromRGB(29, 20, 32), Thickness = 2.5, Transparency = 1 }, textLabel)
        task.delay(0.12 * (i - 1), function()
            if not textLabel.Parent then
                return
            end
            TweenService:Create(textLabel, TweenInfo.new(0.22), { TextTransparency = 0 }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.22), { Transparency = 0 }):Play()
        end)
    end
    task.delay(job.T.End - job.T.Settle + Config.LabelHold, function()
        if not billboard.Parent then
            return
        end
        for _, child in billboard:GetChildren() do
            if child:IsA("TextLabel") then
                TweenService:Create(child, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
                local stroke = child:FindFirstChildOfClass("UIStroke")
                if stroke then
                    TweenService:Create(stroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
                end
            end
        end
        task.delay(0.45, function()
            billboard:Destroy()
        end)
    end)
end

-- The egg breaks: hide it, drop crack visuals and the hum, then (only if near and on time)
-- spawn shards, burst particles, a light flash and shock rings.
local function doBreak(job, t)
    job.broken = true
    local level, far = job.level, job.far
    setLTM(job.parts, 1)
    if job.crackFolder then
        job.crackFolder:Destroy()
        job.crackFolder = nil
    end
    if job.stages then
        for _, stage in job.stages do
            if stage:IsA("Decal") then
                stage.Transparency = 1
            elseif stage:IsA("BasePart") then
                stage.LocalTransparencyModifier = 1
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
    local burstCount = Config.Burst[level]
    if isReducedMotion() then
        burstCount = math.ceil(burstCount / 2)
    end
    job.burst:Emit(burstCount)
    if level >= 3 then
        job.stars:Emit(isReducedMotion() and 6 or 12)
    end
    job.light.Brightness = Config.Light[level]
    TweenService:Create(job.light, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Brightness = 0.6 }):Play()
    -- flat expanding ring at the egg's lower third
    local function ring(color, delaySeconds)
        task.delay(delaySeconds, function()
            if job.cleaned then
                return
            end
            local ringPart = fxPart({
                Shape = Enum.PartType.Cylinder,
                Size = Vector3.new(0.05, 0.4, 0.4),
                Color = color,
                Transparency = 0.15,
                CFrame = CFrame.new(job.eggCF.Position - job.eggCF.UpVector * job.eggSize.Y * 0.3)
                    * job.eggCF.Rotation
                    * CFrame.Angles(0, 0, math.pi / 2),
            }, workspace)
            table.insert(job.made, ringPart)
            local diameter = math.min(Config.RingMax, job.eggSize.Y * 3)
            TweenService:Create(
                ringPart,
                TweenInfo.new(0.35, Enum.EasingStyle.Quad),
                { Size = Vector3.new(0.05, diameter, diameter), Transparency = 1 }
            ):Play()
        end)
    end
    ring(job.color, 0)
    if level >= 3 then
        ring(Config.JackpotAccent, 0.12)
    end
end

---------------------------------------------------------------- per-frame phases (called from step, in this order)
-- egg rocking around its bottom contact point (intact egg only); also plays the twitch / shake
-- sounds, cuts the hum before the break and turns on the inward particles
local function rockEgg(job, t, timeline, egg, amp)
    local rx, rz = 0, 0
    if t >= timeline.Twitch and t < timeline.Twitch + 0.18 then
        rz = math.sin((t - timeline.Twitch) / 0.18 * math.pi * 2) * math.rad(3)
        if not job.twitched then
            job.twitched = true
            sound(job, "Twitch")
        end
    elseif t >= timeline.Build and t < timeline.Crack then
        local k = (t - timeline.Build) / (timeline.Crack - timeline.Build)
        -- find which burst we are in: bursts of `len` s separated by gaps that shrink each time
        local burstTime, gap, len, i = t - timeline.Build, 0.38, 0.2, 0
        while burstTime > len + gap and i < 12 do
            burstTime -= len + gap
            gap = math.max(0.06, gap * 0.72)
            i += 1
        end
        if burstTime < len then
            local angle = math.rad(4 + 5 * k) * math.sin(burstTime / len * math.pi * 3) * (1 - burstTime / len * 0.3)
            if i % 2 == 0 then
                rz = angle
            else
                rx = angle
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
    elseif t >= timeline.Crack and t < timeline.Tension then
        rz = math.rad(1.6) * math.sin(t * 47)
        rx = math.rad(1.1) * math.sin(t * 39)
    elseif t >= timeline.Tension and t < timeline.Break then
        local tensionTime = t - timeline.Tension
        if tensionTime < 0.24 then
            rz = math.rad(11) * math.sin(tensionTime / 0.12 * math.pi)
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
    local bottom = job.bottom
    egg:PivotTo(bottom * CFrame.Angles(rx * amp, 0, rz * amp) * bottom:Inverse() * job.eggPivot)
    if job.hum then
        job.hum.PlaybackSpeed = 0.9 + 0.3 * smooth(t / timeline.Tension)
    end
end

-- cracks grow and leak light (generated segments), or prepared Crack1..3 stages appear in turn
local function updateCracks(job, t, timeline)
    if job.cracks and t >= timeline.Crack and not job.broken then
        local crackTime = t - timeline.Crack
        local heat = smooth(crackTime / (timeline.Break - timeline.Crack))
        for _, segment in job.cracks do
            if crackTime >= segment.t then
                local alpha = smooth((crackTime - segment.t) / 0.12)
                segment.part.Transparency = 1 - alpha
                segment.part.Color = job.color:Lerp(Color3.new(1, 1, 1), 0.2 + 0.5 * heat)
                if not segment.snd then
                    segment.snd = true
                    -- only about a third of the segments click, so the crack sound doesn't machine-gun
                    if (segment.t * 10) % 3 < 1 then
                        sound(job, "Crack")
                    end
                end
            end
        end
    elseif job.stages and t >= timeline.Crack and not job.broken then
        local k = (t - timeline.Crack) / (timeline.Break - timeline.Crack)
        for i, stage in job.stages do
            if k >= (i - 1) / #job.stages then
                if stage:IsA("Decal") then
                    stage.Transparency = 0
                elseif stage:IsA("BasePart") then
                    stage.LocalTransparencyModifier = 0
                end
            end
        end
    end
end

-- shards: closed-form flight (velocity + fake gravity + spin) from the break, fading out;
-- the shard folder is destroyed once they have fully faded
local function updateShards(job, t, timeline)
    local sinceBreak = t - timeline.Break
    local k = math.clamp(sinceBreak / Config.ShardLife, 0, 1)
    local parts, cfs = {}, {}
    for _, shard in job.shards do
        local offset = shard.vel * sinceBreak + Vector3.new(0, -9 * sinceBreak * sinceBreak, 0)
        local rot = CFrame.Angles(shard.spin.X * sinceBreak, shard.spin.Y * sinceBreak, shard.spin.Z * sinceBreak)
        for i, part in shard.parts do
            local base = shard.cfs[i]
            local rel = CFrame.new(shard.center):ToObjectSpace(base)
            table.insert(parts, part)
            table.insert(cfs, CFrame.new(shard.center + offset) * rot * rel)
            part.LocalTransparencyModifier = smooth((k - 0.45) / 0.55)
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

-- character: hidden until the break, then revealed (label + sound) with a small settle bounce
local function updateCharacter(job, t, timeline, character)
    if not job.charPivot then
        job.charPivot = character:GetPivot()
    end
    if t < timeline.Break then
        setLTM(job.charParts, 1)
    else
        if not job.revealed then
            job.revealed = true
            setLTM(job.charParts, 0)
            showLabel(job)
            sound(job, "Settle")
        end
        local settle = (t - timeline.Break) / (timeline.Settle - timeline.Break + 0.4)
        if settle < 1 and not isReducedMotion() then
            local bounceY = 0.28 * math.abs(math.sin(settle * math.pi * 2)) * (1 - settle) ^ 2
            character:PivotTo(job.charPivot * CFrame.new(0, bounceY, 0))
        elseif not job.settled then
            job.settled = true
            character:PivotTo(job.charPivot)
        end
    end
end

-- One frame of a job. `now` is server time, so every client shows the same phase of the timeline:
-- Twitch -> Build (shake bursts) -> Crack (cracks grow) -> Tension -> Break -> Settle -> End.
local function step(job, now)
    local t = now - job.start
    local timeline = job.T
    if t >= timeline.End + 0.2 then
        cleanup(job, true)
        return
    end
    local egg = job.egg
    local amp = isReducedMotion() and 0.5 or 1
    if not job.broken and egg and egg.Parent then
        rockEgg(job, t, timeline, egg, amp)
    end
    if t >= timeline.Break - 0.05 and job.inward.Enabled then
        job.inward.Enabled = false
    end
    -- machine glow + inner light build
    local glowK = smooth(t / 0.8) * (t < timeline.End - 0.5 and 1 or smooth((timeline.End - t) / 0.5))
    for part, color in job.glow do
        part.Color = color:Lerp(Color3.new(1, 1, 1), 0.35 * glowK)
    end
    if not job.broken then
        job.light.Brightness = 0.4 + 1.2 * smooth((t - timeline.Crack) / (timeline.Break - timeline.Crack))
    end
    updateCracks(job, t, timeline)
    -- break + reveal
    if not job.broken and t >= timeline.Break then
        doBreak(job, t)
    end
    if job.shards then
        updateShards(job, t, timeline)
    end
    local character = job.char
    if character and character.Parent then
        updateCharacter(job, t, timeline, character)
    end
end

-- light, sparkle burst, jackpot stars and inward-pull emitters on an invisible holder at the egg centre
local function createEggEffects(job)
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
        Texture = SPARKLE_TEXTURE,
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
        Texture = SPARKLE_TEXTURE,
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
        Texture = SMOKE_TEXTURE,
        Rate = isReducedMotion() and 12 or 26,
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
end

-- remember the incubator's neon glow parts (by Config.MachineGlowNames) and their original colours
local function collectMachineGlow(job, incubator)
    for _, descendant in incubator:GetDescendants() do
        if descendant:IsA("BasePart") and descendant.Material == Enum.Material.Neon then
            for _, glowName in Config.MachineGlowNames do
                if descendant.Name:find(glowName, 1, true) then
                    job.glow[descendant] = descendant.Color
                    break
                end
            end
        end
    end
end

-- Starts the job for the incubator's current HatchToken (no-op if already seen, missing, or the
-- hatch is already over). Yields: waits up to 3 s for HatchEgg, then up to 2 s for its Value.
local function begin(incubator)
    local token = incubator:GetAttribute("HatchToken")
    if not token or token == "" or seenTokens[token] then
        return
    end
    seenTokens[token] = true
    local start = incubator:GetAttribute("HatchStart") or workspace:GetServerTimeNow()
    local roll = incubator:GetAttribute("HatchRoll")
    local timeline = Config.Timeline(roll, incubator:GetAttribute("HatchRarity"))
    if workspace:GetServerTimeNow() - start > timeline.End then
        return
    end
    local eggValue = incubator:WaitForChild("HatchEgg", 3)
    local egg = eggValue and eggValue.Value
    if not egg then
        local waitStart = os.clock()
        repeat
            task.wait(0.1)
            egg = eggValue and eggValue.Value
        until egg or os.clock() - waitStart > 2
    end
    if not egg or not egg.Parent then
        return
    end
    local rarity = incubator:GetAttribute("HatchRarity") or "Common"
    local job = {
        token = token,
        inc = incubator,
        egg = egg,
        start = start,
        T = timeline,
        level = Config.Level(roll),
        rarity = rarity,
        color = Config.RarityColor[rarity] or Config.RarityColor.Common,
        name = incubator:GetAttribute("HatchName") or "",
        power = incubator:GetAttribute("HatchPower") or 0,
        income = incubator:GetAttribute("HatchIncome") or 0,
        mine = incubator:GetAttribute("HatchOwner") == player.UserId,
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
    createEggEffects(job)
    -- machine lights
    collectMachineGlow(job, incubator)
    -- character arrives just before the break; hide it locally until then
    local characterValue = incubator:FindFirstChild("HatchCharacter")
    local function setCharacter(character)
        if not character then
            return
        end
        job.char = character
        job.charParts = eggParts(character)
        job.charPivot = nil
        if workspace:GetServerTimeNow() - start < timeline.Break then
            setLTM(job.charParts, 1)
        end
        table.insert(
            job.conns,
            character.DescendantAdded:Connect(function(descendant)
                if descendant:IsA("BasePart") then
                    table.insert(job.charParts, descendant)
                    if not job.revealed then
                        descendant.LocalTransparencyModifier = 1
                    end
                end
            end)
        )
    end
    if characterValue then
        setCharacter(characterValue.Value)
        table.insert(job.conns, characterValue.Changed:Connect(setCharacter))
    end
    -- cancellation / removal
    table.insert(
        job.conns,
        incubator:GetAttributeChangedSignal("HatchToken"):Connect(function()
            if incubator:GetAttribute("HatchToken") ~= token then
                cleanup(job)
            end
        end)
    )
    table.insert(
        job.conns,
        incubator.AncestryChanged:Connect(function(_, parent)
            if not parent then
                cleanup(job)
            end
        end)
    )
    table.insert(
        job.conns,
        egg.AncestryChanged:Connect(function(_, parent)
            if not parent and not job.broken then
                cleanup(job, true)
            end
        end)
    )
    if not job.far then
        job.hum = sound(job, "Hum", { Looped = true, Volume = Config.Volume * 0.5, PlaybackSpeed = 0.9 })
    end
    jobs[token] = job
    if not renderConnection then
        renderConnection = RunService.RenderStepped:Connect(function()
            local now = workspace:GetServerTimeNow()
            for _, activeJob in jobs do
                -- a failing job is restored and dropped instead of breaking the shared loop
                local ok, err = pcall(step, activeJob, now)
                if not ok then
                    warn("[HatchFX] animation error, restoring:", err)
                    cleanup(activeJob)
                end
            end
        end)
    end
end

-- Watches every "Hatching"-tagged incubator; each new HatchToken starts a job (in its own thread,
-- since begin yields).
function Client.Start()
    local function watch(incubator)
        if watchedIncubators[incubator] then
            return
        end
        watchedIncubators[incubator] = true
        task.spawn(begin, incubator)
        incubator:GetAttributeChangedSignal("HatchToken"):Connect(function()
            task.spawn(begin, incubator)
        end)
    end
    for _, incubator in CollectionService:GetTagged(TAG) do
        watch(incubator)
    end
    CollectionService:GetInstanceAddedSignal(TAG):Connect(watch)
end

return Client
