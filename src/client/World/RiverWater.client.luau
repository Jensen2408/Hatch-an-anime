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
-- Level of detail, per chunk, from the camera distance to the chunk's nearest water:
--   LOD 0  < LOD_NEAR  full grid (rows every 2 studs, 8 quads across), full waves: heights, normals and all three
--                      layers every frame
--   LOD 1  < LOD_MID   coarse flat mesh (rows up to 8 studs apart, 2 quads across), base + foam only, textures slide
--                      every 2 frames
--   LOD 2  beyond      coarser flat mesh (rows up to 30 studs apart, 1 quad across), textures slide every 6 frames
-- Each chunk owns one mesh set per level and shows one of them. The coarse rows are picked from the full grid's rows
-- (fewer where the river bends, so the edges stay under the bank overhang), and every level keeps the full 9-vertex
-- end rows, zipped to its coarse interior, so neighbouring chunks share identical seam vertices at any mix of levels:
-- no T-junction cracks. The waves fade to flat by LOD_NEAR from the camera and a chunk only leaves LOD 0 once all of
-- it is that far away, so a level switch only ever swaps one flat surface for another (no popping). A level is
-- updated in the frame it is switched to, and all chunks of a level update on the same frames, so the sliding
-- textures line up across seams.
-- Chunks behind the camera are not updated at all. The tide's rise moves the chunk parts instead of their vertices, so
-- it shows at every LOD for the cost of a few CFrame writes per chunk. Simple Water (WaterQuality, the Settings panel)
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
local CHUNK_ROWS = 30 -- rows per chunk (60 studs; VolcanoEventClient gives each chunk a lava light, steam and sound)
local LOD_NEAR = 120 -- closer than this (camera to the chunk's nearest water): full waves (LOD 0)
local LOD_MID = 280 -- closer than this: coarse flat, textures every 2 frames (LOD 1); beyond: every 6 frames (LOD 2)
local LOD_HYSTERESIS = 10 -- studs past a threshold before a chunk switches to the coarser level
local LOD_EVERY = { [0] = 1, [1] = 2, [2] = 6 }
-- Coarse meshes: at most maxStep full-grid rows per coarse row, fewer where the edges would stray more than
-- `tolerance` studs from the full ribbon (it reaches OVERHANG under the bank), and `columns` quads across.
local COARSE_LEVELS = {
    [1] = { maxStep = 4, tolerance = 0.15, columns = 2 },
    [2] = { maxStep = 15, tolerance = 0.3, columns = 1 },
}
-- A chunk whose bounding sphere is wholly outside the camera's view is not updated. It is brought up to date in the
-- first frame it comes back into view, before that frame renders, and a seam it shares is out of view with it.
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
                row = i,
                column = c,
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

-- Triangles for a strip of grid rows. pickedRows are row numbers (first and last always included); the end rows keep
-- all COLUMNS + 1 nodes and the rows between them every `step`th column. Two neighbouring rows are zipped together by
-- their columns (rows are straight lines across the river, so any column mix tiles the strip with no gaps), wound to
-- face up like the full grid. Returns the nodes used and the triangles as index triples into them.
local function gridTriangles(pickedRows, step)
    local nodes, index, triangles = {}, {}, {}
    local function idx(n)
        local k = index[n]
        if not k then
            table.insert(nodes, n)
            k = #nodes
            index[n] = k
        end
        return k
    end
    local function columnsOf(position)
        local list = {}
        for c = 0, COLUMNS, (position == 1 or position == #pickedRows) and 1 or step do
            table.insert(list, c)
        end
        return list
    end
    for p = 1, #pickedRows - 1 do
        local top, bottom = rows[pickedRows[p]], rows[pickedRows[p + 1]]
        local T, B = columnsOf(p), columnsOf(p + 1)
        local i, j = 1, 1
        while i < #T or j < #B do
            if j >= #B or (i < #T and T[i + 1] <= B[j + 1]) then
                table.insert(triangles, { idx(top[T[i]]), idx(top[T[i + 1]]), idx(bottom[B[j]]) })
                i += 1
            else
                table.insert(triangles, { idx(top[T[i]]), idx(bottom[B[j + 1]]), idx(bottom[B[j]]) })
                j += 1
            end
        end
    end
    return nodes, triangles
end

-- Rows for a coarse level: from each picked row, reach as far as maxStep rows while both edges and the centre line of
-- every skipped row stay within `tolerance` studs of the straight line between the picked rows.
local function coarseRows(firstRow, lastRow, level)
    local function straightEnough(a, b)
        local da, db = rows[a][0].d, rows[b][0].d
        for k = a + 1, b - 1 do
            local f = (rows[k][0].d - da) / (db - da)
            for _, c in { 0, COLUMNS // 2, COLUMNS } do
                local na, nb, nk = rows[a][c], rows[b][c], rows[k][c]
                local dx = na.x + (nb.x - na.x) * f - nk.x
                local dz = na.z + (nb.z - na.z) * f - nk.z
                if dx * dx + dz * dz > level.tolerance * level.tolerance then
                    return false
                end
            end
        end
        return true
    end
    local picked = { firstRow }
    local a = firstRow
    while a < lastRow do
        local b = math.min(a + level.maxStep, lastRow)
        while b > a + 1 and not straightEnough(a, b) do
            b -= 1
        end
        table.insert(picked, b)
        a = b
    end
    return picked
end

-- Builds `copies` fixed-size EditableMeshes of the given nodes and triangles, laid flat around their own centre (a new
-- MeshPart centres itself on its mesh bounds). Growable meshes reserve far more memory than they use and the client
-- runs out after a few, so the mesh is built once growable and copied; copies may renumber vertices, so each vertex is
-- found again by its rest position (unique within a mesh). Returns verts (node, offsets and per-copy ids), the copies
-- and the centre.
local function buildMeshes(nodes, triangles, copies)
    local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
    for _, n in nodes do
        minX, maxX = math.min(minX, n.x), math.max(maxX, n.x)
        minZ, maxZ = math.min(minZ, n.z), math.max(maxZ, n.z)
    end
    local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
    local em = AssetService:CreateEditableMesh()
    assert(em, "River mesh memory unavailable")
    local verts, ids = table.create(#nodes), table.create(#nodes)
    for k, n in nodes do
        local rest = Vector3.new(n.x - cx, 0, n.z - cz)
        verts[k] = { node = n, row = n.row, column = n.column, lx = rest.X, lz = rest.Z, key = tostring(rest) }
        ids[k] = { em:AddVertex(rest), em:AddNormal(Vector3.yAxis), em:AddUV(Vector2.zero) }
    end
    for _, t in triangles do
        local a, b, c = ids[t[1]], ids[t[2]], ids[t[3]]
        local f = em:AddTriangle(a[1], b[1], c[1])
        em:SetFaceNormals(f, { a[2], b[2], c[2] })
        em:SetFaceUVs(f, { a[3], b[3], c[3] })
    end
    local meshes = {}
    local ok, err = pcall(function()
        for m = 1, copies do
            local copy = AssetService:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true })
            assert(copy, "River mesh memory unavailable")
            meshes[m] = copy
            local byPosition = {}
            for _, id in copy:GetVertices() do
                byPosition[tostring(copy:GetPosition(id))] = id
            end
            for _, vert in verts do
                local id = byPosition[vert.key]
                vert[m] = { id, copy:GetVertexNormals(id)[1], copy:GetVertexUVs(id)[1] }
            end
        end
    end)
    em:Destroy()
    if not ok then
        for _, copy in meshes do
            copy:Destroy()
        end
        error(err)
    end
    return verts, meshes, Vector3.new(cx, SURFACE_Y, cz)
end

local function buildChunk(firstRow, lastRow, index)
    local allRows = {}
    for i = firstRow, lastRow do
        table.insert(allRows, i)
    end
    local nodes, triangles = gridTriangles(allRows, 1)
    local verts, meshes, centre = buildMeshes(nodes, triangles, 3)
    local base, foam, wave = meshes[1], meshes[2], meshes[3]
    for _, vert in verts do
        vert.id, vert.nid, vert.uv = vert[1][1], vert[1][2], vert[1][3]
        vert.fid, vert.fnid, vert.fuv = vert[2][1], vert[2][2], vert[2][3]
        vert.wid, vert.wnid, vert.wuv = vert[3][1], vert[3][2], vert[3][3]
    end
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

    -- Points for the LOD distance: the centre line every 3 rows plus the last row; any water in the chunk is within
    -- `samplePad` of one of them.
    local samples, widest = {}, 0
    for i = firstRow, lastRow do
        if (i - firstRow) % 3 == 0 or i == lastRow then
            local n = rows[i][COLUMNS // 2]
            table.insert(samples, Vector3.new(n.x, SURFACE_Y, n.z))
        end
        widest = math.max(widest, rows[i][0].wallHalf)
    end
    -- Bounding sphere for the view test: every vertex, plus room for the waves, the tide and the layers above.
    local radius = 0
    for _, n in nodes do
        radius = math.max(radius, Vector2.new(n.x - centre.X, n.z - centre.Z).Magnitude)
    end

    local chunk = {
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
        samples = samples,
        samplePad = widest + OVERHANG + ROW_SPACING * 1.5,
        radius = radius + 4,
        triangles = { [0] = #triangles },
        vertices = { [0] = #verts },
        levels = {},
    }

    -- Coarse flat levels (base + foam only). If one can't be built the chunk falls back to flattening its full mesh.
    for lod, level in COARSE_LEVELS do
        local built = pcall(function()
            local coarseNodes, coarseTriangles = gridTriangles(coarseRows(firstRow, lastRow, level), COLUMNS // level.columns)
            local coarseVerts, coarseMeshes, coarseCentre = buildMeshes(coarseNodes, coarseTriangles, 2)
            for _, vert in coarseVerts do
                vert.uv, vert.fuv = vert[1][3], vert[2][3]
            end
            local coarseBase = newMeshPart(coarseMeshes[1], coarseCentre, ("RiverCoarseWater%d_%d"):format(lod, index))
            coarseBase.Color = waterColor
            coarseBase.Transparency = 1
            templates.RiverFlowAppearance:Clone().Parent = coarseBase
            local coarseFoam = newMeshPart(
                coarseMeshes[2],
                coarseCentre + Vector3.new(0, FOAM_LIFT, 0),
                ("RiverCoarseFoam%d_%d"):format(lod, index)
            )
            coarseFoam.Color = Color3.new(1, 1, 1)
            coarseFoam.Transparency = 1
            local coarseAppearance = templates.RiverFoamAppearance:Clone()
            coarseAppearance.Parent = coarseFoam
            coarseBase.Parent = folder
            coarseFoam.Parent = folder
            chunk.levels[lod] = {
                base = coarseMeshes[1],
                foam = coarseMeshes[2],
                basePart = coarseBase,
                foamPart = coarseFoam,
                foamAppearance = coarseAppearance,
                verts = coarseVerts,
                centre = coarseCentre,
                baseModifier = 0,
                foamModifier = 0,
            }
            chunk.triangles[lod] = #coarseTriangles
            chunk.vertices[lod] = #coarseVerts
        end)
        if not built then
            chunk.levels = {} -- all or nothing, so the fallback path stays simple
            break
        end
    end
    return chunk
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
    local calls = 0 -- mesh writes, for the debug counter
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
        -- Past the wave fade a vertex is flat and stays flat: its position and normal are written once, then only its
        -- texture coordinates move.
        if n.h ~= 0 or slopeAlong ~= 0 or slopeAcross ~= 0 or not v.flat then
            local position = Vector3.new(v.lx, n.h, v.lz)
            base:SetPosition(v.id, position)
            base:SetNormal(v.nid, normal)
            foam:SetPosition(v.fid, position)
            foam:SetNormal(v.fnid, normal)
            wave:SetPosition(v.wid, position)
            wave:SetNormal(v.wnid, normal)
            v.flat = n.h == 0 and slopeAlong == 0 and slopeAcross == 0
            calls += 6
        end
        calls += 3
        base:SetUV(v.uv, Vector2.new(n.lateral / FLOW_REPEAT, (n.d - flowOffset) / FLOW_REPEAT))
        foam:SetUV(v.fuv, Vector2.new(0.5 + n.lateral / (2 * n.wallHalf), (n.d - foamOffset) / FOAM_REPEAT))
        -- Wave layer: the same surface, its ripples turned WAVE_ANGLE off the current so they cross the base layer's.
        wave:SetUV(
            v.wuv,
            Vector2.new(
                (n.lateral * WAVE_COS + n.d * WAVE_SIN) / WAVE_REPEAT,
                (n.d * WAVE_COS - n.lateral * WAVE_SIN - waveOffset) / WAVE_REPEAT
            )
        )
    end
    return calls
end

-- LOD 1 and 2 show the chunk's coarse flat meshes, which only slide their textures (slideChunk on chunk.levels[lod]).
-- Fallback if those couldn't be built: lay the full mesh flat once, then only slide its textures (two writes per
-- vertex instead of nine; the hidden wave layer is left alone).
local function flattenChunk(chunk)
    local base, foam = chunk.base, chunk.foam
    for _, v in chunk.verts do
        local position = Vector3.new(v.lx, 0, v.lz)
        base:SetPosition(v.id, position)
        base:SetNormal(v.nid, Vector3.yAxis)
        foam:SetPosition(v.fid, position)
        foam:SetNormal(v.fnid, Vector3.yAxis)
        v.flat = false -- the hidden wave layer isn't flattened, so updateChunk rewrites everything when LOD 0 returns
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
        for _, coarse in chunk.levels do
            local cc = coarse.centre
            coarse.basePart.CFrame = CFrame.new(cc.X, cc.Y + level, cc.Z)
            coarse.foamPart.CFrame = CFrame.new(cc.X, cc.Y + level + FOAM_LIFT, cc.Z)
        end
    end
end

-- Shows one level's parts and hides the others'. Hidden parts stay parented (VolcanoEventClient finds the full ones by
-- name and builds its lava overlay from them).
local function showLevel(chunk, lod)
    local coarse = chunk.levels[lod]
    local full = lod == 0 or not coarse
    chunk.basePart.Transparency = full and WATER_TRANSPARENCY or 1
    chunk.foamPart.Transparency = full and 0 or 1
    chunk.wavePart.Transparency = lod == 0 and WAVE_TRANSPARENCY or 1
    for k, level in chunk.levels do
        level.basePart.Transparency = k == lod and WATER_TRANSPARENCY or 1
        level.foamPart.Transparency = k == lod and 0 or 1
    end
end

-- The tide foam swap and VolcanoEventClient fade the full parts through LocalTransparencyModifier; a shown coarse
-- level copies it (written only when it changes).
local function mirrorModifiers(chunk, coarse)
    local b, f = chunk.basePart.LocalTransparencyModifier, chunk.foamPart.LocalTransparencyModifier
    if b ~= coarse.baseModifier then
        coarse.baseModifier = b
        coarse.basePart.LocalTransparencyModifier = b
    end
    if f ~= coarse.foamModifier then
        coarse.foamModifier = f
        coarse.foamPart.LocalTransparencyModifier = f
    end
end

-- Camera distance to the chunk's nearest water (never more than the true distance).
local function chunkDistance(chunk, cameraPosition)
    local nearest = math.huge
    for _, p in chunk.samples do
        nearest = math.min(nearest, (p - cameraPosition).Magnitude)
    end
    return nearest - chunk.samplePad
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
            for _, coarse in chunk.levels do
                coarse.foamAppearance:Destroy()
                local coarseAppearance = appearance:Clone()
                coarseAppearance.Parent = coarse.foamPart
                coarse.foamAppearance = coarseAppearance
            end
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
    local right, up = camera.CFrame.RightVector, camera.CFrame.UpVector
    -- View frustum half-angles (the side planes pass through the camera).
    local halfV = math.rad(camera.FieldOfView) * 0.5
    local viewport = camera.ViewportSize
    local halfH = math.atan(math.tan(halfV) * viewport.X / math.max(viewport.Y, 1))
    local cosV, sinV, cosH, sinH = math.cos(halfV), math.sin(halfV), math.cos(halfH), math.sin(halfH)
    local simple = WaterQuality.IsSimple(player)
    local started = os.clock()
    local updated, lodCounts = 0, { [0] = 0, [1] = 0, [2] = 0 }
    local shownTriangles, vertexWrites = 0, 0 -- debug: triangles on show (all layers), mesh writes this frame
    placeChunks(state.level)
    for _, chunk in chunks do
        local distance = chunkDistance(chunk, cameraPosition)
        local current = chunk.lod
        local lod = distance < LOD_NEAR and 0 or distance < LOD_MID and 1 or 2
        if lod > current then
            -- Coarser only once LOD_HYSTERESIS past the threshold, so a chunk on the line doesn't flicker between levels.
            local held = distance < LOD_NEAR + LOD_HYSTERESIS and 0 or distance < LOD_MID + LOD_HYSTERESIS and 1 or 2
            lod = math.max(current, held)
        end
        if simple then
            lod = math.max(lod, 1)
        end
        local switched = lod ~= current
        chunk.lod = lod
        lodCounts[lod] += 1
        local coarse = lod > 0 and chunk.levels[lod] or nil
        local behind
        do
            local rel, radius = chunk.centre - cameraPosition, chunk.radius
            local z = rel:Dot(look)
            behind = z < -radius
                or math.abs(rel:Dot(right)) * cosH - z * sinH > radius
                or math.abs(rel:Dot(up)) * cosV - z * sinV > radius
        end
        -- Every chunk of a level updates on the same frames (no stagger), so textures meet across seams. The level a
        -- chunk switches to is brought up to date before it shows.
        if switched or (not behind and frame % LOD_EVERY[lod] == 0) then
            if lod == 0 then
                vertexWrites += updateChunk(chunk, state, flowOffset, foamOffset, waveOffset, cameraPosition)
            elseif coarse then
                slideChunk(coarse, flowOffset, foamOffset)
                vertexWrites += #coarse.verts * 2
            else
                if not chunk.flat then
                    flattenChunk(chunk)
                end
                slideChunk(chunk, flowOffset, foamOffset)
                vertexWrites += #chunk.verts * 2
            end
            updated += 1
        end
        if switched then
            showLevel(chunk, lod)
        end
        if coarse then
            mirrorModifiers(chunk, coarse)
            shownTriangles += chunk.triangles[lod] * 2
        else
            shownTriangles += chunk.triangles[0] * (lod == 0 and 3 or 2)
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
        riverRoot:SetAttribute("RiverWaterTriangles", shownTriangles)
        riverRoot:SetAttribute("RiverWaterVertexWrites", vertexWrites)
    end
end)
