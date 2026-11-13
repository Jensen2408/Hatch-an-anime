--[[
Bake the far-LOD proxy data for the plot temples (Studio, Edit mode, run through the MCP / command bar).

The temple MeshParts are voxel meshes cut into one quad per texture tile (a 44 x 50 floor is 749 triangles), and
each has its own SurfaceAppearance, so a far temple costs ~20k triangles and ~260 draw calls. This tool turns every
temple mesh into a merged, vertex-coloured version:
  - faces are coloured with the average of their atlas tile (read from the SurfaceAppearance ColorMap, which game
    scripts cannot read - that is why this is baked),
  - faces are grouped by plane (sloped roof planes too), rasterised on the plane's own vertex coordinate grid and
    greedily merged into rectangles of similar colour, so the outline (roof tiers, posts, rafters, steps) stays.
The client (StarterPlayerScripts.TempleLOD) combines a far temple into ONE MeshPart from this data.

Output: ReplicatedStorage.TempleProxyMeshes, a ModuleScript with children Chunk1..N (Studio's 200k-character Source
limit), keyed by MeshId. It is generated Studio data (like a model), not a Rojo file: it is reproducible with this tool.
Each record: MeshSize X, Y, Z, then a base64 buffer:
  u16 quadCount, then per rectangle corners 1, 2 and 4 (i16 x, y, z; corners run counter-clockwise around the face
  normal, corner 3 = 2 + 4 - 1) and u8 r, g, b. Coordinates are mesh-space studs x 256 (mesh space is +-MeshSize/2).

Usage (Edit mode): local Bake = require(<this as a ModuleScript>)
  _G.TempleBakeCache = _G.TempleBakeCache or {}
  local main, chunks, stats = Bake.Run(nil, _G.TempleBakeCache)  -- ~10 min for ~1,000 meshes; yields
  Bake.Install(main, chunks)

]]

local AssetService = game:GetService("AssetService")

local SCALE = 256
local SNAP = 64
local COLOUR_TOLERANCE = 24 / 255 -- per channel, against the rectangle's seed cell
local Bake = {}

local imageCache = {}
local function getImage(id)
    if imageCache[id] ~= nil then
        return imageCache[id]
    end
    local ok, image = pcall(function()
        return AssetService:CreateEditableImageAsync(Content.fromUri(id))
    end)
    local entry = false
    if ok and image then
        local size = image.Size
        entry = { w = size.X, h = size.Y, buf = image:ReadPixelsBuffer(Vector2.zero, size) }
        image:Destroy()
    end
    imageCache[id] = entry
    return entry
end

local function sample(img, u, v)
    local x = math.clamp(math.floor((u % 1) * img.w), 0, img.w - 1)
    local y = math.clamp(math.floor((v % 1) * img.h), 0, img.h - 1)
    local o = (y * img.w + x) * 4
    return buffer.readu8(img.buf, o), buffer.readu8(img.buf, o + 1), buffer.readu8(img.buf, o + 2), buffer.readu8(img.buf, o + 3)
end

-- Average colour over the face's UV rectangle (8 x 8 samples), blended over the part colour by the texel alpha
-- (SurfaceAppearance AlphaMode Overlay). The rectangle, not the triangle, so both halves of a tile get the same
-- colour and merge; cached per rectangle.
local GRID = 8
local colourCache = {}
local function faceColour(img, uv1, uv2, uv3, base)
    if not img then
        return base.R, base.G, base.B
    end
    local u0, u1 = math.min(uv1.X, uv2.X, uv3.X), math.max(uv1.X, uv2.X, uv3.X)
    local v0, v1 = math.min(uv1.Y, uv2.Y, uv3.Y), math.max(uv1.Y, uv2.Y, uv3.Y)
    local key = string.format("%s:%.4f:%.4f:%.4f:%.4f", tostring(img), u0, u1, v0, v1)
    local hit = colourCache[key]
    if hit then
        return hit[1], hit[2], hit[3]
    end
    local r, g, b = 0, 0, 0
    for i = 0, GRID - 1 do
        for j = 0, GRID - 1 do
            local sr, sg, sb, sa = sample(img, u0 + (u1 - u0) * (i + 0.5) / GRID, v0 + (v1 - v0) * (j + 0.5) / GRID)
            local t = sa / 255
            r += (sr / 255) * t + base.R * (1 - t)
            g += (sg / 255) * t + base.G * (1 - t)
            b += (sb / 255) * t + base.B * (1 - t)
        end
    end
    local n = GRID * GRID
    colourCache[key] = { r / n, g / n, b / n }
    return r / n, g / n, b / n
end

local function q(x)
    return math.clamp(math.round(x * SCALE), -32768, 32767)
end

local function uniqueSorted(list)
    table.sort(list)
    local out = {}
    for _, x in list do
        if #out == 0 or x - out[#out] > 1e-4 then
            table.insert(out, x)
        end
    end
    return out
end

local function lowerIndex(arr, x) -- largest i with arr[i] <= x + eps
    local lo, hi = 1, #arr
    while lo < hi do
        local mid = (lo + hi + 1) // 2
        if arr[mid] <= x + 1e-4 then
            lo = mid
        else
            hi = mid - 1
        end
    end
    return lo
end

local function inTri(px, py, a, b, c)
    local d1 = (px - b[1]) * (a[2] - b[2]) - (a[1] - b[1]) * (py - b[2])
    local d2 = (px - c[1]) * (b[2] - c[2]) - (b[1] - c[1]) * (py - c[2])
    local d3 = (px - a[1]) * (c[2] - a[2]) - (c[1] - a[1]) * (py - a[2])
    local neg = d1 < -1e-7 or d2 < -1e-7 or d3 < -1e-7
    local pos = d1 > 1e-7 or d2 > 1e-7 or d3 > 1e-7
    return not (neg and pos)
end

-- In-plane basis for a face normal: u is the world axis most perpendicular to n, projected onto the plane, so the
-- voxel edges (and roof slopes) line up with u / v and merge into rectangles.
local WORLD = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
local function basis(n)
    local best, bestDot = nil, math.huge
    for _, axis in WORLD do
        local d = math.abs(n:Dot(axis))
        if d < bestDot then
            best, bestDot = axis, d
        end
    end
    local u = (best - n * n:Dot(best)).Unit
    return u, n:Cross(u)
end

-- One mesh -> quads (4 corners + colour)
function Bake.Mesh(meshId, colorMap, baseColour)
    local ok, em = pcall(function()
        return AssetService:CreateEditableMeshAsync(Content.fromUri(meshId))
    end)
    if not ok or not em then
        return nil, "load failed: " .. tostring(em)
    end
    local img = colorMap and colorMap ~= "" and getImage(colorMap) or nil
    local planes = {} -- key -> { n, d, u, v, tris = { {a,b,c, r,g,b} } } with a/b/c in plane coordinates
    local faceCount = 0
    for _, f in em:GetFaces() do
        faceCount += 1
        local vs = em:GetFaceVertices(f)
        local uvs = em:GetFaceUVs(f)
        local p1, p2, p3 = em:GetPosition(vs[1]), em:GetPosition(vs[2]), em:GetPosition(vs[3])
        local cross = (p2 - p1):Cross(p3 - p1)
        if cross.Magnitude > 1e-8 then
            local n = cross.Unit
            n = Vector3.new(math.round(n.X * 1000) / 1000, math.round(n.Y * 1000) / 1000, math.round(n.Z * 1000) / 1000).Unit
            local d = math.round(n:Dot(p1) * SCALE) / SCALE
            local uv1 = uvs[1] and em:GetUV(uvs[1]) or Vector2.zero
            local uv2 = uvs[2] and em:GetUV(uvs[2]) or Vector2.zero
            local uv3 = uvs[3] and em:GetUV(uvs[3]) or Vector2.zero
            local r, g, b = faceColour(img, uv1, uv2, uv3, baseColour)
            -- + 0 turns -0 into 0 so faces of one plane never split into "-0.000" and "0.000" groups
            local key = string.format("%.3f,%.3f,%.3f:%.2f", n.X + 0, n.Y + 0, n.Z + 0, d + 0)
            local group = planes[key]
            if not group then
                local u, v = basis(n)
                group = { n = n, d = d, u = u, v = v, tris = {} }
                planes[key] = group
            end
            local u, v = group.u, group.v
            -- snap to 1/64 stud: the mesh vertices carry ~0.0005-stud import jitter that would split the grid
            local function s(x)
                return math.round(x * SNAP) / SNAP
            end
            table.insert(group.tris, {
                { s(p1:Dot(u)), s(p1:Dot(v)) }, { s(p2:Dot(u)), s(p2:Dot(v)) }, { s(p3:Dot(u)), s(p3:Dot(v)) }, r, g, b,
            })
        end
    end
    em:Destroy()

    local quads = {}
    for _, group in planes do
        local us, vs = {}, {}
        for _, t in group.tris do
            for i = 1, 3 do
                table.insert(us, t[i][1])
                table.insert(vs, t[i][2])
            end
        end
        us, vs = uniqueSorted(us), uniqueSorted(vs)
        local nu, nv = #us - 1, #vs - 1
        if nu >= 1 and nv >= 1 then
            local cell = {} -- index (j-1)*nu + i -> {r,g,b,n}
            for _, t in group.tris do
                local a, b, c = t[1], t[2], t[3]
                local i0 = lowerIndex(us, math.min(a[1], b[1], c[1]))
                local i1 = lowerIndex(us, math.max(a[1], b[1], c[1]))
                local j0 = lowerIndex(vs, math.min(a[2], b[2], c[2]))
                local j1 = lowerIndex(vs, math.max(a[2], b[2], c[2]))
                for j = j0, math.min(j1, nv) do
                    local cy = (vs[j] + vs[j + 1]) / 2
                    for i = i0, math.min(i1, nu) do
                        local cx = (us[i] + us[i + 1]) / 2
                        if inTri(cx, cy, a, b, c) then
                            local k = (j - 1) * nu + i
                            local e = cell[k]
                            if not e then
                                cell[k] = { t[4], t[5], t[6], 1 }
                            else
                                e[1] += t[4]; e[2] += t[5]; e[3] += t[6]; e[4] += 1
                            end
                        end
                    end
                end
            end
            for _, e in cell do
                e[1] /= e[4]; e[2] /= e[4]; e[3] /= e[4]
            end
            local used = {}
            local function fits(i, j, seed)
                local k = (j - 1) * nu + i
                local e = cell[k]
                return e and not used[k]
                    and math.abs(e[1] - seed[1]) <= COLOUR_TOLERANCE
                    and math.abs(e[2] - seed[2]) <= COLOUR_TOLERANCE
                    and math.abs(e[3] - seed[3]) <= COLOUR_TOLERANCE
            end
            for j = 1, nv do
                for i = 1, nu do
                    local k = (j - 1) * nu + i
                    local seed = cell[k]
                    if seed and not used[k] then
                        local i2 = i
                        while i2 < nu and fits(i2 + 1, j, seed) do
                            i2 += 1
                        end
                        local j2 = j
                        while j2 < nv do
                            local rowOk = true
                            for x = i, i2 do
                                if not fits(x, j2 + 1, seed) then
                                    rowOk = false
                                    break
                                end
                            end
                            if not rowOk then
                                break
                            end
                            j2 += 1
                        end
                        local r, g, b, area = 0, 0, 0, 0
                        for y = j, j2 do
                            for x = i, i2 do
                                local kk = (y - 1) * nu + x
                                used[kk] = true
                                local e = cell[kk]
                                local w = (us[x + 1] - us[x]) * (vs[y + 1] - vs[y])
                                r += e[1] * w; g += e[2] * w; b += e[3] * w; area += w
                            end
                        end
                        local u0, v0, u1, v1 = us[i], vs[j], us[i2 + 1], vs[j2 + 1]
                        local origin = group.n * group.d
                        local function corner(a, c)
                            return origin + group.u * a + group.v * c
                        end
                        -- corners wound counter-clockwise around n (u x v = n)
                        table.insert(quads, {
                            corner(u0, v0), corner(u1, v0), corner(u1, v1), corner(u0, v1),
                            r / area, g / area, b / area,
                        })
                    end
                end
            end
        end
    end
    return { quads = quads, inputFaces = faceCount }
end

-- u16 quadCount, then per quad: corners 1, 2 and 4 x (i16 x, y, z), u8 r, g, b (21 bytes); the quads are rectangles,
-- so corner 3 = corner 2 + corner 4 - corner 1.
function Bake.Encode(result)
    local nq = #result.quads
    local buf = buffer.create(2 + nq * 21)
    buffer.writeu16(buf, 0, nq)
    local o = 2
    local function c8(x)
        return math.clamp(math.round(x * 255), 0, 255)
    end
    for _, qd in result.quads do
        for _, i in { 1, 2, 4 } do
            buffer.writei16(buf, o, q(qd[i].X))
            buffer.writei16(buf, o + 2, q(qd[i].Y))
            buffer.writei16(buf, o + 4, q(qd[i].Z))
            o += 6
        end
        buffer.writeu8(buf, o, c8(qd[5]))
        buffer.writeu8(buf, o + 1, c8(qd[6]))
        buffer.writeu8(buf, o + 2, c8(qd[7]))
        o += 3
    end
    return buf
end

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function Bake.Base64(buf)
    local out = {}
    local len = buffer.len(buf)
    for i = 0, len - 1, 3 do
        local a = buffer.readu8(buf, i)
        local b = i + 1 < len and buffer.readu8(buf, i + 1) or 0
        local c = i + 2 < len and buffer.readu8(buf, i + 2) or 0
        local n = a * 65536 + b * 256 + c
        local s1 = string.sub(B64, (n // 262144) % 64 + 1, (n // 262144) % 64 + 1)
        local s2 = string.sub(B64, (n // 4096) % 64 + 1, (n // 4096) % 64 + 1)
        local s3 = i + 1 < len and string.sub(B64, (n // 64) % 64 + 1, (n // 64) % 64 + 1) or "="
        local s4 = i + 2 < len and string.sub(B64, n % 64 + 1, n % 64 + 1) or "="
        table.insert(out, s1 .. s2 .. s3 .. s4)
    end
    return table.concat(out)
end

-- Every temple MeshPart in the plots and the upgrade templates.
function Bake.Collect()
    local roots = {}
    local plots = workspace:FindFirstChild("Plots")
    if plots then
        for _, plot in plots:GetChildren() do
            local temple = plot:FindFirstChild("Temple")
            if temple then
                table.insert(roots, temple)
            end
        end
    end
    local templates = game:GetService("ServerStorage"):FindFirstChild("TempleUpgradeTemplates")
    if templates then
        for _, t in templates:GetChildren() do
            table.insert(roots, t)
        end
    end
    local meshes, order = {}, {}
    for _, root in roots do
        for _, d in root:GetDescendants() do
            if d:IsA("MeshPart") and d.MeshId ~= "" and not meshes[d.MeshId] then
                local sa = d:FindFirstChildOfClass("SurfaceAppearance")
                -- Base colour under Overlay alpha: the part colour without the theme tint (themes tint SA.Color).
                meshes[d.MeshId] = {
                    meshSize = d.MeshSize,
                    colorMap = sa and sa.ColorMap or "",
                    base = d:GetAttribute("BeforeThemeColor") or d.Color,
                }
                table.insert(order, d.MeshId)
            end
        end
    end
    return meshes, order
end

-- Studio caps a script's Source at 200,000 characters, so the data is split into chunk ModuleScripts under the main
-- module. Entries are kept in `cache` (pass the same table again to resume after an error).
local CHUNK_CHARS = 180000
local MAIN_SOURCE = [[
-- GENERATED by tools/temple_lod/bake_temple_proxies.luau - do not edit by hand. Re-run the tool after changing
-- temple meshes or their textures. Far-LOD proxy geometry for the plot temples, keyed by MeshId, read by
-- ReplicatedStorage.TempleProxy. Record: { MeshSize X, Y, Z, base64 quads } (format in the tool header).
local meshes = {}
for _, chunk in script:GetChildren() do
	if chunk:IsA("ModuleScript") then
		for meshId, record in require(chunk) do
			meshes[meshId] = record
		end
	end
end
return { Version = 2, Scale = 256, Meshes = meshes }
]]

function Bake.Run(progress, cache)
    cache = cache or {}
    local meshes, order = Bake.Collect()
    table.sort(order)
    local stats = { meshes = 0, inFaces = 0, outTris = 0, failed = 0 }
    for index, meshId in order do
        if not cache[meshId] then
            local info = meshes[meshId]
            local result, err = Bake.Mesh(meshId, info.colorMap, info.base)
            if result then
                local s = info.meshSize
                cache[meshId] = {
                    line = string.format('\t["%s"] = { %.4f, %.4f, %.4f, "%s" },', meshId, s.X, s.Y, s.Z, Bake.Base64(Bake.Encode(result))),
                    inFaces = result.inputFaces,
                    outTris = #result.quads * 2,
                }
            else
                stats.failed += 1
                warn("[TempleProxyBake]", meshId, err)
            end
            task.wait()
        end
        local entry = cache[meshId]
        if entry then
            stats.meshes += 1
            stats.inFaces += entry.inFaces
            stats.outTris += entry.outTris
        end
        if progress then
            progress(index, #order, stats)
        end
    end
    table.clear(imageCache)
    table.clear(colourCache)
    local chunks, current, size = {}, {}, 0
    for _, meshId in order do
        local entry = cache[meshId]
        if entry then
            if size + #entry.line > CHUNK_CHARS and #current > 0 then
                table.insert(chunks, current)
                current, size = {}, 0
            end
            table.insert(current, entry.line)
            size += #entry.line + 1
        end
    end
    if #current > 0 then
        table.insert(chunks, current)
    end
    local sources = {}
    for i, lines in chunks do
        sources[i] = "-- GENERATED chunk " .. i .. " of TempleProxyMeshes (tools/temple_lod/bake_temple_proxies.luau)\nreturn {\n"
            .. table.concat(lines, "\n") .. "\n}\n"
    end
    return MAIN_SOURCE, sources, stats
end

-- Writes the result into ReplicatedStorage.TempleProxyMeshes (replacing it) with children Chunk1..N.
function Bake.Install(mainSource, chunkSources)
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local old = ReplicatedStorage:FindFirstChild("TempleProxyMeshes")
    local module = Instance.new("ModuleScript")
    module.Name = "TempleProxyMeshes"
    module.Source = mainSource
    for i, source in chunkSources do
        local chunk = Instance.new("ModuleScript")
        chunk.Name = "Chunk" .. i
        chunk.Source = source
        chunk.Parent = module
    end
    if old then
        old:Destroy()
    end
    module.Parent = ReplicatedStorage
    return module
end

return Bake
