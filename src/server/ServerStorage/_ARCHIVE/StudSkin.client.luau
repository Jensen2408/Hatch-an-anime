-- StudSkin: the game's UI stud look.
-- 1) hides every pill stud (frames named Stud / Studs / StudBand) inside and outside all UIs,
-- 2) puts the star-stud texture on the surface where those pills were, on the HUD buttons, the cash panel
--    and every old "StudTex" surface. Cosmetic only. Texture id + strength are attributes on this script.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local TEX = script:GetAttribute("Texture")
local ALPHA = script:GetAttribute("Strength") or 0.62
local TILE = script:GetAttribute("TilePx") or 240
local PILLS = { Stud = true, Studs = true, StudBand = true }
local EXTRA = {}
local done = setmetatable({}, { __mode = "k" })

local function skin(obj, inset)
	if done[obj] or not obj:IsA("GuiObject") or TEX == "" then return end
	if obj:FindFirstChildWhichIsA("UIGridStyleLayout") then return end
	if not obj:IsA("GuiButton") then return end
	if obj.Name == "Dim" or (obj.Size.X.Scale >= 0.95 and obj.Size.Y.Scale >= 0.95 and obj.Parent and obj.Parent:IsA("LayerCollector")) then return end
	done[obj] = true
	local im = Instance.new("ImageLabel")
	im.Name = "StarStuds"; im.BackgroundTransparency = 1; im.Image = TEX
	im.ScaleType = Enum.ScaleType.Tile; im.TileSize = UDim2.fromOffset(TILE, TILE); im.ImageColor3 = Color3.new(1, 1, 1); im.ImageTransparency = ALPHA
	im.AnchorPoint = Vector2.new(0, 0); im.Position = UDim2.fromOffset(0, 0)
	im.Size = UDim2.fromScale(1, 1)
	im.ZIndex = obj.ZIndex; im.Active = false; im.Interactable = false
	local c = (not obj:IsA("GuiButton")) and obj:FindFirstChildOfClass("UICorner")
	if c then c:Clone().Parent = im elseif inset and inset > 0 then local u = Instance.new("UICorner"); u.CornerRadius = UDim.new(0.12, 0); u.Parent = im end
	im.Parent = obj
	local function fit()
		local a = obj.AbsoluteSize
		local m = math.min(a.X, a.Y)
		if m < 34 then im.Visible = false return end
		im.Visible = true
		local t = math.clamp(math.floor(m / 5), 10, TILE)
		im.TileSize = UDim2.fromOffset(t, t)
		local c = obj.BackgroundColor3
		local lum = c.R * 0.3 + c.G * 0.59 + c.B * 0.11
		im.ImageTransparency = lum > 0.75 and math.min(0.8, ALPHA + 0.3) or ALPHA
	end
	fit(); obj:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	-- keep text, icons and inner panels above the studs
	for _, ch in obj:GetChildren() do
		if ch ~= im and ch:IsA("GuiObject") and ch.Name ~= "StarStuds" and ch.ZIndex <= im.ZIndex then ch.ZIndex = im.ZIndex + 1 end
	end
end

local function handle(d)
	if not d:IsA("GuiObject") then return end
	local sg = d:FindFirstAncestorWhichIsA("LayerCollector")
	if sg and (sg.Name:find("Loading") or sg.Name == "JoinArrivalUI" or sg.Name == "CinematicHatchUI" or sg.Name == "CineCamUI" or sg.Name == "Freecam") then return end
	if d.Name == "StarStuds" or d:FindFirstAncestor("TrailerTitle") or d:FindFirstAncestor("TrailerStatus") then return end
	-- every visible frame / button gets the star texture, cropped to its own size
	if d:IsA("GuiButton") and d.BackgroundTransparency < 0.5 then
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		task.defer(function()
			if not (d.Size.X.Scale >= 0.95 and d.Size.Y.Scale >= 0.95) and d.Name ~= "Dim" and d.AbsoluteSize.X < vp.X * 0.85 and d.AbsoluteSize.Y < vp.Y * 0.85 then skin(d, 0) end
		end)
	end
	-- buttons: sharp corners + black outline
	if d:IsA("GuiButton") then
		for _, c in d:GetChildren() do if c:IsA("UICorner") then c.CornerRadius = UDim.new(0, 0) end end
		local st = d:FindFirstChildOfClass("UIStroke")
		if not st and d.BackgroundTransparency < 0.5 then st = Instance.new("UIStroke"); st.Parent = d end
		if st then
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; st.Color = d.BackgroundColor3:Lerp(Color3.new(0, 0, 0), 0.45); st.Thickness = 2
		end
	end
	if d:IsA("Frame") and d.BackgroundTransparency < 0.5 and d.AbsoluteSize.X > 120 and d:FindFirstAncestor("OwnerPanel") then skin(d, 0) end
	if PILLS[d.Name] then
		d.Visible = false
		d:GetPropertyChangedSignal("Visible"):Connect(function() if d.Visible then d.Visible = false end end)
		local host = d.Parent
		
	elseif d.Name == "StudTex" and d:IsA("ImageLabel") and not d:FindFirstAncestorWhichIsA("GuiButton") then
		d.Visible = false
	elseif d.Name == "StudTex" and d:IsA("ImageLabel") and TEX ~= "" then
		d.Image = TEX; d.ScaleType = Enum.ScaleType.Tile; d.TileSize = UDim2.fromOffset(TILE, TILE); d.ImageColor3 = Color3.new(1, 1, 1); d.ImageTransparency = ALPHA
	elseif EXTRA[d.Name] then
		local face = (d:FindFirstChild("Outer") and d.Outer:FindFirstChild("Face")) or d:FindFirstChild("Face") or d.Parent and d
		if not d:FindFirstChild("Outer") and not d:FindFirstChild("Face") then task.delay(1, function() local f = (d:FindFirstChild("Outer") and d.Outer:FindFirstChild("Face")) or d:FindFirstChild("Face") or d; skin(f, 0) end) else skin(face, 0) end
	end
end

local function watch(root)
	for _, d in root:GetDescendants() do task.defer(handle, d) end
	root.DescendantAdded:Connect(function(d) task.defer(handle, d) end)
end
watch(pg)
-- boards in the world (leaderboard shrine etc.)
for _, g in workspace:GetDescendants() do if g:IsA("SurfaceGui") then watch(g) end end
workspace.DescendantAdded:Connect(function(g) if g:IsA("SurfaceGui") then watch(g) end end)
