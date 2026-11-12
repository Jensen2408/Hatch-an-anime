-- Galaxy v6: Public Domain NASA/ESA Hubble (NGC 3603 + Westerlund 2) baked into ONE ultra-bright, star-packed 256x256 drifting coat.
-- Zero per-frame SurfaceAppearance mutations, zero workspace:GetDescendants() scans in RenderStepped, and strict single-layer deduplication.
local RS = game:GetService("ReplicatedStorage")
local Assets = game:GetService("AssetService")
local Encoding = game:GetService("EncodingService")
local Run = game:GetService("RunService")

local templates = RS:WaitForChild("ProjectedCoatingMeshes")
local protoFolder = RS:WaitForChild("GalaxyPrototype")
local mapData = require(protoFolder:WaitForChild("GalaxyMapData"))
local auraTemplate = protoFolder:WaitForChild("GalaxyAura", 25)

-- Clean up any leftover runtime layer folders from prior runs
for _, child in workspace:GetChildren() do
	if child.Name == "GalaxyLayersLocal" then
		child:Destroy()
	end
end

local SIZE = mapData.Size -- 256
local DIMS = Vector2.new(SIZE, SIZE)
local TOTAL_BYTES = SIZE * SIZE * 4

local function decodeParts(parts)
	local out = buffer.create(TOTAL_BYTES)
	local offset = 0
	for _, part in parts do
		local raw = Encoding:DecompressBuffer(Encoding:Base64Decode(buffer.fromstring(part)), Enum.CompressionAlgorithm.Zstd)
		buffer.copy(out, offset, raw)
		offset += buffer.len(raw)
	end
	return out
end

local createdObjects = {}
local function track(inst)
	table.insert(createdObjects, inst)
	return inst
end

local function makeSolid(color)
	local img = track(Assets:CreateEditableImage({ Size = Vector2.one }))
	img:DrawRectangle(Vector2.zero, Vector2.one, color, 0, Enum.ImageCombineType.Overwrite)
	return img
end

-- Everything below is built lazily, the first time a galaxy model is near the camera. Before this, every client
-- loaded 3 asset images, ran a Luau loop over the whole Sun God atlas and held ~9 EditableImages at startup,
-- even when nobody owned a galaxy character.
local coat, colorTile, driftImage
-- Base surface: the character's CURRENT atlas tinted cosmic violet, eyes/mouth glowing white (GlowFace). The old
-- hand-made face/tint images were drawn for the pre-re-unwrap UVs, which is why the face had disappeared.
local GlowFace = require(RS:WaitForChild("GlowFace"))
local GALAXY_STYLE = {
	base = function(r, g, b)
		local lum = r * 0.3 + g * 0.5 + b * 0.2
		return 0.035 + lum * 0.30, 0.015 + lum * 0.16, 0.095 + lum * 0.50
	end,
	glow = Color3.new(1, 1, 1),
	emissive = 1.85,
}
local DRAW_OPTS = {
	PivotPoint = Vector2.zero,
	CombineType = Enum.ImageCombineType.Overwrite,
	SamplingMode = Enum.ResamplerMode.Default,
}
-- Faster diagonal drift (28 px/s X, 14 px/s Y on 256px tile) using only 4 C++ draw calls on ONE EditableImage
local function drift(t)
	local dx = (t * 28) % SIZE
	local dy = (t * 14) % SIZE
	for y = 0, 1 do
		for x = 0, 1 do
			driftImage:DrawImageTransformed(Vector2.new(-dx + x * SIZE, -dy + y * SIZE), Vector2.one, 0, colorTile, DRAW_OPTS)
		end
	end
end
local initStarted, ready = false, false
local function initResources()
	-- Decode baked 256x256 seamless ColorMap for the SINGLE animated layer
	-- Populate driftImage BEFORE CreateSurfaceAppearanceAsync so the GPU texture backing initializes with valid opaque texels.
	local colorBytes = decodeParts(mapData.Color)
	colorTile = track(Assets:CreateEditableImage({ Size = DIMS }))
	colorTile:WritePixelsBuffer(Vector2.zero, DIMS, colorBytes)

	driftImage = track(Assets:CreateEditableImage({ Size = DIMS }))
	driftImage:WritePixelsBuffer(Vector2.zero, DIMS, colorBytes)

	drift(0)

	coat = track(Assets:CreateSurfaceAppearanceAsync({
		ColorMap = Content.fromObject(driftImage),
		EmissiveMask = Content.fromObject(makeSolid(Color3.new(1, 1, 1))),
		RoughnessMap = Content.fromObject(makeSolid(Color3.new(1, 1, 1))),
		MetalnessMap = Content.fromObject(makeSolid(Color3.new(0, 0, 0))),
	}))
	coat.Name = "GalaxyDrift"
	coat.EmissiveStrength = 1.35
	ready = true
end

local active, pending = {}, {}
local function remove(m)
	local rec = active[m]
	if not rec then return end
	rec.folder:Destroy()
	for _, r in rec.parts do
		if r.source.Parent then
			local s = r.source:FindFirstChild("GalaxyBase")
			if s then s:Destroy() end
			if r.original then r.original.Parent = r.source end
		elseif r.original then
			r.original:Destroy()
		end
	end
	active[m] = nil
end

local function isVisibleCandidate(m)
	-- Never coat the hidden source model inside an equipped character Tool; TwoHandItemCarryService clones it into HeldItemCarry.Character
	local tool = m:FindFirstAncestorOfClass("Tool")
	if tool then
		if tool:GetAttribute("CharacterId") ~= nil then
			return false
		end
		if tool.Parent and (tool.Parent:FindFirstChildOfClass("Humanoid") or tool.Parent:FindFirstChild("HeldItemCarry")) then
			return false
		end
	end
	for _, p in m:GetDescendants() do
		if p:IsA("MeshPart") and p.Name ~= "GalaxyMovingLayer" and p.Name ~= "ProjectedCoating" then
			if p.Transparency < 1 then
				return true
			end
		end
	end
	return false
end

local function build(m)
	if active[m] or pending[m] then return end
	pending[m] = true
	local folder = Instance.new("Folder")
	folder.Name = "GalaxyLayersLocal"
	local records = {}
	local baseSurface, faceParts = GlowFace.Surface(m, "Galaxy", GALAXY_STYLE)
	if not m:IsDescendantOf(workspace) then
		pending[m] = nil
		folder:Destroy()
		return
	end
	for _, p in m:GetDescendants() do
		if not p:IsA("MeshPart") or p.Transparency >= 1 then continue end
		if p.Name == "GalaxyMovingLayer" or p.Name == "ProjectedCoating" then continue end
		local partIndex = tonumber(p.Name:match("Part (%d+)$"))
		local projected = templates:FindFirstChild(p.Name)
		if not projected then continue end
		for _, oldSa in p:GetChildren() do
			if oldSa:IsA("SurfaceAppearance") and oldSa.Name == "GalaxyBase" then
				oldSa:Destroy()
			end
		end
		local original
		if baseSurface then
			original = p:FindFirstChildOfClass("SurfaceAppearance")
			if original then original.Parent = nil end
			local base = baseSurface:Clone()
			base.Name = "GalaxyBase"
			base.Parent = p
		end
		-- parts carrying the glowing face get a thinner galaxy layer so the face reads through
		local head = if faceParts then faceParts[p.Name] == true else (partIndex and partIndex >= 6)
		local shell = p:Clone()
		for _, d in shell:GetDescendants() do
			if not d:IsA("Bone") and not d:FindFirstAncestorWhichIsA("Bone") then
				d:Destroy()
			end
		end
		shell:ApplyMesh(projected)
		shell.Size = p.Size * (projected.MeshSize / p.MeshSize)
		shell.Name = "GalaxyMovingLayer"
		shell.Material = Enum.Material.SmoothPlastic
		shell.Color = Color3.new(1, 1, 1)
		shell.TextureID = ""
		shell.Anchored = true
		shell.CanCollide = false
		shell.CanQuery = false
		shell.CanTouch = false
		shell.CastShadow = false
		local opacity = head and 0.54 or 0.30
		shell.Transparency = opacity
		coat:Clone().Parent = shell
		local rec = { source = p, shell = shell, original = original, opacity = opacity, bones = {} }
		for _, b in p:GetDescendants() do
			if b:IsA("Bone") then
				local path = {}
				local parent = b
				while parent ~= p do
					table.insert(path, 1, parent.Name)
					parent = parent.Parent
				end
				local target = shell
				for _, name in path do
					target = target and target:FindFirstChild(name)
				end
				if target then
					table.insert(rec.bones, { b, target })
				end
			end
		end
		shell.CFrame = p.CFrame
		shell.Parent = folder
		table.insert(records, rec)
	end
	pending[m] = nil
	if #records == 0 then
		folder:Destroy()
		return
	end
	local aura, offset
	if auraTemplate then
		aura = auraTemplate:Clone()
		aura.Name = "GalaxyAuraLocal"
		local box = m:GetBoundingBox()
		offset = m:GetPivot():ToObjectSpace(box)
		aura.CFrame = box
		aura.Parent = folder
	end
	folder.Parent = workspace
	active[m] = { folder = folder, parts = records, aura = aura, auraOffset = offset }
end

-- Event-driven candidate tracking (eliminates expensive workspace:GetDescendants() scans in RenderStepped!)
-- No per-Model signal connections (the old version hooked GetAttributeChangedSignal on every Model in workspace).
-- Galaxy models are found when they are added (attribute or "GalaxyPrototype" tag); attribute removal is caught by the scan.
local CollectionService = game:GetService("CollectionService")
local candidates = {}
local function isGalaxy(inst)
	return inst:GetAttribute("GalaxyPrototype") == true or CollectionService:HasTag(inst, "GalaxyPrototype")
end
local function watchInstance(inst)
	if inst:IsA("Model") and not inst:IsA("Tool") and isGalaxy(inst) then
		candidates[inst] = true
	end
end

for _, inst in workspace:GetDescendants() do
	watchInstance(inst)
end
local addedConn = workspace.DescendantAdded:Connect(function(inst)
	watchInstance(inst)
	if inst:IsA("Model") then
		task.defer(watchInstance, inst)
	end
end)
local removingConn = workspace.DescendantRemoving:Connect(function(inst)
	if candidates[inst] then
		candidates[inst] = nil
		remove(inst)
	end
end)

local nextScan, nextImage = 0, 0
local connection = Run.RenderStepped:Connect(function()
	local t = os.clock()
	if t >= nextScan then
		nextScan = t + 0.5
		local near = {}
		local cam = workspace.CurrentCamera
		if cam then
			for m in candidates do
				if not m:IsDescendantOf(workspace) or not isGalaxy(m) then
					candidates[m] = nil
					remove(m)
					continue
				end
				if isVisibleCandidate(m) then
					local distance = (m:GetPivot().Position - cam.CFrame.Position).Magnitude
					if distance < 100 then
						table.insert(near, { model = m, distance = distance })
					end
				end
			end
		end
		if #near > 0 and not ready then
			if not initStarted then
				initStarted = true
				task.spawn(initResources)
			end
			near = {}
		end
		table.sort(near, function(a, b) return a.distance < b.distance end)
		local keep = {}
		for i = 1, math.min(2, #near) do
			local m = near[i].model
			keep[m] = true
			if not active[m] and not pending[m] then
				task.spawn(build, m)
			end
		end
		for m in active do
			if not keep[m] then remove(m) end
		end
	end
	if next(active) and t >= nextImage then
		nextImage = t + 1 / 30
		drift(t)
	end
	for m, rec in active do
		if not m:IsDescendantOf(workspace) then
			remove(m)
			continue
		end
		if rec.aura then
			rec.aura.CFrame = m:GetPivot() * rec.auraOffset
		end
		for _, r in rec.parts do
			if r.source.Parent then
				r.shell.CFrame = r.source.CFrame
				r.shell.LocalTransparencyModifier = r.source.LocalTransparencyModifier
				r.shell.Transparency = r.source.Transparency >= 1 and 1 or r.opacity
				for _, pair in r.bones do
					if pair[1].Parent and pair[2].Parent then
						pair[2].Transform = pair[1].Transform
					end
				end
			end
		end
	end
end)

script.Destroying:Connect(function()
	connection:Disconnect()
	addedConn:Disconnect()
	removingConn:Disconnect()
	for m in active do remove(m) end
	for _, v in createdObjects do
		v:Destroy()
	end
end)
