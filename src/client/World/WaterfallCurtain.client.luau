--!native
-- StarterPlayerScripts.WaterfallCurtain (client only): the waterfall (the old slab sheet is backed up in
-- ServerStorage.RiverBackups.OldSlabWaterfall). A curved EditableMesh sheet that runs the whole cliff-top channel (where the
-- terrain water used to be; the server clears it), pours off the lip and arcs out under gravity into the plunge
-- pool. Three layers (WaterTemplates):
--   body  WaterfallBodyAppearance, studded pixel water (1-stud pixels in shades of blue with light streaks, a stud on
--         each, mixed roughness so some pixels glint) sliding down the sheet
--   veil  WaterfallVeilAppearance, sparse studded white streak pixels just in front, sliding down faster
--   waves WaterfallWaveAppearance, a translucent sheet in front of everything with fine realistic ripples racing
--         down at a slight slant, like the river's wave layer
-- High tide (ReplicatedStorage.WaterfallRiver.RiverWaves): the waterfall BURSTS when a tide starts (a surge of water
-- throws the arc far out, with a spray and splash burst, a rumble and a short camera shake nearby), then pours
-- wider, thicker and faster for the whole tide while the splash emitters roar. The first surge wave of the tide
-- leaves the foot of the falls a moment later (RiverWaves.State).
-- Geometry comes from the FallFX attributes (FrontX = lip face, TopY = lip height, Z0/Z1 = sheet edges).
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local riverAssets = ReplicatedStorage:WaitForChild("WaterfallRiver")
local Path = require(riverAssets:WaitForChild("RiverPath"))
local Waves = require(riverAssets:WaitForChild("RiverWaves"))
local WaterQuality = require(riverAssets:WaitForChild("WaterQuality"))
local player = Players.LocalPlayer
local templates = riverAssets:WaitForChild("WaterTemplates")
local riverRoot = workspace:WaitForChild("WaterfallRiver")
local fallFx = riverRoot:WaitForChild("FallFX")
if workspace:GetAttribute("RiverMeshWater") == false then
    return -- EditableMesh unavailable: keep the original slab waterfall
end

local LIP_X = fallFx:GetAttribute("FrontX") or -282.5
local TOP_Y = fallFx:GetAttribute("TopY") or 57.6
local Z0, Z1 = fallFx:GetAttribute("Z0") or 13, fallFx:GetAttribute("Z1") or 27
local Z_CENTRE = (Z0 + Z1) / 2
local BASE_HALF = (Z1 - Z0) / 2 + 0.5
local COLUMNS = 8 -- quads across the sheet
-- Cliff-top channel the water runs along before the lip (it used to hold terrain water, x -314 .. lip, y ~58).
local POOL_BACK_X = fallFx:GetAttribute("PoolBackX") or LIP_X - 31.5
local POOL_Y = fallFx:GetAttribute("PoolSurfaceY") or TOP_Y + 0.37
local CHANNEL_HALF = 8 -- the channel is 16 studs wide
local RUN_ROWS = 16 -- rows along the channel, ~2 studs apart
local RUN_STEP = (LIP_X - POOL_BACK_X) / RUN_ROWS
local FALL_ROWS = 22 -- rows down the drop, packed toward the lip where the arc bends most
local GRAVITY = 60
local CALM_THROW = 3.5 -- studs per second the water leaves the lip with
local TIDE_THROW = 7 -- extra at full tide
local BURST_THROW = 18 -- extra at the peak of the burst
local TEXTURE_LENGTH = 32 -- studs of sheet per texture tile (1 studded piece = 1 stud)
local FALL_SPEED = 16 -- studs per second the pieces slide down
local VEIL_OFFSET = 0.35
local WAVE_OFFSET = 0.6 -- the realistic wave layer sits in front of the studded pieces
local WAVE_LENGTH = 12 -- studs of sheet per tile of the wave layer's fine ripples
local BURST_DECAY = 3.8 -- seconds for the burst to ease off (was 2.4)
local BURST_RISE = 1.1 -- seconds for the burst to build up (it used to snap to full in 0.25)
local WAVE_TRANSPARENCY = 0.82
-- Level of detail, from the camera distance to the falls (Simple Water caps it at LOD 1):
--   LOD 0  < LOD_NEAR  shape rebuilt every frame (wobble, run swell), all three layers
--   LOD 1  < LOD_MID   wobble frozen, shape rebuilt only when the tide / burst changes the arc, textures slide every 2
--                      frames, ripple sheen hidden
--   LOD 2  beyond      as LOD 1, every 6 frames
-- Nothing is updated while the falls are behind the camera; splash emitters and sound keep running regardless.
local LOD_NEAR = 140
local LOD_MID = 320
local LOD_EVERY = { [0] = 1, [1] = 2, [2] = 6 }
local BEHIND_MARGIN = 40

-- Burst strength at `now` for the tide window that started at startedAt: builds up smoothly, then decays.
local function burstAt(startedAt, now)
    if not startedAt or now < startedAt then
        return 0
    end
    local t = now - startedAt
    local rise = math.clamp(t / BURST_RISE, 0, 1)
    return rise * rise * (3 - 2 * rise) * math.exp(-math.max(0, t - BURST_RISE) / BURST_DECAY)
end

-- Sheet shape ---------------------------------------------------------------------------------------------------
-- positions[row][column] for the current throw speed, half width, water level and time.
local ROWS = RUN_ROWS + FALL_ROWS + 1
local function sheetPoint(row, column, throw, half, baseY, now, layerOffset)
    local u = column / COLUMNS
    local zSpread = (u - 0.5) * 2
    if row < RUN_ROWS then
        -- Running along the cliff-top channel toward the lip, with small ripples; deeper at high tide.
        local x = LIP_X - (RUN_ROWS - row) * RUN_STEP
        local swell = 0.08 * math.sin(now * 3 + column * 1.3 - x * 0.6) + (throw - CALM_THROW) * 0.05
        local z = Z_CENTRE + zSpread * math.min(half * 1.05, CHANNEL_HALF)
        return Vector3.new(x, POOL_Y + swell + layerOffset * 0.1, z), 0
    end
    local q = (row - RUN_ROWS) / FALL_ROWS
    local h = (TOP_Y - baseY) * q ^ 1.5
    local fallTime = math.sqrt(2 * h / GRAVITY)
    -- The sheet fans out a little as it falls and ripples sideways.
    local wobble = 0.22 * math.sin(zSpread * 4 + now * 4.5 + q * 7) * q
    local x = LIP_X + 0.15 + throw * fallTime + wobble + layerOffset * (1 + q * 0.6)
    local z = Z_CENTRE + zSpread * half * (1 + 0.14 * q)
    return Vector3.new(x, TOP_Y - h, z), h
end

-- Mesh building (same fixed-size copy approach as RiverWater: growable meshes reserve too much memory) -----------
local centre = Vector3.new(LIP_X + 4, (TOP_Y + Path.SurfaceY) / 2, Z_CENTRE)
local function buildLayer(name, appearance, layerOffset)
    local em = AssetService:CreateEditableMesh()
    assert(em, "Waterfall mesh memory unavailable")
    local ids = {}
    local verts = {}
    -- Lay the mesh out at its widest burst shape so the part's bounds cover every later pose.
    local maxThrow = CALM_THROW + TIDE_THROW + BURST_THROW
    for row = 0, ROWS - 1 do
        for column = 0, COLUMNS do
            local p = sheetPoint(row, column, maxThrow, BASE_HALF * 1.7, Path.SurfaceY, 0, layerOffset) - centre
            local key = tostring(p)
            local vert = { row = row, column = column, key = key }
            ids[vert] = { em:AddVertex(p), em:AddNormal(Vector3.xAxis), em:AddUV(Vector2.zero) }
            table.insert(verts, vert)
        end
    end
    local width = COLUMNS + 1
    local function at(row, column)
        return ids[verts[row * width + column + 1]]
    end
    local function face(a, b, c)
        local f = em:AddTriangle(a[1], b[1], c[1])
        em:SetFaceNormals(f, { a[2], b[2], c[2] })
        em:SetFaceUVs(f, { a[3], b[3], c[3] })
    end
    for row = 0, ROWS - 2 do
        for column = 0, COLUMNS - 1 do
            -- Faces out from the cliff (rows run down the fall, columns toward +Z).
            local a, b, c, d = at(row, column), at(row, column + 1), at(row + 1, column), at(row + 1, column + 1)
            face(a, b, d)
            face(a, d, c)
        end
    end
    local mesh = AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
    assert(mesh, "Waterfall mesh memory unavailable")
    local byPosition = {}
    for _, id in mesh:GetVertices() do
        byPosition[tostring(mesh:GetPosition(id))] = id
    end
    em:Destroy()
    for _, vert in verts do
        local id = byPosition[vert.key]
        vert.id, vert.nid, vert.uv = id, mesh:GetVertexNormals(id)[1], mesh:GetVertexUVs(id)[1]
    end
    local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh), {
        CollisionFidelity = Enum.CollisionFidelity.Box,
    })
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
    templates[appearance]:Clone().Parent = part
    return { mesh = mesh, part = part, verts = verts, offset = layerOffset, name = name }
end

local folder = Instance.new("Folder")
folder.Name = "WaterfallCurtainLocal"
local built, layersOrError = pcall(function()
    return {
        buildLayer("WaterfallBody", "WaterfallBodyAppearance", 0),
        buildLayer("WaterfallVeil", "WaterfallVeilAppearance", VEIL_OFFSET),
        buildLayer("WaterfallWaves", "WaterfallWaveAppearance", WAVE_OFFSET),
    }
end)
if built then
    -- The wave layer only carries ripple normals and gloss: a faint pale sheen over the pixel water.
    local waveLayer = layersOrError[3]
    waveLayer.part.Color = Color3.fromRGB(200, 244, 252)
    waveLayer.part.Transparency = WAVE_TRANSPARENCY
end
if not built then
    warn("[WaterfallCurtain] could not build the waterfall:", layersOrError)
    riverRoot:SetAttribute("WaterfallCurtainError", tostring(layersOrError))
    return
end
local layers = layersOrError
for _, layer in layers do
    layer.part.Parent = folder
end
folder.Parent = workspace


-- Splash emitters follow the arc's landing point and roar with the tide --------------------------------------------
local emitters = {}
local movers = {}
for _, holder in { fallFx, riverRoot:FindFirstChild("FX") } do
    if holder then
        for _, emitter in holder:GetDescendants() do
            if emitter:IsA("ParticleEmitter") then
                table.insert(emitters, { emitter = emitter, rate = emitter.Rate })
            end
        end
    end
end
for _, name in { "Impact", "SplashBase" } do
    local part = fallFx:FindFirstChild(name)
    if part then
        table.insert(movers, { part = part, home = part.CFrame, size = part.Size })
    end
end
local fallSound = fallFx:FindFirstChild("SplashBase") and fallFx.SplashBase:FindFirstChildOfClass("Sound")
local soundVolume = fallSound and fallSound.Volume or 0
local fxAnchor = riverRoot:FindFirstChild("FX") and riverRoot.FX:FindFirstChild("SplashEmitter")

local function burstEffects()
    for _, entry in emitters do
        entry.emitter:Emit(math.clamp(math.floor(entry.rate * 1.5), 20, 220))
    end
    if fallSound then
        local rumble = fallSound:Clone()
        rumble.Looped = false
        rumble.Volume = 1.4
        rumble.PlaybackSpeed = 0.55
        rumble.Parent = fxAnchor or fallSound.Parent
        rumble:Play()
        task.delay(4, function()
            rumble:Destroy()
        end)
    end
    -- Short camera shake for players who can see it happen up close.
    local camera = workspace.CurrentCamera
    local distance = camera and (camera.CFrame.Position - Vector3.new(LIP_X, Path.SurfaceY, Z_CENTRE)).Magnitude
    if distance and distance < 170 then
        local strength = 0.35 * (1 - distance / 170)
        local started = os.clock()
        RunService:BindToRenderStep("WaterfallBurstShake", Enum.RenderPriority.Camera.Value + 1, function()
            local t = os.clock() - started
            if t > 0.9 then
                RunService:UnbindFromRenderStep("WaterfallBurstShake")
                return
            end
            local k = strength * (1 - t / 0.9)
            workspace.CurrentCamera.CFrame *= CFrame.Angles(
                math.rad(math.sin(t * 61) * 2 * k),
                math.rad(math.sin(t * 47 + 1) * 2 * k),
                0
            )
        end)
    end
end

-- Animation ------------------------------------------------------------------------------------------------------
local veilPhase, bodyPhase, wavePhase = 0.37, 0, 0
local burstFor -- the tide window whose burst already played
local frame = 0
local positions = table.create(ROWS)
local shownLod, reshapeAll = 0, true
local lastShape = { throw = -1, half = -1, baseY = -1 }
RunService.RenderStepped:Connect(function(dt)
    frame += 1
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local now = workspace:GetServerTimeNow()
    local state = Waves.State(now)
    local burst = burstAt(state.startedAt, now)
    if state.startedAt and state.startedAt ~= burstFor and now - state.startedAt < 3 and state.tide > 0 then
        burstFor = state.startedAt
        burstEffects()
    elseif not burstFor then
        burstFor = state.startedAt -- don't replay a burst that happened before this client joined
    end

    local tide = state.tide
    local throw = CALM_THROW + TIDE_THROW * tide + BURST_THROW * burst
    local half = BASE_HALF * (1 + 0.45 * tide + 0.45 * burst)
    local baseY = Path.SurfaceY + state.level - 0.3
    local flow = 1 + 1.4 * tide + 1.5 * burst
    veilPhase = (veilPhase + dt * FALL_SPEED * 1.35 * flow / TEXTURE_LENGTH) % 1
    bodyPhase = (bodyPhase + dt * FALL_SPEED * flow / TEXTURE_LENGTH) % 1
    wavePhase = (wavePhase + dt * FALL_SPEED * 1.2 * flow / WAVE_LENGTH) % 1

    -- Emitters, sound and the splash parts move out to where the arc now lands.
    local landX = LIP_X + throw * math.sqrt(2 * (TOP_Y - baseY) / GRAVITY)
    for _, entry in emitters do
        entry.emitter.Rate = entry.rate * (1 + 2 * tide + 3 * burst)
    end
    for _, mover in movers do
        mover.part.CFrame = mover.home + Vector3.new(landX - mover.home.X - 0.5, state.level, 0)
        mover.part.Size = Vector3.new(mover.size.X, mover.size.Y, mover.size.Z * half / BASE_HALF)
    end
    if fallSound then
        fallSound.Volume = soundVolume * (1 + 2.5 * tide + 2 * burst)
        fallSound.PlaybackSpeed = 1 - 0.15 * tide
    end

    -- Level of detail (see the header): pick the LOD, hide the ripple sheen beyond LOD 0, skip when behind the camera
    -- or between the LOD's update frames.
    local toFall = centre - camera.CFrame.Position
    local distance = toFall.Magnitude
    local lod = distance < LOD_NEAR and 0 or distance < LOD_MID and 1 or 2
    if WaterQuality.IsSimple(player) then
        lod = math.max(lod, 1)
    end
    if lod ~= shownLod then
        shownLod = lod
        layers[3].part.Transparency = lod == 0 and WAVE_TRANSPARENCY or 1
        reshapeAll = true
    end
    if toFall:Dot(camera.CFrame.LookVector) < -BEHIND_MARGIN or frame % LOD_EVERY[lod] ~= 0 then
        return
    end
    -- LOD 0 rebuilds the shape every frame (it wobbles with time). LOD 1 / 2 freeze the wobble and only rebuild when
    -- the tide or the burst changes the arc; otherwise the textures just slide over the cached shape.
    local shapeTime = lod == 0 and now or 0
    local reshape = lod == 0
        or reshapeAll
        or math.abs(throw - lastShape.throw) > 0.02
        or math.abs(half - lastShape.half) > 0.02
        or math.abs(baseY - lastShape.baseY) > 0.01
    if reshape then
        lastShape.throw, lastShape.half, lastShape.baseY = throw, half, baseY
    end
    for index, layer in layers do
        if index == 3 and lod > 0 then
            continue -- hidden ripple sheen
        end
        local mesh, offset = layer.mesh, layer.offset
        if reshape or reshapeAll or not layer.lengths then
            for row = 0, ROWS - 1 do
                local rowPositions = positions[row + 1] or {}
                positions[row + 1] = rowPositions
                for column = 0, COLUMNS do
                    rowPositions[column + 1] =
                        sheetPoint(row, column, throw, half * (1 + offset * 0.1), baseY, shapeTime, offset)
                end
            end
            -- Texture V follows the sheet's length down its middle, so streaks keep their size as the arc stretches.
            local lengths = table.create(ROWS)
            local run = 0
            local middle = COLUMNS // 2 + 1
            for row = 1, ROWS do
                if row > 1 then
                    run += (positions[row][middle] - positions[row - 1][middle]).Magnitude
                end
                lengths[row] = run
            end
            layer.lengths = lengths
            for _, vert in layer.verts do
                local row, column = vert.row + 1, vert.column + 1
                local rowPositions = positions[row]
                local p = rowPositions[column]
                local across = rowPositions[math.min(COLUMNS + 1, column + 1)] - rowPositions[math.max(1, column - 1)]
                local down = positions[math.min(ROWS, row + 1)][column] - positions[math.max(1, row - 1)][column]
                mesh:SetPosition(vert.id, p - centre)
                mesh:SetNormal(vert.nid, across:Cross(down).Unit)
                vert.across16 = (p.Z - Z_CENTRE) / 16
            end
        end
        -- Every layer slides down the sheet: the body, the front streaks faster, and the wave layer's fine ripples
        -- fastest, at a slight slant so they cross the others.
        local layerPhase = layer.name == "WaterfallVeil" and veilPhase
            or layer.name == "WaterfallWaves" and wavePhase
            or bodyPhase
        local slant = layer.name == "WaterfallWaves" and 0.25 or 0
        local repeatLength = layer.name == "WaterfallWaves" and WAVE_LENGTH or TEXTURE_LENGTH
        local lengths = layer.lengths
        for _, vert in layer.verts do
            local across16 = vert.across16
            mesh:SetUV(
                vert.uv,
                Vector2.new(across16 + 0.5, lengths[vert.row + 1] / repeatLength + across16 * slant - layerPhase)
            )
        end
    end
    reshapeAll = false
end)
