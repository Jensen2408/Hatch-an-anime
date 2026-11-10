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

local originalNormal = track(Assets:CreateEditableImageAsync(Content.fromUri("rbxassetid://122481203141794")))
local faceImage = track(Assets:CreateEditableImageAsync(Content.fromUri("rbxassetid://131043949385474")))
local faceMask = track(Assets:CreateEditableImageAsync(Content.fromUri("rbxassetid://81291379703357")))
local faceSurface = track(Assets:CreateSurfaceAppearanceAsync({
	ColorMap = Content.fromObject(faceImage),
	NormalMap = Content.fromObject(originalNormal),
	EmissiveMask = Content.fromObject(faceMask),
	RoughnessMap = Content.fromObject(makeSolid(Color3.new(1, 1, 1))),
	MetalnessMap = Content.fromObject(makeSolid(Color3.new(0, 0, 0))),
}))
faceSurface.Name = "GalaxyBase"
faceSurface.EmissiveStrength = 1.85

-- Rich cosmic violet/indigo base with original voxel cube normal bevels
local tintNormal = track(Assets:CreateEditableImageAsync(Content.fromUri("rbxassetid://122481203141794")))
local tintImage = track(Assets:CreateEditableImageAsync(Content.fromUri("rbxassetid://92565503187719")))
local dims = tintImage.Size
local tintPixels = tintImage:ReadPixelsBuffer(Vector2.zero, dims)
for i = 0, dims.X * dims.Y - 1 do
	local p = i * 4
	local r = buffer.readu8(tintPixels, p) / 255
	local g = buffer.readu8(tintPixels, p + 1) / 255
	local b = buffer.readu8(tintPixels, p + 2) / 255
	local lum = r * 0.3 + g * 0.5 + b * 0.2
	buffer.writeu8(tintPixels, p, math.floor(math.clamp(0.035 + lum * 0.30, 0, 1) * 255))
	buffer.writeu8(tintPixels, p + 1, math.floor(math.clamp(0.015 + lum * 0.16, 0, 1) * 255))
	buffer.writeu8(tintPixels, p + 2, math.floor(math.clamp(0.095 + lum * 0.50, 0, 1) * 255))
end
tintImage:WritePixelsBuffer(Vector2.zero, dims, tintPixels)
local tintSurface = track(Assets:CreateSurfaceAppearanceAsync({
	ColorMap = Content.fromObject(tintImage),
	NormalMap = Content.fromObject(tintNormal),
	EmissiveMask = Content.fromObject(makeSolid(Color3.new(0, 0, 0))),
	RoughnessMap = Content.fromObject(makeSolid(Color3.new(1, 1, 1))),
	MetalnessMap = Content.fromObject(makeSolid(Color3.new(0, 0, 0))),
}))
tintSurface.Name = "GalaxyBase"

-- Decode baked 256x256 seamless ColorMap for the SINGLE animated layer
-- Populate driftImage BEFORE CreateSurfaceAppearanceAsync so the GPU texture backing initializes with valid opaque texels.
local colorBytes = decodeParts(mapData.Color)
local colorTile = track(Assets:CreateEditableImage({ Size = DIMS }))
colorTile:WritePixelsBuffer(Vector2.zero, DIMS, colorBytes)

local driftImage = track(Assets:CreateEditableImage({ Size = DIMS }))
driftImage:WritePixelsBuffer(Vector2.zero, DIMS, colorBytes)

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
drift(0)

local coat = track(Assets:CreateSurfaceAppearanceAsync({
	ColorMap = Content.fromObject(driftImage),
	EmissiveMask = Content.fromObject(makeSolid(Color3.new(1, 1, 1))),
	RoughnessMap = Content.fromObject(makeSolid(Color3.new(1, 1, 1))),
	MetalnessMap = Content.fromObject(makeSolid(Color3.new(0, 0, 0))),
}))
coat.Name = "GalaxyDrift"
coat.EmissiveStrength = 1.35

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
		local original = p:FindFirstChildOfClass("SurfaceAppearance")
		if original then original.Parent = nil end
		local head = partIndex and partIndex >= 6
		local base = head and faceSurface or tintSurface
		base:Clone().Parent = p
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
local candidates = {}
local function watchInstance(inst)
	if inst:IsA("Model") and not inst:IsA("Tool") then
		if inst:GetAttribute("GalaxyPrototype") == true then
			candidates[inst] = true
		end
		inst:GetAttributeChangedSignal("GalaxyPrototype"):Connect(function()
			if inst:GetAttribute("GalaxyPrototype") == true then
				candidates[inst] = true
			else
				candidates[inst] = nil
				remove(inst)
			end
		end)
	end
end

for _, inst in workspace:GetDescendants() do
	watchInstance(inst)
end
local addedConn = workspace.DescendantAdded:Connect(watchInstance)
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
				if not m:IsDescendantOf(workspace) then
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
		table.sort(near, function(a, b) return a.distance < b.distance end)
		local keep = {}
		for i = 1, math.min(2, #near) do
			local m = near[i].model
			keep[m] = true
			build(m)
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
