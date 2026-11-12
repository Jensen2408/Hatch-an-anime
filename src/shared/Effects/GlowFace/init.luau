--[[
GlowFace (client): rebuilds a character's own atlas with a new palette and makes its eyes and mouth glow.

Used by Molten (lava coat, eyes/mouth glow hot orange through it) and Galaxy (cosmic tint, white glowing marks).
Works from the CURRENT (re-unwrapped) atlas of any V2 character, so it never drifts out of sync with the meshes
the way hand-made face images did.

How the face is found: the meshes are read as EditableMeshes; triangles facing the model's front in the upper
half of the model are candidates. A candidate cube face counts as DRAWN when its texels have strong contrast (eyes,
mouth, brows on skin); its dark texels become the glow. Flat one-colour faces (black hair, hat bands) are skipped.
Results are cached per character tag and style.

GlowFace.Surface(model, styleName, style) -> SurfaceAppearance template (clone it) or nil, set of face part names. Yields.
style = {
	base = function(r, g, b) -> r, g, b   -- palette for every non-feature texel (0..1)
	glow = Color3                          -- colour of the glowing features
	emissive = number                      -- EmissiveStrength
}
]]
local Assets = game:GetService("AssetService")
local Atlas = require(script.CharacterAtlasIds)

local GlowFace = {}

local FRONT_DOT = 0.8 -- how squarely a triangle must face the model's front to count as face
local FACE_LOW = 0.5 -- only the upper half of the model (the head)
local DARK = 0.30 -- luminance below this on a drawn face is a feature
local CONTRAST = 0.35 -- a cube face is "drawn" when its brightest and darkest texels differ by this much

local masks, surfaces, building = {}, {}, {}

local function tagOf(model)
	for _, p in model:GetDescendants() do
		if p:IsA("MeshPart") then
			local tag = p.Name:match("^(.-) Part %d+$")
			if tag and Atlas[tag] then
				return tag
			end
		end
	end
	return nil
end

local function solid(value)
	local img = Assets:CreateEditableImage({ Size = Vector2.one })
	img:DrawRectangle(Vector2.zero, Vector2.one, Color3.new(value, value, value), 0, Enum.ImageCombineType.Overwrite)
	return Content.fromObject(img)
end

-- collect the texel indices covered by one UV triangle
local function raster(out, w, h, a, b, c)
	local ax, ay, bx, by, cx, cy = a.X * w, a.Y * h, b.X * w, b.Y * h, c.X * w, c.Y * h
	local x0, x1 = math.max(0, math.floor(math.min(ax, bx, cx))), math.min(w - 1, math.ceil(math.max(ax, bx, cx)))
	local y0, y1 = math.max(0, math.floor(math.min(ay, by, cy))), math.min(h - 1, math.ceil(math.max(ay, by, cy)))
	local area = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
	if math.abs(area) < 1e-6 then
		return
	end
	for y = y0, y1 do
		local py = y + 0.5
		for x = x0, x1 do
			local px = x + 0.5
			local w0 = ((bx - px) * (cy - py) - (by - py) * (cx - px)) / area
			local w1 = ((cx - px) * (ay - py) - (cy - py) * (ax - px)) / area
			local w2 = 1 - w0 - w1
			-- half-texel tolerance so thin face tiles are fully covered
			if w0 >= -0.02 and w1 >= -0.02 and w2 >= -0.02 then
				table.insert(out, y * w + x)
			end
		end
	end
end

local function faceMask(model, tag, w, h, px)
	if masks[tag] then
		return masks[tag], masks[tag .. "/parts"]
	end
	local look = model:GetPivot().LookVector
	local box, size = model:GetBoundingBox()
	local low = box.Position.Y - size.Y / 2 + size.Y * FACE_LOW
	local mask = buffer.create(w * h)
	local parts = {}
	local lum = function(i)
		local p = i * 4
		return (buffer.readu8(px, p) * 0.3 + buffer.readu8(px, p + 1) * 0.59 + buffer.readu8(px, p + 2) * 0.11) / 255
	end
	local count = 0
	for _, part in model:GetDescendants() do
		if not part:IsA("MeshPart") or part.Transparency >= 1 or not part.Name:match(" Part %d+$") then
			continue
		end
		if part.Position.Y + part.Size.Y / 2 < low then
			continue
		end
		local ok, em = pcall(function()
			return Assets:CreateEditableMeshAsync(Content.fromUri(part.MeshId))
		end)
		if not ok or not em then
			continue
		end
		local scale = part.Size / part.MeshSize
		local cf = part.CFrame
		for _, f in em:GetFaces() do
			local v = em:GetFaceVertices(f)
			local uv = em:GetFaceUVs(f)
			if #v < 3 or #uv < 3 then
				continue
			end
			local p1 = cf:PointToWorldSpace(em:GetPosition(v[1]) * scale)
			local p2 = cf:PointToWorldSpace(em:GetPosition(v[2]) * scale)
			local p3 = cf:PointToWorldSpace(em:GetPosition(v[3]) * scale)
			local n = (p2 - p1):Cross(p3 - p1)
			if n.Magnitude < 1e-9 or n.Unit:Dot(look) < FRONT_DOT or (p1.Y + p2.Y + p3.Y) / 3 < low then
				continue
			end
			local texels = {}
			raster(texels, w, h, em:GetUV(uv[1]), em:GetUV(uv[2]), em:GetUV(uv[3]))
			local lo, hi = 1, 0
			for _, t in texels do
				local l = lum(t)
				lo, hi = math.min(lo, l), math.max(hi, l)
			end
			if hi - lo >= CONTRAST then
				for _, t in texels do
					if lum(t) < DARK then
						buffer.writeu8(mask, t, 1)
						parts[part.Name] = true
					end
				end
			end
			count += 1
			if count % 300 == 0 then
				task.wait()
			end
		end
		em:Destroy()
	end
	masks[tag], masks[tag .. "/parts"] = mask, parts
	return mask, parts
end

function GlowFace.Surface(model, styleName, style)
	local tag = tagOf(model)
	if not tag then
		return nil
	end
	local key = tag .. "/" .. styleName
	if surfaces[key] then
		return surfaces[key], masks[tag .. "/parts"]
	end
	while building[key] do
		task.wait()
	end
	if surfaces[key] then
		return surfaces[key], masks[tag .. "/parts"]
	end
	building[key] = true
	local ok, result = pcall(function()
		local ids = Atlas[tag]
		local atlas = Assets:CreateEditableImageAsync(Content.fromUri("rbxassetid://" .. ids.Color))
		local size = atlas.Size
		local w, h = size.X, size.Y
		local px = atlas:ReadPixelsBuffer(Vector2.zero, size)
		local mask = faceMask(model, tag, w, h, px)
		local glowBuf = buffer.create(w * h * 4)
		local gr, gg, gb = math.floor(style.glow.R * 255), math.floor(style.glow.G * 255), math.floor(style.glow.B * 255)
		local base = style.base
		for y = 0, h - 1 do
			if y % 32 == 31 then
				task.wait()
			end
			for x = 0, w - 1 do
				local i = y * w + x
				local p = i * 4
				local r = buffer.readu8(px, p) / 255
				local g = buffer.readu8(px, p + 1) / 255
				local b = buffer.readu8(px, p + 2) / 255
				local feature = buffer.readu8(mask, i) == 1
				if feature then
					buffer.writeu8(px, p, gr)
					buffer.writeu8(px, p + 1, gg)
					buffer.writeu8(px, p + 2, gb)
					buffer.writeu32(glowBuf, p, 0xFFFFFFFF)
				else
					local nr, ng, nb = base(r, g, b)
					buffer.writeu8(px, p, math.floor(math.clamp(nr, 0, 1) * 255))
					buffer.writeu8(px, p + 1, math.floor(math.clamp(ng, 0, 1) * 255))
					buffer.writeu8(px, p + 2, math.floor(math.clamp(nb, 0, 1) * 255))
					buffer.writeu32(glowBuf, p, 0xFF000000)
				end
			end
		end
		atlas:WritePixelsBuffer(Vector2.zero, size, px)
		local glowImage = Assets:CreateEditableImage({ Size = size })
		glowImage:WritePixelsBuffer(Vector2.zero, size, glowBuf)
		local normal = Assets:CreateEditableImageAsync(Content.fromUri("rbxassetid://" .. ids.Normal))
		local sa = Assets:CreateSurfaceAppearanceAsync({
			ColorMap = Content.fromObject(atlas),
			NormalMap = Content.fromObject(normal),
			EmissiveMask = Content.fromObject(glowImage),
			RoughnessMap = solid(1),
			MetalnessMap = solid(0),
		})
		sa.Name = "GlowFace"
		sa.EmissiveStrength = style.emissive or 1.8
		return sa
	end)
	building[key] = nil
	if not ok then
		warn("[GlowFace] " .. tag .. ": " .. tostring(result))
		return nil
	end
	surfaces[key] = result
	return result, masks[tag .. "/parts"]
end

return GlowFace
