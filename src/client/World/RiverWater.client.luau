--!native
-- StarterPlayerScripts.RiverWater (client only): animated mesh water for the waterfall river, adapted from the
-- MIC SIDEWAYS! ocean (CustomWaterWaves v4). The server's RiverWater script clears the river's terrain water; this
-- script replaces it with:
--   base layer   translucent EditableMesh ribbon along RiverPath, riding ReplicatedStorage.WaterfallRiver.RiverWaves,
--                with studded pixel ripples (RiverFlowAppearance: 1-stud pixels, each with a stud, light and dark
--                shades from the first ripple map, and mixed roughness so some pixels glint) sliding downstream
--   foam layer   a copy just above it with studded pixel foam along the banks and in streaks (RiverFoamAppearance),
--                swapped for the churned RiverTideFoamAppearance during high tide
--   wave layer   a faint translucent copy on top with fine realistic ripples (RiverWaveAppearance) crossing the
--                current at an angle, adding a sheen of moving water
--   surge crests one flat foam Beam across the river on each high tide surge, tilted to lie on the wave's back
--
-- Level of detail, per chunk, from the camera distance to the chunk's nearest end:
--   LOD 0  < LOD_NEAR  full waves: heights, normals and all three layers every frame
--   LOD 1  < LOD_MID   flat surface (one flatten pass, then only the textures slide, every 2 frames); ripple sheen
--                      layer hidden
--   LOD 2  beyond      flat, textures slide every 6 frames
-- Chunks behind the camera are not updated at all. The tide's rise moves the chunk parts instead of their vertices, so
-- it shows at every LOD for the cost of three CFrame writes per chunk. Simple Water (WaterQuality, the Settings panel)
-- caps every chunk at LOD 1: still moving, much cheaper.
--
-- Engine notes carried over from the ocean (measured in Studio):
-- 1. Changing one vertex makes the engine reprocess the whole mesh that frame, so the river is cut into chunks and
--    only chunks near the camera update every frame.
-- 2. A new MeshPart takes its size and centre from the mesh bounds at creation, so each chunk is built flat around
--    its own centre.
-- 3. Vertex alpha does not render; foam fades through its texture alpha instead.
-- Templates live in ReplicatedStorage.WaterfallRiver.WaterTemplates (scripts cannot set SurfaceAppearance maps).
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local riverAssets = ReplicatedStorage:WaitForChild("WaterfallRiver")
local Config = require(riverAssets:WaitForChild("RiverConfig"))
local Path = require(riverAssets:WaitForChild("RiverPath"))
local Waves = require(riverAssets:WaitForChild("RiverWaves"))
local WaterQuality = require(riverAssets:WaitForChild("WaterQuality"))
local player = Players.LocalPlayer
local templates = riverAssets:WaitForChild("WaterTemplates")
local riverRoot = workspace:WaitForChild("WaterfallRiver")
if workspace:GetAttribute("RiverMeshWater") == false then
    return -- the server found EditableMesh unavailable and kept the terrain water (RiverFlow draws the current)
end

local SURFACE_Y = Path.SurfaceY
local TOTAL = Path.Total
local ROW_SPACING = 2 -- studs between rows along the river (shortest wave is 5.2 studs, so no aliasing)
local COLUMNS = 8 -- quads across the river
local OVERHANG = 0.8 -- the ribbon reaches this far past each wall, tucked under the bank
local START_DISTANCE = -6 -- starts a little behind the waterfall foot, inside the cliff
local CHUNK_ROWS = 30 -- rows per chunk (60 studs)
local LOD_NEAR = 120 -- closer than this (camera to the chunk's nearest end): full waves (LOD 0)
local LOD_MID = 280 -- closer than this: flat, textures every 2 frames (LOD 1); beyond: every 6 frames (LOD 2)
local LOD_EVERY = { [0] = 1, [1] = 2, [2] = 6 }
local BEHIND_MARGIN = 45 -- a chunk whose centre is this far behind the camera plane is skipped
local FLOW_REPEAT = 16 -- studs per tile of the realistic ripple map (the first, smooth river texture)
local FLOW_SPEED = 7.5 -- studs per second the realistic ripples slide downstream
local FOAM_REPEAT = 36 -- studs per tile of pixel foam along the river
local FOAM_SPEED = 5.5 -- studs per second the foam slides downstream
local FOAM_LIFT = 0.045
local WAVE_LIFT = 0.1 -- the realistic wave layer floats just above the pieces
local WAVE_REPEAT = 12 -- studs per tile of the wave layer's ripples
local WAVE_SPEED = 5 -- studs per second along its own heading
local WAVE_ANGLE = math.rad(32) -- its ripples run this far off the current, crossing the base layer's
local WAVE_COS, WAVE_SIN = math.cos(WAVE_ANGLE), math.sin(WAVE_ANGLE)
local WAVE_TRANSPARENCY = 0.82 -- a faint sheen of ripples over the pixel water
local WAVE_TINT = Color3.fromRGB(200, 244, 252) -- pale, so the ripple layer adds glints without darkening the water
local WATER_TRANSPARENCY = 0.3
local CREST_WIDTH = 7 -- studs of foam across each surge crest (front lip sits ~0.5 studs behind the crest)
local TIDE_FOAM_ON, TIDE_FOAM_OFF = 0.35, 0.2 -- tide strength hysteresis for switching to the tide pieces

local waterColor = riverRoot:GetAttribute("WaterColor") or Config.Terrain.WaterColor
local crestTexture = templates:GetAttribute("CrestFoamTexture") or ""

-- Path frame, extended straight back past the waterfall foot for negative distances.
local function frameAt(d)
    if d < 0 then
        local p, t, r = Path.At(0)
        return p + t * d, t, r
    end
    return Path.At(d)
end

local folder = Instance.new("Folder")
folder.Name = "RiverWaterLocal"
folder.Parent = workspace

-- Nodes ----------------------------------------------------------------------------------------------------------
-- rows[i][c] = node {d, s, lateral, wallHalf, x, z, tx, tz, rx, rz, prep, h}; s is -1..1 wall to wall (clamped for
-- the overhang), lateral is studs from the centre line, prep is the node's RiverWaves.Prepare terms.
local rows = {}
do
    local i = 0
    while true do
        local d = START_DISTANCE + i * ROW_SPACING
        if d > TOTAL + ROW_SPACING then
            break
        end
        d = math.min(d, TOTAL + 1)
        local p, t, r = frameAt(d)
        local wallHalf = Path.WidthAt(math.clamp(d, 0, TOTAL)) * 0.5
        local half = wallHalf + OVERHANG
        local row = table.create(COLUMNS + 1)
        for c = 0, COLUMNS do
            local lateral = (c / COLUMNS * 2 - 1) * half
            local pos = p + r * lateral
            local s = math.clamp(lateral / wallHalf, -1, 1)
            row[c] = {
                d = d,
                s = s,
                prep = Waves.Prepare(d, s),
                lateral = lateral,
                wallHalf = wallHalf,
                x = pos.X,
                z = pos.Z,
                tx = t.X,
                tz = t.Z,
                rx = r.X,
                rz = r.Z,
                h = 0,
            }
        end
        rows[i] = row
        i += 1
    end
end
local ROW_COUNT = #rows + 1 -- rows is 0-based

-- Chunks ---------------------------------------------------------------------------------------------------------
local chunks = {}
local function newMeshPart(mesh, centre, name)
    local part = AssetService:CreateMeshPartAsync(
        Content.fromObject(mesh),
        { CollisionFidelity = Enum.CollisionFidelity.Box }
    )
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.DoubleSided = true
    part.Material = Enum.Material.SmoothPlastic
    part.CFrame = CFrame.new(centre)
    return part
end

local function buildChunk(firstRow, lastRow, index)
    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
    for i = firstRow, lastRow do
        for c = 0, COLUMNS do
            local n = rows[i][c]
            minX, maxX = math.min(minX, n.x), math.max(maxX, n.x)
            minZ, maxZ = math.min(minZ, n.z), math.max(maxZ, n.z)
        end
    end
    local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
    -- Build once in a growable mesh, then keep fixed-size copies (base, pieces, waves): growable meshes reserve far
    -- more memory than they use, and the client runs out after a few. Copies may renumber vertices, so each vertex is
    -- found again by its rest position (unique within a chunk).
    local em = AssetService:CreateEditableMesh()
    assert(em, "River mesh memory unavailable")
    local verts = {}
    local ids = {}
    for i = firstRow, lastRow do
        for c = 0, COLUMNS do
            local n = rows[i][c]
            local rest = Vector3.new(n.x - cx, 0, n.z - cz)
            local vert = { node = n, row = i, column = c, lx = rest.X, lz = rest.Z, key = tostring(rest) }
            ids[vert] = { em:AddVertex(rest), em:AddNormal(Vector3.yAxis), em:AddUV(Vector2.zero) }
            table.insert(verts, vert)
        end
    end
    local width = COLUMNS + 1
    local function at(i, c)
        return ids[verts[(i - firstRow) * width + c + 1]]
    end
    local function face(a, b, c)
        local f = em:AddTriangle(a[1], b[1], c[1])
        em:SetFaceNormals(f, { a[2], b[2], c[2] })
        em:SetFaceUVs(f, { a[3], b[3], c[3] })
    end
    for i = firstRow, lastRow - 1 do
        for c = 0, COLUMNS - 1 do
            -- Winding faces up (rows run downstream, columns run toward RiverPath's right).
            local a, b, cc, dd = at(i, c), at(i, c + 1), at(i + 1, c), at(i + 1, c + 1)
            face(a, b, dd)
            face(a, dd, cc)
        end
    end
    local function fixedCopy()
        local copy = AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
        assert(copy, "River mesh memory unavailable")
        local byPosition = {}
        for _, id in copy:GetVertices() do
            byPosition[tostring(copy:GetPosition(id))] = id
        end
        return copy, byPosition
    end
    local base, baseIds = fixedCopy()
    local foam, foamIds = fixedCopy()
    local wave, waveIds = fixedCopy()
    em:Destroy()
    for _, vert in verts do
        local id, fid, wid = baseIds[vert.key], foamIds[vert.key], waveIds[vert.key]
        vert.id, vert.nid, vert.uv = id, base:GetVertexNormals(id)[1], base:GetVertexUVs(id)[1]
        vert.fid, vert.fnid, vert.fuv = fid, foam:GetVertexNormals(fid)[1], foam:GetVertexUVs(fid)[1]
        vert.wid, vert.wnid, vert.wuv = wid, wave:GetVertexNormals(wid)[1], wave:GetVertexUVs(wid)[1]
    end
    local centre = Vector3.new(cx, SURFACE_Y, cz)
    local basePart = newMeshPart(base, centre, "RiverWater" .. index)
    basePart.Color = waterColor
    basePart.Transparency = WATER_TRANSPARENCY
    templates.RiverFlowAppearance:Clone().Parent = basePart
    local foamPart = newMeshPart(foam, centre + Vector3.new(0, FOAM_LIFT, 0), "RiverFoam" .. index)
    foamPart.Color = Color3.new(1, 1, 1)
    local foamAppearance = templates.RiverFoamAppearance:Clone()
    foamAppearance.Parent = foamPart
    local wavePart = newMeshPart(wave, centre + Vector3.new(0, WAVE_LIFT, 0), "RiverWaves" .. index)
    wavePart.Color = WAVE_TINT
    wavePart.Transparency = WAVE_TRANSPARENCY
    templates.RiverWaveAppearance:Clone().Parent = wavePart
    basePart.Parent = folder
    foamPart.Parent = folder
    wavePart.Parent = folder
    return {
        base = base,
        foam = foam,
        wave = wave,
        basePart = basePart,
        foamPart = foamPart,
        wavePart = wavePart,
        lod = 0,
        flat = false,
        foamAppearance = foamAppearance,
        verts = verts,
        firstRow = firstRow,
        lastRow = lastRow,
        centre = centre,
        stagger = index,
    }
end

local built, buildError = pcall(function()
    local index = 1
    local first = 0
    while first < ROW_COUNT - 1 do
        local last = math.min(first + CHUNK_ROWS, ROW_COUNT - 1)
        table.insert(chunks, buildChunk(first, last, index))
        index += 1
        first = last -- chunks share their boundary row, so the seam vertices move identically
        task.wait()
    end
end)
if not built then
    warn("[RiverWater] could not build the river mesh:", buildError)
    riverRoot:SetAttribute("RiverWaterError", tostring(buildError))
    folder:Destroy()
    return
end
riverRoot:SetAttribute("RiverWaterChunks", #chunks)

-- The flow streak beams and RiverFlow's current beams sat on the old flat terrain water; the textured mesh replaces
-- them (they would also sink under the water at high tide).
for _, beam in riverRoot:GetDescendants() do
    if beam:IsA("Beam") and beam:GetAttribute("FlowSpeed") then
        beam.Enabled = false
    end
end
local oldFlow = workspace:FindFirstChild("RiverFlowLocal")
if oldFlow then
    oldFlow:Destroy()
end

-- Load the tide foam and crest textures now so the high tide swap doesn't flash in. Scripts can't read a
-- SurfaceAppearance's maps, so the template folder lists their ids (PreloadTextures), fetched through Decals.
task.spawn(function()
    local decals = {}
    for id in string.gmatch(templates:GetAttribute("PreloadTextures") or "", "[^,]+") do
        local decal = Instance.new("Decal")
        decal.Texture = id
        table.insert(decals, decal)
    end
    pcall(game:GetService("ContentProvider").PreloadAsync, game:GetService("ContentProvider"), decals)
end)

-- Animation ------------------------------------------------------------------------------------------------------
-- LOD 0: full wave geometry. Heights leave out the tide level, which moves the chunk parts instead (placeChunks), and
-- fade to flat by LOD_NEAR from the camera, so a full-detail chunk meets its flat LOD 1 neighbour without a step.
local function updateChunk(chunk, state, flowOffset, foamOffset, waveOffset, cameraPosition)
    local base, foam, wave = chunk.base, chunk.foam, chunk.wave
    local firstRow, lastRow = chunk.firstRow, chunk.lastRow
    chunk.flat = false
    -- Heights first (including one row beyond each end for the normals).
    local camX, camY, camZ = cameraPosition.X, cameraPosition.Y, cameraPosition.Z
    local fadeStart, fadeLength = LOD_NEAR * 0.6, LOD_NEAR * 0.4
    for i = math.max(0, firstRow - 1), math.min(ROW_COUNT - 1, lastRow + 1) do
        local row = rows[i]
        for c = 0, COLUMNS do
            local n = row[c]
            local dx, dy, dz = n.x - camX, SURFACE_Y - camY, n.z - camZ
            local q = math.clamp((math.sqrt(dx * dx + dy * dy + dz * dz) - fadeStart) / fadeLength, 0, 1)
            n.h = (Waves.HeightAtPrepared(state, n.prep) - state.level) * (1 - q * q * (3 - 2 * q))
        end
    end
    for _, v in chunk.verts do
        local n, i, c = v.node, v.row, v.column
        local row = rows[i]
        local up, down = rows[math.max(0, i - 1)][c], rows[math.min(ROW_COUNT - 1, i + 1)][c]
        local left, right = row[math.max(0, c - 1)], row[math.min(COLUMNS, c + 1)]
        local slopeAlong = (down.h - up.h) / math.max(down.d - up.d, 0.01)
        local slopeAcross = (right.h - left.h) / math.max(right.lateral - left.lateral, 0.01)
        local normal = Vector3.new(
            -slopeAlong * n.tx - slopeAcross * n.rx,
            1,
            -slopeAlong * n.tz - slopeAcross * n.rz
        ).Unit
        local position = Vector3.new(v.lx, n.h, v.lz)
        base:SetPosition(v.id, position)
        base:SetNormal(v.nid, normal)
        foam:SetPosition(v.fid, position)
        foam:SetNormal(v.fnid, normal)
        base:SetUV(v.uv, Vector2.new(n.lateral / FLOW_REPEAT, (n.d - flowOffset) / FLOW_REPEAT))
        foam:SetUV(v.fuv, Vector2.new(0.5 + n.lateral / (2 * n.wallHalf), (n.d - foamOffset) / FOAM_REPEAT))
        -- Wave layer: the same surface, its ripples turned WAVE_ANGLE off the current so they cross the base layer's.
        wave:SetPosition(v.wid, position)
        wave:SetNormal(v.wnid, normal)
        wave:SetUV(
            v.wuv,
            Vector2.new(
                (n.lateral * WAVE_COS + n.d * WAVE_SIN) / WAVE_REPEAT,
                (n.d * WAVE_COS - n.lateral * WAVE_SIN - waveOffset) / WAVE_REPEAT
            )
        )
    end
end

-- LOD 1 and 2: lay the chunk flat once, then only slide its textures (two writes per vertex instead of nine; the
-- hidden wave layer is left alone).
local function flattenChunk(chunk)
    local base, foam = chunk.base, chunk.foam
    for _, v in chunk.verts do
        local position = Vector3.new(v.lx, 0, v.lz)
        base:SetPosition(v.id, position)
        base:SetNormal(v.nid, Vector3.yAxis)
        foam:SetPosition(v.fid, position)
        foam:SetNormal(v.fnid, Vector3.yAxis)
    end
    chunk.flat = true
end
local function slideChunk(chunk, flowOffset, foamOffset)
    local base, foam = chunk.base, chunk.foam
    for _, v in chunk.verts do
        local n = v.node
        base:SetUV(v.uv, Vector2.new(n.lateral / FLOW_REPEAT, (n.d - flowOffset) / FLOW_REPEAT))
        foam:SetUV(v.fuv, Vector2.new(0.5 + n.lateral / (2 * n.wallHalf), (n.d - foamOffset) / FOAM_REPEAT))
    end
end

-- The tide level lifts every chunk part (cheap, so it also shows on flat LOD 1 / 2 chunks and in Simple Water).
local placedLevel = -1
local function placeChunks(level)
    if math.abs(level - placedLevel) < 0.002 then
        return
    end
    placedLevel = level
    for _, chunk in chunks do
        local c = chunk.centre
        chunk.basePart.CFrame = CFrame.new(c.X, c.Y + level, c.Z)
        chunk.foamPart.CFrame = CFrame.new(c.X, c.Y + level + FOAM_LIFT, c.Z)
        chunk.wavePart.CFrame = CFrame.new(c.X, c.Y + level + WAVE_LIFT, c.Z)
    end
end

-- Surge crest beams, pooled.
local crestAnchor = Instance.new("Part")
crestAnchor.Name = "CrestAnchor"
crestAnchor.Anchored = true
crestAnchor.CanCollide = false
crestAnchor.CanQuery = false
crestAnchor.CanTouch = false
crestAnchor.Transparency = 1
crestAnchor.Size = Vector3.one
crestAnchor.CFrame = CFrame.new()
crestAnchor.Parent = folder
local crestPool = {}
local function crestBeam(index)
    local beam = crestPool[index]
    if beam then
        return beam
    end
    local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
    a0.Parent, a1.Parent = crestAnchor, crestAnchor
    local b = Instance.new("Beam")
    b.Attachment0, b.Attachment1 = a0, a1
    b.Texture = crestTexture
    b.TextureMode = Enum.TextureMode.Stretch
    b.TextureLength = 1
    b.FaceCamera = false
    b.Segments = 1
    b.LightEmission = 0.25
    b.LightInfluence = 0
    b.Color = ColorSequence.new(Color3.fromRGB(244, 252, 255))
    b.Width0, b.Width1 = CREST_WIDTH, CREST_WIDTH
    b.Enabled = false
    b.Parent = crestAnchor
    beam = { beam = b, a0 = a0, a1 = a1 }
    crestPool[index] = beam
    return beam
end

local function updateCrests(state, simple)
    local used = 0
    for _, surge in state.surges do
        local crest = surge.crest
        if crest > 0 and crest < TOTAL + 2 and surge.height > 0.06 then
            -- Preserve the full crest image. Offsetting six full images repeated/squeezed its pattern.
            used+=1
            local pooled=crestBeam(used)
            local frontD,backD=crest+1.6,crest+1.6-CREST_WIDTH
            local frontP,_,r=frameAt(math.clamp(frontD,0,TOTAL))
            local backP=frameAt(math.clamp(backD,0,TOTAL))
            local function height(d)
                if simple then return SURFACE_Y+state.level end
                return SURFACE_Y+math.max(Waves.HeightAt(state,d,-1),Waves.HeightAt(state,d,0),Waves.HeightAt(state,d,1))
            end
            local fy,by=height(frontD),height(backD)
            local clearance=0.22
            for n=1,5 do
                local t=n/6
                clearance=math.max(clearance,height(frontD+(backD-frontD)*t)-(fy+(by-fy)*t)+0.22)
            end
            local front=Vector3.new(frontP.X,fy+clearance,frontP.Z)
            local back=Vector3.new(backP.X,by+clearance,backP.Z)
            local half=Path.WidthAt(math.clamp(crest,0,TOTAL))*0.5+0.2
            local cf=CFrame.fromMatrix((front+back)/2,r,(back-front).Unit)
            pooled.a0.WorldCFrame=cf-r*half
            pooled.a1.WorldCFrame=cf+r*half
            local beam=pooled.beam
            beam.Width0,beam.Width1=(back-front).Magnitude,(back-front).Magnitude
            beam.TextureMode=Enum.TextureMode.Stretch
            beam.TextureLength=1
            beam.TextureSpeed=0
            beam:SetTextureOffset(0)
            beam.Transparency=NumberSequence.new(1-math.clamp(surge.height/Waves.SurgeHeight,0,1))
            beam.Enabled=true
        end
    end
    for i = used + 1, #crestPool do
        crestPool[i].beam.Enabled = false
    end
end

local tideFoam = false
local tideFoamToken = 0
-- Fades the foam out, swaps the foam texture, and fades it back in (LocalTransparencyModifier, so it never fights the
-- real Transparency), instead of changing texture in one frame.
local function setTideFoam(on)
    tideFoam = on
    tideFoamToken += 1
    local token = tideFoamToken
    task.spawn(function()
        local function fade(from, to, seconds)
            local started = os.clock()
            while true do
                local q = math.clamp((os.clock() - started) / seconds, 0, 1)
                q = q * q * (3 - 2 * q)
                for _, chunk in chunks do
                    chunk.foamPart.LocalTransparencyModifier = from + (to - from) * q
                end
                if q >= 1 then
                    return
                end
                RunService.Heartbeat:Wait()
                if token ~= tideFoamToken then
                    return
                end
            end
        end
        fade(0, 1, 0.7)
        if token ~= tideFoamToken then
            return
        end
        for _, chunk in chunks do
            chunk.foamAppearance:Destroy()
            local appearance = (on and templates.RiverTideFoamAppearance or templates.RiverFoamAppearance):Clone()
            appearance.Parent = chunk.foamPart
            chunk.foamAppearance = appearance
        end
        fade(1, 0, 1.1)
    end)
end

local frame = 0
local flowOffset, foamOffset, waveOffset = 0, 0, 0
RunService.RenderStepped:Connect(function(dt)
    frame += 1
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local now = workspace:GetServerTimeNow()
    local state = Waves.State(now)
    -- Texture drift integrates the current, so the ripples race when the high tide speeds the river up.
    flowOffset = (flowOffset + dt * FLOW_SPEED * state.flow) % FLOW_REPEAT
    foamOffset = (foamOffset + dt * FOAM_SPEED * state.flow) % FOAM_REPEAT
    waveOffset = (waveOffset + dt * WAVE_SPEED * state.flow) % WAVE_REPEAT
    local cameraPosition, look = camera.CFrame.Position, camera.CFrame.LookVector
    local simple = WaterQuality.IsSimple(player)
    local started = os.clock()
    local updated, lodCounts = 0, { [0] = 0, [1] = 0, [2] = 0 }
    placeChunks(state.level)
    for _, chunk in chunks do
        local toChunk = chunk.centre - cameraPosition
        local distance = toChunk.Magnitude - CHUNK_ROWS * ROW_SPACING * 0.5
        local lod = distance < LOD_NEAR and 0 or distance < LOD_MID and 1 or 2
        if simple then
            lod = math.max(lod, 1)
        end
        if lod ~= chunk.lod then
            chunk.lod = lod
            -- The ripple sheen layer only shows on full-detail chunks.
            chunk.wavePart.Transparency = lod == 0 and WAVE_TRANSPARENCY or 1
        end
        lodCounts[lod] += 1
        local behind = toChunk:Dot(look) < -BEHIND_MARGIN and distance > 0
        if not behind and (frame + chunk.stagger) % LOD_EVERY[lod] == 0 then
            if lod == 0 then
                updateChunk(chunk, state, flowOffset, foamOffset, waveOffset, cameraPosition)
            else
                if not chunk.flat then
                    flattenChunk(chunk)
                end
                slideChunk(chunk, flowOffset, foamOffset)
            end
            updated += 1
        end
    end
    updateCrests(state, simple)
    if not tideFoam and state.tide > TIDE_FOAM_ON then
        setTideFoam(true)
    elseif tideFoam and state.tide < TIDE_FOAM_OFF then
        setTideFoam(false)
    end
    if frame % 30 == 0 then
        riverRoot:SetAttribute("RiverWaterScriptMs", math.floor((os.clock() - started) * 10000) / 10)
        riverRoot:SetAttribute("RiverWaterDirtyChunks", updated)
        riverRoot:SetAttribute("RiverWaterLOD", ("%d/%d/%d"):format(lodCounts[0], lodCounts[1], lodCounts[2]))
        riverRoot:SetAttribute("RiverWaterSimple", simple)
    end
end)
