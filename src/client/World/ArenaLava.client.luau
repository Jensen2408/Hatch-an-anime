--!native
--!optimize 2
-- StarterPlayerScripts.ArenaLava (client only): the molten lava sea at the bottom of the Arena Brawl volcano. Same
-- technology as the river water (RiverWater.client / MIC SIDEWAYS! ocean): EditableMesh chunks whose vertices ride a
-- sum of travelling waves every frame, with textures sliding across them. Tuned for heat instead of water:
--   base layer   opaque molten rock (LavaBaseAppearance): orange liquid, dark crust floes, a strong emissive mask so it
--                glows, slow flow
--   flow layer   a copy 0.4 studs above it with translucent white-hot veins (LavaFlowAppearance) that cross the base
--                flow at an angle, so the surface seems to churn
--   crest layer  a third copy 0.2 studs up (LavaCrestAppearance) whose UVs ARE the phases of waves 1 and 2, so a bright
--                emissive band sits on every crest of the two biggest trains and travels with them (checked: mean
--                height under the bands +3.1 and +2.8 studs, under the troughs -1.9)
--   eruption ring rings of glowing stud cubes (studded plastic, snapped to the whole-stud grid, so it reads as pixels) ride the
--                real lava height as the ring wave runs outward (20 studs/s, gone after 2.2 s, about 44 studs)
--   waves        five slow, steep, peaked trains (the longest is 96 studs) that swell and ease in sets
--   eruptions    every few seconds lava swells into a bubble, bursts into a plume and a spray of glowing voxel cubes,
--                the cubes fall back with a splash and a ring wave runs across the lava. All of it comes from the
--                server clock, so every player sees the same eruption at the same moment.
-- Nothing here is networked and the lava only exists on a client while that player is inside the volcano zone (and
-- the zone model exists), so the map never sees it. Engine notes from the river apply: one changed vertex reprocesses
-- the whole mesh, so the surface is cut into chunks and far chunks update less often; new MeshParts take their centre
-- from the mesh bounds so each chunk is built flat around its own centre; SurfaceAppearance maps can't be set by
-- scripts, so the two appearances live in ReplicatedStorage.ArenaEvent.LavaTemplates (built in Studio).
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local arenaAssets = ReplicatedStorage:WaitForChild("ArenaEvent")
local Config = require(arenaAssets:WaitForChild("ArenaConfig"))
local templates = arenaAssets:WaitForChild("LavaTemplates")
local player = Players.LocalPlayer

local TAU = math.pi * 2
local CENTER = Config.Center
local LAVA_Y = CENTER.Y - Config.LavaDepth
local RADIUS = Config.LavaRadius -- the sea reaches under the colosseum walls
local CELL = 6 -- studs between vertices (the shortest wave is 22 studs long, so 3.7 cells: no aliasing)
local CHUNK_CELLS = 10 -- cells per chunk edge (60 studs)
local SURFACE_HEIGHT_SCALE = 0.10 -- keep travelling waves and eruption swells below the arena deck
local FLOW_LIFT = 0.4
local FLOW_TRANSPARENCY = 0.7
local CREST_NEAR = 85 -- the crest bands only on chunks this close to the camera (the flow layer reaches NEAR)
local CREST_LIFT = 0.2
local CREST_TRANSPARENCY = 0.3
local NEAR = 110 -- chunks closer than this to the camera (centre to centre) update every 3 frames, with the flow layer
local MID = 220 -- closer than this: every 6 frames without the flow layer; beyond: every 10
local BEHIND = 60 -- a chunk this far behind the camera plane is not updated
local BASE_TILE = 64 -- studs per tile of the base maps (one pixel cell = 1 stud)
local FLOW_TILE = 48
local BASE_SPEED = Vector2.new(2.2, 1.1) -- studs per second the base texture slides
local FLOW_SPEED = Vector2.new(3.2, -1.3)
local FLOW_ANGLE = math.rad(37)
local ZONE_REACH = RADIUS + 450 -- the player is this close (flat) to the centre: build the lava
local BUILD_PER_STEP = 3

-- Waves -----------------------------------------------------------------------------------------------------------
-- angle (deg), wavelength (studs), height (studs), pace. Steep and slow: lava is heavy.
local waveSpecs = {
    { angle = 8, length = 96, height = 3.0, phase = 0.4 },
    { angle = 64, length = 64, height = 2.0, phase = 2.2 },
    { angle = -47, length = 46, height = 1.2, phase = 4.1 },
    { angle = 118, length = 31, height = 0.7, phase = 1.3 },
    { angle = -103, length = 22, height = 0.4, phase = 5.2 },
}
local GRAVITY = 6 -- stylised: heavy, slow
local waves = {}
for index, spec in waveSpecs do
    local a = math.rad(spec.angle)
    local k = TAU / spec.length
    waves[index] = {
        dx = math.cos(a),
        dz = math.sin(a),
        k = k,
        w = math.sqrt(GRAVITY * k),
        a = spec.height * SURFACE_HEIGHT_SCALE,
        p = spec.phase,
        set = 0.11 + index * 0.017, -- how fast this train swells and eases
    }
end
local WAVE_COUNT = #waves
local PEAK = 2.2 -- crest sharpening: height = a * (PEAK * s^2 - 0.8), s = (sin + 1) / 2

-- Eruptions: slot n starts at n * SLOT (the bubble swells), bursts at n * SLOT + LEAD, and rings out afterwards.
local SLOT = 3.6
local LEAD = 2.0
local RING_SECONDS = 2.2 -- the ripple dies out after this long (it used to run 4.5 s and reach ~115 studs)
local RING_SPEED = 20 -- studs per second the ring front runs outward (reaches about 44 studs)
local RING_DECAY = 0.9 -- the ring wave's height fades as exp(-RING_DECAY * t)
local function hash(n)
    local v = math.sin(n * 127.1 + 311.7) * 43758.5453
    return v - math.floor(v)
end
local function eruption(n)
    local angle = hash(n) * TAU
    local radius = 78 + hash(n + 0.37) * 62
    return {
        n = n,
        burst = n * SLOT + LEAD,
        x = CENTER.X + math.cos(angle) * radius,
        z = CENTER.Z + math.sin(angle) * radius,
        seed = hash(n + 0.71),
    }
end

local active = {} -- eruptions currently affecting the surface this frame
local function collectEruptions(serverTime)
    table.clear(active)
    local current = math.floor(serverTime / SLOT)
    for n = current - 1, current do
        local ev = eruption(n)
        local t = serverTime - ev.burst
        if t > -LEAD and t < RING_SECONDS then
            ev.t = t
            table.insert(active, ev)
        end
    end
end

-- Height added by the active eruptions at a point.
local function eruptionHeight(x, z)
    local total = 0
    for _, ev in active do
        local dx, dz = x - ev.x, z - ev.z
        local d2 = dx * dx + dz * dz
        local t = ev.t
        if t < 0 then
            local u = (t + LEAD) / LEAD
            total += 5.5 * u * u * math.exp(-d2 / 90)
        else
            local d = math.sqrt(d2)
            local front = d - RING_SPEED * t
            total += 5.5 * math.exp(-6 * t) * math.exp(-d2 / 90)
                + 3.2 * math.sin(0.5 * front) * math.exp(-(front * front) / 196) * math.exp(-RING_DECAY * t)
        end
    end
    return total * SURFACE_HEIGHT_SCALE
end

-- Mesh chunks -----------------------------------------------------------------------------------------------------
local folder = nil
local chunks = {}
local building = false
local built = false

local function newMeshPart(mesh, centre, name)
    local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), { CollisionFidelity = Enum.CollisionFidelity.Box })
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.DoubleSided = true
    part.Material = Enum.Material.SmoothPlastic
    part.Color = Color3.new(1, 1, 1)
    part.CFrame = CFrame.new(centre)
    return part
end

local function buildChunk(cx, cz, index)
    local em = AssetService:CreateEditableMesh()
    assert(em, "Lava mesh memory unavailable")
    local half = CHUNK_CELLS * CELL / 2
    local verts = {}
    local ids = {}
    for row = 0, CHUNK_CELLS do
        for column = 0, CHUNK_CELLS do
            local lx, lz = -half + column * CELL, -half + row * CELL
            local vert = { lx = lx, lz = lz, wx = cx + lx, wz = cz + lz, key = tostring(Vector3.new(lx, 0, lz)) }
            ids[vert] = { em:AddVertex(Vector3.new(lx, 0, lz)), em:AddNormal(Vector3.yAxis), em:AddUV(Vector2.zero) }
            table.insert(verts, vert)
            -- spatial half of every wave phase: only the time term is added per frame
            vert.ph = table.create(WAVE_COUNT)
            for i, w in waves do
                vert.ph[i] = w.k * (w.dx * vert.wx + w.dz * vert.wz) + w.p
            end
        end
    end
    local width = CHUNK_CELLS + 1
    local function at(row, column)
        return ids[verts[row * width + column + 1]]
    end
    local function face(a, b, c)
        local f = em:AddTriangle(a[1], b[1], c[1])
        em:SetFaceNormals(f, { a[2], b[2], c[2] })
        em:SetFaceUVs(f, { a[3], b[3], c[3] })
    end
    for row = 0, CHUNK_CELLS - 1 do
        for column = 0, CHUNK_CELLS - 1 do
            local a, b, c, d = at(row, column), at(row, column + 1), at(row + 1, column), at(row + 1, column + 1)
            face(a, d, b)
            face(a, c, d)
        end
    end
    local function fixedCopy()
        local copy = AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
        assert(copy, "Lava mesh memory unavailable")
        local byPosition = {}
        for _, id in copy:GetVertices() do
            byPosition[tostring(copy:GetPosition(id))] = id
        end
        return copy, byPosition
    end
    local base, baseIds = fixedCopy()
    local flow, flowIds = fixedCopy()
    local crest, crestIds = fixedCopy()
    em:Destroy()
    for _, vert in verts do
        local id, fid = baseIds[vert.key], flowIds[vert.key]
        vert.id, vert.nid, vert.uv = id, base:GetVertexNormals(id)[1], base:GetVertexUVs(id)[1]
        vert.fid, vert.fnid, vert.fuv = fid, flow:GetVertexNormals(fid)[1], flow:GetVertexUVs(fid)[1]
        local cid = crestIds[vert.key]
        vert.cid, vert.cnid, vert.cuv = cid, crest:GetVertexNormals(cid)[1], crest:GetVertexUVs(cid)[1]
    end
    local centre = Vector3.new(cx, LAVA_Y, cz)
    local basePart = newMeshPart(base, centre, "Lava" .. index)
    basePart.Color = Color3.fromRGB(205, 150, 130) -- a touch dark: the surface lights up from its emissive map, not from the lamps
    templates.LavaBaseAppearance:Clone().Parent = basePart
    local flowPart = newMeshPart(flow, centre + Vector3.new(0, FLOW_LIFT, 0), "LavaFlow" .. index)
    flowPart.Transparency = 1 -- shown only on chunks near the camera (see the frame loop)
    templates.LavaFlowAppearance:Clone().Parent = flowPart
    local crestPart = newMeshPart(crest, centre + Vector3.new(0, CREST_LIFT, 0), "LavaCrest" .. index)
    crestPart.Transparency = 1
    templates.LavaCrestAppearance:Clone().Parent = crestPart
    basePart.Parent = folder
    crestPart.Parent = folder
    flowPart.Parent = folder
    return {
        base = base,
        flow = flow,
        crest = crest,
        verts = verts,
        cx = cx,
        cz = cz,
        flowPart = flowPart,
        crestPart = crestPart,
        -- spatial phase of waves 1 and 2 at the chunk centre (their crests are what the crest texture marks)
        spatial1 = waves[1].k * (waves[1].dx * cx + waves[1].dz * cz) + waves[1].p,
        spatial2 = waves[2].k * (waves[2].dx * cx + waves[2].dz * cz) + waves[2].p,
        flowOn = false,
        crestOn = false,
        frame = index,
    }
end

local flowCos, flowSin = math.cos(FLOW_ANGLE), math.sin(FLOW_ANGLE)
local function updateChunk(chunk, t, withFlow, withCrest)
    local base, flow, crest = chunk.base, chunk.flow, chunk.crest
    local w1, w2 = waves[1], waves[2]
    -- the crest texture's U and V are the phases of waves 1 and 2 themselves, measured from this chunk's centre: bands
    -- sit on the crests and travel with them. Wrapped per chunk (never per vertex), so no seam inside a chunk.
    local centre1 = (chunk.spatial1 - w1.w * t) % TAU
    local centre2 = (chunk.spatial2 - w2.w * t) % TAU
    -- how big each train is right now: slow sets swell and ease
    local amplitude = table.create(WAVE_COUNT)
    local timePhase = table.create(WAVE_COUNT)
    for i, w in waves do
        amplitude[i] = w.a * (0.8 + 0.2 * math.sin(t * w.set + i * 2.1))
        timePhase[i] = -w.w * t
    end
    -- t is the server clock (about 1.8 billion), far beyond what a UV can hold: wrap the slide by whole tiles, and
    -- measure positions from the arena centre so the numbers stay small
    local baseU, baseV = (BASE_SPEED.X * t) % BASE_TILE, (BASE_SPEED.Y * t) % BASE_TILE
    local flowU, flowV = (FLOW_SPEED.X * t) % FLOW_TILE, (FLOW_SPEED.Y * t) % FLOW_TILE
    for _, v in chunk.verts do
        local y, dydx, dydz = 0, 0, 0
        local phases = v.ph
        for i = 1, WAVE_COUNT do
            local w = waves[i]
            local phase = phases[i] + timePhase[i]
            local s = math.sin(phase) * 0.5 + 0.5
            local a = amplitude[i]
            y += a * (PEAK * s * s - 0.8)
            local slope = PEAK * a * s * math.cos(phase) * w.k * 2
            dydx += slope * w.dx
            dydz += slope * w.dz
        end
        y += eruptionHeight(v.wx, v.wz)
        local normal = Vector3.new(-dydx, 1, -dydz).Unit
        local position = Vector3.new(v.lx, y, v.lz)
        base:SetPosition(v.id, position)
        base:SetNormal(v.nid, normal)
        local rx, rz = v.wx - CENTER.X, v.wz - CENTER.Z
        base:SetUV(v.uv, Vector2.new((rx - baseU) / BASE_TILE, (rz - baseV) / BASE_TILE))
        if withFlow then
            flow:SetPosition(v.fid, position)
            flow:SetNormal(v.fnid, normal)
            local ru = rx * flowCos + rz * flowSin
            local rv = -rx * flowSin + rz * flowCos
            flow:SetUV(v.fuv, Vector2.new((ru - flowU) / FLOW_TILE, (rv - flowV) / FLOW_TILE))
        end
        if withCrest then
            crest:SetPosition(v.cid, position)
            crest:SetNormal(v.cnid, normal)
            crest:SetUV(
                v.cuv,
                Vector2.new(
                    (centre1 + w1.k * (w1.dx * v.lx + w1.dz * v.lz)) / TAU,
                    (centre2 + w2.k * (w2.dx * v.lx + w2.dz * v.lz)) / TAU
                )
            )
        end
    end
end

-- The ripple when lava bursts: rings of glowing stud cubes snapped to the whole-stud grid, so it reads as pixels
local ringCubes = {} -- pooled Neon cubes
local ringActive = {} -- eruption number -> { x, z, burst }
local ringShown = 0 -- cubes used last update
local ringFrame = 0
local soundAnchor = nil -- invisible part on the lava surface carrying the ambient bubbling / fire loops

local function destroyLava()
    built = false
    soundAnchor = nil
    table.clear(chunks)
    table.clear(ringCubes)
    table.clear(ringActive)
    if folder then
        folder:Destroy()
        folder = nil
    end
end

local function createLavaLoop(parent, name, soundId, volume, speed)
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.SoundId = soundId
    sound.Volume = volume
    sound.PlaybackSpeed = speed or 1
    sound.Looped = true
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = 35
    sound.RollOffMaxDistance = 320
    sound.Parent = parent
    sound:Play()
    return sound
end

local function buildLava()
    if building or built then
        return
    end
    building = true
    folder = Instance.new("Folder")
    folder.Name = "ArenaLavaSurface"
    folder.Parent = workspace
    local mine = folder
    local anchor = Instance.new("Part")
    anchor.Name = "LavaSoundAnchor"
    anchor.Anchored = true
    anchor.CanCollide = false
    anchor.CanQuery = false
    anchor.CanTouch = false
    anchor.Transparency = 1
    anchor.Size = Vector3.one
    anchor.Position = Vector3.new(CENTER.X, LAVA_Y + 4, CENTER.Z)
    anchor.Parent = folder
    createLavaLoop(anchor, "LavaBubbleLoop", "rbxassetid://9112823197", 0.55, 0.95)
    createLavaLoop(anchor, "LavaFireLoop", "rbxassetid://9112822944", 0.45, 1.0)
    soundAnchor = anchor
    local half = CHUNK_CELLS * CELL
    local count = math.ceil(RADIUS * 2 / half)
    local start = -count * half / 2 + half / 2
    local index = 0
    local made = 0
    for i = 0, count - 1 do
        for j = 0, count - 1 do
            local cx = CENTER.X + start + i * half
            local cz = CENTER.Z + start + j * half
            -- a chunk is wanted when any part of it is inside the sea's radius
            local nearestX = math.max(math.abs(cx - CENTER.X) - half / 2, 0)
            local nearestZ = math.max(math.abs(cz - CENTER.Z) - half / 2, 0)
            if math.sqrt(nearestX * nearestX + nearestZ * nearestZ) < RADIUS then
                if folder ~= mine then
                    building = false
                    return -- the player left while it was building
                end
                index += 1
                local ok, chunk = pcall(buildChunk, cx, cz, index)
                if ok then
                    updateChunk(chunk, workspace:GetServerTimeNow(), true, true)
                    table.insert(chunks, chunk)
                else
                    warn("[ArenaLava] chunk failed:", chunk)
                end
                made += 1
                if made % BUILD_PER_STEP == 0 then
                    RunService.Heartbeat:Wait()
                end
            end
        end
    end
    building = false
    built = folder == mine
end

-- Eruption visuals (client only, one burst per slot, from the server clock) -------------------------------------------
local BIT_GRAVITY = 110
local bits = {}
local fired = {}
local surfaceHeightAt = function(x, z, t)
    local y = 0
    for i, w in waves do
        local phase = w.k * (w.dx * x + w.dz * z) + w.p - w.w * t
        local s = math.sin(phase) * 0.5 + 0.5
        y += w.a * (0.8 + 0.2 * math.sin(t * w.set + i * 2.1)) * (PEAK * s * s - 0.8)
    end
    return LAVA_Y + y
end

local RING_LEVELS = {
    { behind = 0, color = Color3.fromRGB(255, 240, 170) }, -- the front: white-hot
    { behind = 1.3, color = Color3.fromRGB(255, 190, 100) }, -- the wake behind it
}
local RING_FADE_FROM = 1.0 -- seconds after the burst when the cubes begin to fade
local RING_LIFT = 1.0 -- above the lava, clear of chunks that update a few frames late
local function ringCube(index)
    local cube = ringCubes[index]
    if not cube then
        cube = Instance.new("Part")
        cube.Anchored = true
        cube.CanCollide = false
        cube.CanTouch = false
        cube.CanQuery = false
        cube.CastShadow = false
        -- the game's own HD stud plastic, so every ripple pixel is a real stud brick; bright colours carry the glow
        cube.Material = Enum.Material.Plastic
        cube.MaterialVariant = "Incubator One Stud Cavity"
        cube.Size = Vector3.new(1, 1, 1)
        cube.TopSurface = Enum.SurfaceType.Smooth
        cube.BottomSurface = Enum.SurfaceType.Smooth
        cube.Parent = folder
        ringCubes[index] = cube
    end
    return cube
end

local function stepRingCubes(serverTime)
    ringFrame += 1
    if ringFrame % 2 ~= 0 then
        return -- the ring moves 20 studs/s: every second frame, snapped to whole studs, hops like pixels
    end
    local used = 0
    for n, ring in ringActive do
        local t = serverTime - ring.burst
        if t > RING_SECONDS then
            ringActive[n] = nil
        else
            local fade = math.clamp((t - RING_FADE_FROM) / (RING_SECONDS - RING_FADE_FROM), 0, 1)
            local transparency = fade * fade
            for _, level in RING_LEVELS do
                local radius = RING_SPEED * t - level.behind
                if radius > 1 then
                    local count = math.max(8, math.floor(TAU * radius / 1.1))
                    for i = 0, count - 1 do
                        local angle = i / count * TAU
                        -- whole-stud cells: the cube centre sits on a half stud, like the ground's tiles
                        local x = math.floor(ring.x + math.cos(angle) * radius) + 0.5
                        local z = math.floor(ring.z + math.sin(angle) * radius) + 0.5
                        local y = surfaceHeightAt(x, z, serverTime) + eruptionHeight(x, z) + RING_LIFT
                        used += 1
                        local cube = ringCube(used)
                        cube.CFrame = CFrame.new(x, y, z)
                        cube.Color = level.color
                        cube.Transparency = transparency
                    end
                end
            end
        end
    end
    for i = used + 1, ringShown do
        local cube = ringCubes[i]
        if cube then
            cube.Transparency = 1
        end
    end
    ringShown = used
end

local function neonPart(size, color, parent)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Material = Enum.Material.Neon
    part.Color = color
    part.Size = size
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = parent
    return part
end

local lastSplashSound = 0
local function splash(position)
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.Transparency = 1
    part.Size = Vector3.new(1, 1, 1)
    part.Position = position
    part.Parent = folder
    local emitter = Instance.new("ParticleEmitter")
    emitter.Lifetime = NumberRange.new(0.5, 1)
    emitter.Speed = NumberRange.new(8, 22)
    emitter.SpreadAngle = Vector2.new(60, 60)
    emitter.EmissionDirection = Enum.NormalId.Top
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
    emitter.Color = ColorSequence.new(Color3.fromRGB(255, 200, 70), Color3.fromRGB(255, 70, 10))
    emitter.LightEmission = 1
    emitter.Acceleration = Vector3.new(0, -60, 0)
    emitter.Rate = 0
    emitter.Parent = part
    emitter:Emit(10)
    local now = os.clock()
    if now - lastSplashSound >= 0.09 then
        lastSplashSound = now
        local sound = Instance.new("Sound")
        sound.Name = "LavaSplashSfx"
        sound.SoundId = "rbxassetid://9125409816"
        sound.Volume = 0.35
        sound.PlaybackSpeed = 0.72 + math.random() * 0.28
        sound.RollOffMode = Enum.RollOffMode.InverseTapered
        sound.RollOffMinDistance = 15
        sound.RollOffMaxDistance = 160
        sound.Parent = part
        sound:Play()
    end
    Debris:AddItem(part, 1.8)
end

local plumes = {}
local function fireEruption(ev, serverTime)
    if not folder then
        return
    end
    local rng = Random.new(math.floor(ev.seed * 1e6))
    local origin = Vector3.new(ev.x, surfaceHeightAt(ev.x, ev.z, serverTime) + 1, ev.z)
    -- the plume: a neon column that shoots up and sinks back
    local column = neonPart(Vector3.new(5, 1, 5), Color3.fromRGB(255, 120, 30), folder)
    column.Transparency = 0.1
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 130, 50)
    light.Range = 70
    light.Brightness = 9
    light.Parent = column
    local whoosh = Instance.new("Sound")
    whoosh.Name = "EruptionWhooshSfx"
    whoosh.SoundId = "rbxassetid://9114463219"
    whoosh.Volume = 0.85
    whoosh.PlaybackSpeed = 0.72 + rng:NextNumber() * 0.16
    whoosh.RollOffMode = Enum.RollOffMode.InverseTapered
    whoosh.RollOffMinDistance = 25
    whoosh.RollOffMaxDistance = 260
    whoosh.Parent = column
    whoosh:Play()
    local bubble = Instance.new("Sound")
    bubble.Name = "EruptionBubbleSfx"
    bubble.SoundId = "rbxassetid://9125409816"
    bubble.Volume = 0.75
    bubble.PlaybackSpeed = 0.58 + rng:NextNumber() * 0.14
    bubble.RollOffMode = Enum.RollOffMode.InverseTapered
    bubble.RollOffMinDistance = 25
    bubble.RollOffMaxDistance = 240
    bubble.Parent = column
    bubble:Play()
    table.insert(plumes, { part = column, origin = origin, born = os.clock(), height = 26 + rng:NextNumber() * 14 })
    -- the spray: glowing voxel cubes thrown up and out
    for _ = 1, 18 do
        local side = ({ 1, 1, 2, 2, 3 })[rng:NextInteger(1, 5)]
        local heat = rng:NextNumber()
        local bit = neonPart(Vector3.new(side, side, side), Color3.fromRGB(255, 60 + heat * 150, 10 + heat * 50), folder)
        local angle = rng:NextNumber() * TAU
        local flat = 5 + rng:NextNumber() * 22
        table.insert(bits, {
            part = bit,
            origin = origin,
            velocity = Vector3.new(math.cos(angle) * flat, 85 + rng:NextNumber() * 38, math.sin(angle) * flat),
            born = os.clock(),
            spin = CFrame.Angles(rng:NextNumber() * TAU, rng:NextNumber() * TAU, 0),
        })
    end
    splash(origin)
    ringActive[ev.n] = { x = ev.x, z = ev.z, burst = ev.burst }
end

local function stepEffects(serverTime)
    local now = os.clock()
    for i = #plumes, 1, -1 do
        local plume = plumes[i]
        local age = now - plume.born
        if age > 1.4 or not plume.part.Parent then
            plume.part:Destroy()
            table.remove(plumes, i)
        else
            local rise = age < 0.4 and age / 0.4 or math.max(0, 1 - (age - 0.4) / 1.0)
            local height = math.max(1, plume.height * rise)
            plume.part.Size = Vector3.new(5 * (0.6 + 0.4 * rise), height, 5 * (0.6 + 0.4 * rise))
            plume.part.Position = plume.origin + Vector3.new(0, height / 2 - 1, 0)
        end
    end
    for i = #bits, 1, -1 do
        local bit = bits[i]
        local age = now - bit.born
        local p = bit.origin + bit.velocity * age + Vector3.new(0, -0.5 * BIT_GRAVITY * age * age, 0)
        if age > 0.3 and p.Y < surfaceHeightAt(p.X, p.Z, serverTime) then
            splash(Vector3.new(p.X, surfaceHeightAt(p.X, p.Z, serverTime), p.Z))
            bit.part:Destroy()
            table.remove(bits, i)
        elseif age > 6 or not bit.part.Parent then
            bit.part:Destroy()
            table.remove(bits, i)
        else
            bit.part.CFrame = CFrame.new(p) * bit.spin * CFrame.Angles(age * 3, age * 2, 0)
        end
    end
end

-- Zone presence -----------------------------------------------------------------------------------------------------
local lastCheck = 0
local function playerInZone()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return false
    end
    local offset = root.Position - CENTER
    return Vector3.new(offset.X, 0, offset.Z).Magnitude < ZONE_REACH and math.abs(offset.Y) < 600
end

local frame = 0
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    if now - lastCheck > 0.5 then
        lastCheck = now
        local want = playerInZone() and workspace:FindFirstChild("PvPArena") ~= nil
        if want and not built and not building then
            task.spawn(buildLava)
        elseif not want and (built or folder) then
            destroyLava()
            for _, bit in bits do
                bit.part:Destroy()
            end
            for _, plume in plumes do
                plume.part:Destroy()
            end
            table.clear(bits)
            table.clear(plumes)
        end
    end
    if not built then
        return
    end
    frame += 1
    local serverTime = workspace:GetServerTimeNow()
    collectEruptions(serverTime)
    for _, ev in active do
        if ev.t >= 0 and ev.t < 1 and not fired[ev.n] then
            fired[ev.n] = true
            fireEruption(ev, serverTime)
        end
    end
    fired[math.floor(serverTime / SLOT) - 6] = nil
    local camera = workspace.CurrentCamera
    local cameraCFrame = camera and camera.CFrame or CFrame.new(CENTER)
    local cameraPosition, look = cameraCFrame.Position, cameraCFrame.LookVector
    if soundAnchor and soundAnchor.Parent then
        local offset = Vector3.new(cameraPosition.X - CENTER.X, 0, cameraPosition.Z - CENTER.Z)
        local maxReach = RADIUS * 0.85
        if offset.Magnitude > maxReach then
            offset = offset.Unit * maxReach
        end
        soundAnchor.Position = Vector3.new(CENTER.X + offset.X, LAVA_Y + 4, CENTER.Z + offset.Z)
    end
    for _, chunk in chunks do
        local dx, dz = chunk.cx - cameraPosition.X, chunk.cz - cameraPosition.Z
        local distance = math.sqrt(dx * dx + dz * dz)
        local ahead = dx * look.X + dz * look.Z
        local near = distance < NEAR
        local flowChanged = near ~= chunk.flowOn and (near or distance > NEAR + 20)
        if flowChanged then
            chunk.flowOn = near
            chunk.flowPart.Transparency = near and FLOW_TRANSPARENCY or 1
        end
        local close = distance < CREST_NEAR
        local crestChanged = close ~= chunk.crestOn and (close or distance > CREST_NEAR + 15)
        if crestChanged then
            chunk.crestOn = close
            chunk.crestPart.Transparency = close and CREST_TRANSPARENCY or 1
        end
        local every = near and 3 or (distance < MID and 6 or 10)
        if
            (flowChanged or crestChanged or (frame + chunk.frame) % every == 0)
            and (ahead > -BEHIND or distance < CHUNK_CELLS * CELL)
        then
            updateChunk(chunk, serverTime, chunk.flowOn, chunk.crestOn)
        end
    end
    stepEffects(serverTime)
    stepRingCubes(serverTime)
end)
