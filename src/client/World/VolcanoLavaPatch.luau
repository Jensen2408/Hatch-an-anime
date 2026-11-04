--[[ StarterPlayerScripts.VolcanoLavaPatch (ModuleScript, client only): a small, temporary, animated lava lake.
The same technology as the Arena Brawl's lava sea (ArenaLava): a disc of EditableMesh chunks whose vertices ride a few slow, steep,
peaked waves every frame, with the studded lava textures sliding across it and a translucent vein layer on top. It is used for the
volcano's cutscene: it sits in the caldera, RISES from the crater floor to the opening, and bursts when the volcano blows; the
cutscene destroys it afterwards (Patch:Destroy()), so it never lives longer than the cutscene.

  local patch = LavaPatch.new({ center = Vector3 (x, _, z), radius = 100, level = y, parent = folder, templates = folder })
  patch:SetLevel(y)            -- world height of the surface (move it up to make the lava rise)
  patch:Burst(serverTime)      -- the eruption: the surface swells at the middle and a ring wave runs out
  patch:Step(serverTime)       -- call every frame
  patch:Destroy()

templates must hold the SurfaceAppearances "LavaBaseAppearance" and "LavaFlowAppearance" (scripts cannot set maps).
Chunks are built over a few frames (CreateEditableMeshAsync yields); patch.Ready turns true when all are in. ]]
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

local TAU = math.pi * 2
local CELL = 5 -- studs between vertices
local CHUNK_CELLS = 8 -- cells per chunk edge (40 studs)
local BASE_TILE, FLOW_TILE = 64, 48
local BASE_SPEED, FLOW_SPEED = Vector2.new(2.2, 1.1), Vector2.new(3.2, -1.3)
local FLOW_ANGLE = math.rad(37)
local BURST_SECONDS = 4

-- slow, steep trains, a little smaller than the arena's (the lake is only about 200 studs across)
local waveSpecs = {
    { angle = 8, length = 70, height = 1.8, phase = 0.4 },
    { angle = 64, length = 46, height = 1.2, phase = 2.2 },
    { angle = -47, length = 32, height = 0.7, phase = 4.1 },
    { angle = 118, length = 21, height = 0.4, phase = 1.3 },
}
local waves = {}
for index, spec in waveSpecs do
    local a = math.rad(spec.angle)
    local k = TAU / spec.length
    waves[index] = {
        dx = math.cos(a),
        dz = math.sin(a),
        k = k,
        w = math.sqrt(6 * k),
        a = spec.height,
        p = spec.phase,
        set = 0.11 + index * 0.017,
    }
end
local PEAK = 2.2 -- crest sharpening: height = a * (PEAK * s^2 - 0.8)

local Patch = {}
Patch.__index = Patch

local function newMeshPart(mesh, position, name)
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
    part.CFrame = CFrame.new(position)
    return part
end

local function buildChunk(self, cx, cz, index)
    local em = AssetService:CreateEditableMesh()
    assert(em, "Lava patch memory unavailable")
    local half = CHUNK_CELLS * CELL / 2
    local verts, ids = {}, {}
    for row = 0, CHUNK_CELLS do
        for column = 0, CHUNK_CELLS do
            local lx, lz = -half + column * CELL, -half + row * CELL
            local vert = { lx = lx, lz = lz, wx = cx + lx, wz = cz + lz, key = tostring(Vector3.new(lx, 0, lz)), ph = table.create(#waves) }
            ids[vert] = { em:AddVertex(Vector3.new(lx, 0, lz)), em:AddNormal(Vector3.yAxis), em:AddUV(Vector2.zero) }
            table.insert(verts, vert)
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
        assert(copy, "Lava patch memory unavailable")
        local byPosition = {}
        for _, id in copy:GetVertices() do
            byPosition[tostring(copy:GetPosition(id))] = id
        end
        return copy, byPosition
    end
    local base, baseIds = fixedCopy()
    local flow, flowIds = fixedCopy()
    em:Destroy()
    for _, vert in verts do
        local id, fid = baseIds[vert.key], flowIds[vert.key]
        vert.id, vert.nid, vert.uv = id, base:GetVertexNormals(id)[1], base:GetVertexUVs(id)[1]
        vert.fid, vert.fnid, vert.fuv = fid, flow:GetVertexNormals(fid)[1], flow:GetVertexUVs(fid)[1]
    end
    local origin = Vector3.new(cx, self.level, cz)
    local basePart = newMeshPart(base, origin, "PatchLava" .. index)
    basePart.Color = Color3.fromRGB(205, 150, 130)
    self.templates.LavaBaseAppearance:Clone().Parent = basePart
    local flowPart = newMeshPart(flow, origin + Vector3.new(0, 0.4, 0), "PatchLavaFlow" .. index)
    flowPart.Transparency = 0.7
    self.templates.LavaFlowAppearance:Clone().Parent = flowPart
    basePart.Parent = self.folder
    flowPart.Parent = self.folder
    return { base = base, flow = flow, verts = verts, cx = cx, cz = cz, basePart = basePart, flowPart = flowPart }
end

function Patch.new(options)
    local self = setmetatable({
        center = options.center,
        radius = options.radius or 100,
        level = options.level or options.center.Y,
        templates = options.templates,
        chunks = {},
        ready = false,
        destroyed = false,
        burstAt = nil,
        burstScale = 1,
    }, Patch)
    self.folder = Instance.new("Folder")
    self.folder.Name = "VolcanoLavaPatchLocal"
    self.folder.Parent = options.parent or workspace
    task.spawn(function()
        local span = CHUNK_CELLS * CELL
        local count = math.ceil(self.radius * 2 / span)
        local start = -count * span / 2 + span / 2
        local made = 0
        for i = 0, count - 1 do
            for j = 0, count - 1 do
                local cx = self.center.X + start + i * span
                local cz = self.center.Z + start + j * span
                local nearestX = math.max(math.abs(cx - self.center.X) - span / 2, 0)
                local nearestZ = math.max(math.abs(cz - self.center.Z) - span / 2, 0)
                if math.sqrt(nearestX * nearestX + nearestZ * nearestZ) < self.radius then
                    if self.destroyed then
                        return
                    end
                    local ok, chunk = pcall(buildChunk, self, cx, cz, made + 1)
                    if ok then
                        table.insert(self.chunks, chunk)
                    else
                        warn("[VolcanoLavaPatch] chunk failed:", chunk)
                    end
                    made += 1
                    if made % 3 == 0 then
                        RunService.Heartbeat:Wait()
                    end
                end
            end
        end
        self.ready = true
    end)
    return self
end

function Patch:SetLevel(y)
    self.level = y
end

function Patch:Burst(serverTime)
    self.burstAt = serverTime
end

-- the burst: the surface swells in the middle and a ring runs outward (one event, like the arena's eruptions)
function Patch:_burstHeight(x, z, t)
    if not self.burstAt then
        return 0
    end
    local age = t - self.burstAt
    if age < 0 or age > BURST_SECONDS then
        return 0
    end
    local dx, dz = x - self.center.X, z - self.center.Z
    local d2 = dx * dx + dz * dz
    local d = math.sqrt(d2)
    local front = d - 22 * age
    return 9 * math.exp(-5 * age) * math.exp(-d2 / 1800)
        + 3 * math.sin(0.5 * front) * math.exp(-(front * front) / 196) * math.exp(-0.7 * age)
end

local flowCos, flowSin = math.cos(FLOW_ANGLE), math.sin(FLOW_ANGLE)
function Patch:Step(serverTime)
    if self.destroyed then
        return
    end
    local t = serverTime
    local amplitude, timePhase = table.create(#waves), table.create(#waves)
    for i, w in waves do
        amplitude[i] = w.a * (0.8 + 0.2 * math.sin(t * w.set + i * 2.1))
        timePhase[i] = -w.w * t
    end
    local baseU, baseV = (BASE_SPEED.X * t) % BASE_TILE, (BASE_SPEED.Y * t) % BASE_TILE
    local flowU, flowV = (FLOW_SPEED.X * t) % FLOW_TILE, (FLOW_SPEED.Y * t) % FLOW_TILE
    local count = #waves
    for _, chunk in self.chunks do
        chunk.basePart.CFrame = CFrame.new(chunk.cx, self.level, chunk.cz)
        chunk.flowPart.CFrame = CFrame.new(chunk.cx, self.level + 0.4, chunk.cz)
        local base, flow = chunk.base, chunk.flow
        for _, v in chunk.verts do
            local y, dydx, dydz = 0, 0, 0
            local phases = v.ph
            for i = 1, count do
                local w = waves[i]
                local phase = phases[i] + timePhase[i]
                local s = math.sin(phase) * 0.5 + 0.5
                local a = amplitude[i]
                y += a * (PEAK * s * s - 0.8)
                local slope = PEAK * a * s * math.cos(phase) * w.k * 2
                dydx += slope * w.dx
                dydz += slope * w.dz
            end
            y += self:_burstHeight(v.wx, v.wz, t)
            local normal = Vector3.new(-dydx, 1, -dydz).Unit
            local position = Vector3.new(v.lx, y, v.lz)
            base:SetPosition(v.id, position)
            base:SetNormal(v.nid, normal)
            flow:SetPosition(v.fid, position)
            flow:SetNormal(v.fnid, normal)
            local rx, rz = v.wx - self.center.X, v.wz - self.center.Z
            base:SetUV(v.uv, Vector2.new((rx - baseU) / BASE_TILE, (rz - baseV) / BASE_TILE))
            local ru = rx * flowCos + rz * flowSin
            local rv = -rx * flowSin + rz * flowCos
            flow:SetUV(v.fuv, Vector2.new((ru - flowU) / FLOW_TILE, (rv - flowV) / FLOW_TILE))
        end
    end
end

function Patch:Destroy()
    self.destroyed = true
    if self.folder then
        self.folder:Destroy()
        self.folder = nil
    end
    table.clear(self.chunks)
end

return Patch
