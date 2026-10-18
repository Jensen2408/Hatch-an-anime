--[[ StarterPlayerScripts.FloatingCharacters  (LocalScript)
Showcase float for placed characters. No particles.
  • slow hover with a slight breathe
  • every 6.6 s: an eased 360° showcase spin with a small lift
  • a contact shadow that shrinks as the character rises
  • a thin ring that ripples out each time it reaches the bottom of its bob
Cosmetic and client-only. The server's model never moves.

Tag each placed character Model with "FloatingCharacter" (server, after placing).
Optional attributes: FloatHeight (default 1.15), FloatFacing (extra yaw in degrees).
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Config = {
	Tag = "FloatingCharacter",
	Height = 1.15, Bob = 0.3, Period = 2.8,
	Cycle = 6.6, SpinStart = 5, SpinTime = 1.6, SpinLift = 0.55,
	SwayYaw = 8, SwayTilt = 0,
	MaxDistance = 140,
	Cream = Color3.fromRGB(255, 243, 207),
}

local active = {}
local function easeIO(x) if x < 0.5 then return 4 * x * x * x end return 1 - ((-2 * x + 2) ^ 3) / 2 end

local function fxPart(name, size, color, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size, p.Color, p.Material = size, color, Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	return p
end

local function add(model)
	if active[model] or not model:IsA("Model") then return end
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then d.Anchored = true end end
	local base = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local groundY = base.Position.Y - size.Y / 2
	local ground = Vector3.new(base.Position.X, groundY, base.Position.Z)
	local folder = Instance.new("Folder"); folder.Name = "FloatFX"; folder.Parent = workspace
	local shadow = fxPart("Shadow", Vector3.new(0.05, size.X * 1.2, size.X * 1.2), Color3.fromRGB(30, 20, 12), Enum.PartType.Cylinder)
	shadow.CFrame = CFrame.new(ground + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90))
	shadow.Parent = folder
	local ring = fxPart("Ring", Vector3.new(1, 0.05, 1), Config.Cream); ring.Transparency = 1
	ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.03, 0)); ring.Parent = folder
	local sel = Instance.new("SelectionBox")
	sel.Adornee, sel.Color3, sel.LineThickness, sel.SurfaceTransparency, sel.Transparency = ring, Config.Cream, 0.06, 1, 1
	sel.Parent = ring
	active[model] = { base = base, size = size, ground = ground, shadow = shadow, ring = ring, sel = sel,
		folder = folder, seed = 0, lastLow = -10 }
end

local function remove(model)
	local s = active[model]
	if not s then return end
	active[model] = nil
	s.folder:Destroy()
	if model.Parent then model:PivotTo(s.base) end
end

for _, m in CollectionService:GetTagged(Config.Tag) do task.spawn(add, m) end
CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(add)
CollectionService:GetInstanceRemovedSignal(Config.Tag):Connect(remove)

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local now = workspace:GetServerTimeNow()
	for model, s in active do
		if not model.Parent then remove(model) continue end
		if (s.base.Position - camPos).Magnitude > Config.MaxDistance then continue end
		local t = now + s.seed
		local c = t % Config.Cycle
		local spinA = c > Config.SpinStart and math.min(1, (c - Config.SpinStart) / Config.SpinTime) or 0
		local sp = easeIO(spinA)
		local arc = math.sin(spinA * math.pi)
		local bob = math.sin(t * math.pi * 2 / Config.Period)
		local h = (model:GetAttribute("FloatHeight") or Config.Height) + Config.Bob * bob + Config.SpinLift * arc
		local sway = (1 - arc) * math.rad(Config.SwayYaw) * math.sin(t * 0.55)
		local yaw = math.rad(model:GetAttribute("FloatFacing") or 0) + sway + sp * math.pi * 2
		local tilt = math.rad(Config.SwayTilt) * (1 - arc)
		model:PivotTo(s.base * CFrame.new(0, h, 0) * CFrame.Angles(tilt * math.sin(t * 1.3), yaw, tilt * 0.8 * math.sin(t * 1.7 + 1)))
		local k = math.clamp((h - 0.85) / 1.15, 0, 1)
		local d = s.size.X * (1.25 - 0.35 * k)
		s.shadow.Size = Vector3.new(0.05, d, d)
		s.shadow.Transparency = 0.45 + 0.4 * k
		local phase = (t / Config.Period) % 1
		if phase > 0.74 and phase < 0.8 and t - s.lastLow > 1 then s.lastLow = t end
		local r = math.min(1, (t - s.lastLow) / 1.1)
		local w = s.size.X * (1.1 + r * 1.1)
		s.ring.Size = Vector3.new(w, 0.05, w)
		s.sel.Transparency = 1 - 0.6 * (1 - r) * math.min(1, r * 8)
	end
end)

