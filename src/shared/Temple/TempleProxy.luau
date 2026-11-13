-- ReplicatedStorage.TempleProxy (client module, used by StarterPlayerScripts.TempleLOD): builds the far-LOD stand-in for a plot temple.
--
-- The temple meshes are cut into one quad per texture tile and every MeshPart has its own SurfaceAppearance, so a far
-- temple costs ~20k triangles and ~260 draw calls. The proxy is ONE vertex-coloured MeshPart built from
-- ReplicatedStorage.TempleProxyMeshes: per MeshId, the mesh's faces merged plane by plane into rectangles and coloured
-- with the average of their texture tile (baked in Studio by tools/temple_lod/bake_temple_proxies.luau, because game
-- scripts cannot read SurfaceAppearance maps). The outline (roof tiers, posts, rafters, steps) is kept.
--
-- Parts without baked data (new meshes, not re-baked yet) are left out of the proxy and stay visible as they are, so
-- a missing bake costs savings, never looks. Identical temples share one mesh (see `shared` below).
local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TempleProxy = {}

local MAX_TRIANGLES = 19000 -- per EditableMesh (engine limit 20k); a temple that needs more gets several parts
local MIN_PART_SIZE = 4 -- smaller parts (largest dimension) are hidden, not drawn: TempleLOD hides them at LOD 2 anyway
local YIELD_EVERY = 1500 -- quads between task.wait()s while building

local data
local function getData()
    if data == nil then
        local module = ReplicatedStorage:FindFirstChild("TempleProxyMeshes")
        local ok, result = pcall(function()
            return module and require(module)
        end)
        data = ok and result or false
        if not ok then
            warn("[TempleProxy] TempleProxyMeshes failed to load:", result)
        end
    end
    return data
end

-- base64 -> buffer, decoded once per MeshId
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup = {}
for i = 1, 64 do
    lookup[string.byte(B64, i)] = i - 1
end
local function decode(text)
    local len = #text
    local pad = (string.sub(text, -2) == "==" and 2) or (string.sub(text, -1) == "=" and 1) or 0
    local buf = buffer.create(len // 4 * 3 - pad)
    local o = 0
    for i = 1, len, 4 do
        local a, b, c, d = string.byte(text, i, i + 3)
        local n = lookup[a] * 262144 + lookup[b] * 4096 + (lookup[c] or 0) * 64 + (lookup[d] or 0)
        buffer.writeu8(buf, o, n // 65536)
        if o + 1 < buffer.len(buf) then
            buffer.writeu8(buf, o + 1, (n // 256) % 256)
        end
        if o + 2 < buffer.len(buf) then
            buffer.writeu8(buf, o + 2, n % 256)
        end
        o += 3
    end
    return buf
end

local decoded = {} -- [MeshId] = { meshSize, buf } or false
local function meshRecord(meshId)
    local cached = decoded[meshId]
    if cached ~= nil then
        return cached
    end
    local all = getData()
    local entry = all and all.Meshes and all.Meshes[meshId]
    local record = false
    if entry then
        record = { meshSize = Vector3.new(entry[1], entry[2], entry[3]), buf = decode(entry[4]) }
    end
    decoded[meshId] = record
    return record
end

function TempleProxy.Available()
    return getData() and true or false
end

-- Colour multiplier for a part's tint: themes tint SurfaceAppearance.Color (Jade, Sakura, ...); Royal Gold swaps the
-- SurfaceAppearance for a gold preset and sets a Metal gold Color, which the luminance-times-colour below follows.
local function tintFor(part)
    if part.Material == Enum.Material.Metal then
        return part.Color, true
    end
    local sa = part:FindFirstChildOfClass("SurfaceAppearance")
    local ok, color = pcall(function()
        return sa and sa.Color
    end)
    return (ok and color) or Color3.new(1, 1, 1), false
end

local BOX_FACES = { -- normal, then 4 corner sign triples wound counter-clockwise around it
    { Vector3.new(1, 0, 0), { { 1, -1, -1 }, { 1, 1, -1 }, { 1, 1, 1 }, { 1, -1, 1 } } },
    { Vector3.new(-1, 0, 0), { { -1, -1, 1 }, { -1, 1, 1 }, { -1, 1, -1 }, { -1, -1, -1 } } },
    { Vector3.new(0, 1, 0), { { -1, 1, -1 }, { -1, 1, 1 }, { 1, 1, 1 }, { 1, 1, -1 } } },
    { Vector3.new(0, -1, 0), { { -1, -1, 1 }, { -1, -1, -1 }, { 1, -1, -1 }, { 1, -1, 1 } } },
    { Vector3.new(0, 0, 1), { { 1, -1, 1 }, { 1, 1, 1 }, { -1, 1, 1 }, { -1, -1, 1 } } },
    { Vector3.new(0, 0, -1), { { -1, -1, -1 }, { -1, 1, -1 }, { 1, 1, -1 }, { 1, -1, -1 } } },
}

-- Collects quads ({ c1, c2, c3, c4, normal, color }) in the temple's pivot space, then cuts them into EditableMeshes.
local function newBuilder()
    return { quads = {}, min = Vector3.one * math.huge, max = Vector3.one * -math.huge }
end

local function addQuad(builder, a, b, c, d, color)
    local normal = (b - a):Cross(c - a)
    if normal.Magnitude < 1e-6 then
        return
    end
    table.insert(builder.quads, { a, b, c, d, normal.Unit, color })
    builder.min = builder.min:Min(a):Min(b):Min(c):Min(d)
    builder.max = builder.max:Max(a):Max(b):Max(c):Max(d)
end

local function addMeshPart(builder, part, record, relative)
    local buf = record.buf
    local count = buffer.readu16(buf, 0)
    local meshSize = record.meshSize
    local scale = Vector3.new(
        meshSize.X > 0 and part.Size.X / meshSize.X or 1,
        meshSize.Y > 0 and part.Size.Y / meshSize.Y or 1,
        meshSize.Z > 0 and part.Size.Z / meshSize.Z or 1
    ) / 256
    local tint, gold = tintFor(part)
    local o = 2
    local corners = table.create(4)
    for _ = 1, count do
        -- stored: corners 1, 2, 4 of a rectangle; corner 3 = 2 + 4 - 1 (in mesh space, before the part's scale)
        local m = table.create(3)
        for i = 1, 3 do
            m[i] = Vector3.new(buffer.readi16(buf, o), buffer.readi16(buf, o + 2), buffer.readi16(buf, o + 4))
            o += 6
        end
        corners[1] = relative * (m[1] * scale)
        corners[2] = relative * (m[2] * scale)
        corners[3] = relative * ((m[2] + m[3] - m[1]) * scale)
        corners[4] = relative * (m[3] * scale)
        local r, g, b = buffer.readu8(buf, o) / 255, buffer.readu8(buf, o + 1) / 255, buffer.readu8(buf, o + 2) / 255
        o += 3
        local color
        if gold then
            local lum = 0.45 + 0.9 * (0.299 * r + 0.587 * g + 0.114 * b)
            color = Color3.new(math.min(tint.R * lum, 1), math.min(tint.G * lum, 1), math.min(tint.B * lum, 1))
        else
            color = Color3.new(r * tint.R, g * tint.G, b * tint.B)
        end
        addQuad(builder, corners[1], corners[2], corners[3], corners[4], color)
    end
    return count
end

local function addBox(builder, part, relative)
    local half = part.Size / 2
    for _, face in BOX_FACES do
        local c = {}
        for i, s in face[2] do
            c[i] = relative * Vector3.new(half.X * s[1], half.Y * s[2], half.Z * s[3])
        end
        addQuad(builder, c[1], c[2], c[3], c[4], part.Color)
    end
end

-- Template MeshParts, each with its pivot-space offset in the attribute ProxyOffset; each temple clones them.
local function buildMeshes(builder, name)
    local centre = (builder.min + builder.max) / 2
    local parts, meshes = {}, {}
    local index = 1
    local quads = builder.quads
    while index <= #quads do
        local em = AssetService:CreateEditableMesh()
        local triangles = 0
        while index <= #quads and triangles + 2 <= MAX_TRIANGLES do
            local q = quads[index]
            local v1 = em:AddVertex(q[1] - centre)
            local v2 = em:AddVertex(q[2] - centre)
            local v3 = em:AddVertex(q[3] - centre)
            local v4 = em:AddVertex(q[4] - centre)
            local n = em:AddNormal(q[5])
            local c = em:AddColor(q[6], 1)
            local f1 = em:AddTriangle(v1, v2, v3)
            local f2 = em:AddTriangle(v1, v3, v4)
            em:SetFaceNormals(f1, { n, n, n })
            em:SetFaceNormals(f2, { n, n, n })
            em:SetFaceColors(f1, { c, c, c })
            em:SetFaceColors(f2, { c, c, c })
            triangles += 2
            index += 1
            if index % YIELD_EVERY == 0 then
                task.wait()
            end
        end
        local part = AssetService:CreateMeshPartAsync(
            Content.fromObject(em),
            { CollisionFidelity = Enum.CollisionFidelity.Box, RenderFidelity = Enum.RenderFidelity.Precise }
        )
        part.Name = name
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Material = Enum.Material.SmoothPlastic
        part.Color = Color3.new(1, 1, 1)
        part:SetAttribute("ProxyOffset", CFrame.new(centre))
        table.insert(parts, part)
        table.insert(meshes, em)
    end
    return parts, meshes
end

-- Identical temples (same level, theme and layout) share ONE set of EditableMeshes: the client's EditableMesh memory
-- budget is shared with the river water and runs out after ~6 separate temple proxies. Keyed by a signature of every
-- drawn part's mesh, pivot-space CFrame, size and colour.
local shared = {} -- [signature] = { templates, meshes, triangles, refs }

local function round(x)
    return math.round(x * 100) / 100
end

local function partSignature(part, relative, tint)
    local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = relative:GetComponents()
    local s = part.Size
    return string.format(
        "%s|%g,%g,%g|%g,%g,%g,%g,%g,%g,%g,%g,%g|%g,%g,%g|%s|%s",
        part:IsA("MeshPart") and part.MeshId or "box",
        round(x), round(y), round(z),
        round(r00), round(r01), round(r02), round(r10), round(r11), round(r12), round(r20), round(r21), round(r22),
        round(s.X), round(s.Y), round(s.Z),
        tostring(tint), part.Material.Name
    )
end

-- Builds the proxy for `model`. Returns { parts, covered = { [BasePart] = true }, triangles, signature } or nil.
-- Yields. Release it with TempleProxy.Destroy.
function TempleProxy.Build(model)
    if not getData() then
        return nil
    end
    local origin = model:GetPivot()
    local covered = {}
    local drawn = {} -- { part, relative, record or false (box), signature }
    for _, part in model:GetDescendants() do
        if part:IsA("BasePart") and part.Transparency < 0.95 then
            local size = part.Size
            if math.max(size.X, size.Y, size.Z) >= MIN_PART_SIZE then
                local relative = origin:ToObjectSpace(part.CFrame)
                if part:IsA("MeshPart") then
                    local record = meshRecord(part.MeshId)
                    if record then
                        covered[part] = true
                        table.insert(drawn, { part, relative, record, partSignature(part, relative, (tintFor(part))) })
                    end
                elseif part.ClassName == "Part" and part.Shape == Enum.PartType.Block then
                    covered[part] = true
                    table.insert(drawn, { part, relative, false, partSignature(part, relative, part.Color) })
                end
            else
                covered[part] = true -- too small to read at proxy range: hidden, not drawn
            end
        end
    end
    if #drawn == 0 then
        return nil
    end
    local signatures = table.create(#drawn)
    for i, entry in drawn do
        signatures[i] = entry[4]
    end
    table.sort(signatures)
    local signature = table.concat(signatures, "\n")

    local set = shared[signature]
    if not set then
        local builder = newBuilder()
        local work = 0
        for _, entry in drawn do
            if entry[3] then
                work += addMeshPart(builder, entry[1], entry[3], entry[2])
            else
                addBox(builder, entry[1], entry[2])
                work += 6
            end
            if work > YIELD_EVERY then
                work = 0
                task.wait()
            end
        end
        if shared[signature] then -- another temple built the same set while this one yielded
            set = shared[signature]
        else
            local ok, templates, meshes = pcall(buildMeshes, builder, "TempleLODProxy")
            if not ok then
                warn("[TempleProxy] build failed:", templates)
                return nil
            end
            if shared[signature] then -- lost a race while building: keep the first set
                for _, template in templates do
                    template:Destroy()
                end
                for _, em in meshes do
                    em:Destroy()
                end
            else
                shared[signature] = { templates = templates, meshes = meshes, triangles = #builder.quads * 2, refs = 0 }
            end
            set = shared[signature]
        end
    end
    set.refs += 1
    local parts = {}
    for _, template in set.templates do
        local part = template:Clone()
        part.CFrame = origin * template:GetAttribute("ProxyOffset")
        table.insert(parts, part)
    end
    return { parts = parts, covered = covered, triangles = set.triangles, signature = signature }
end

function TempleProxy.Destroy(proxy)
    if not proxy then
        return
    end
    for _, part in proxy.parts do
        part:Destroy()
    end
    local set = shared[proxy.signature]
    if set then
        set.refs -= 1
        if set.refs <= 0 then
            shared[proxy.signature] = nil
            for _, template in set.templates do
                template:Destroy()
            end
            for _, em in set.meshes do
                em:Destroy()
            end
        end
    end
end

return TempleProxy
