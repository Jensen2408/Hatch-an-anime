--[[ ReplicatedStorage.IncubatorController (ModuleScript)
Brings the viewer behaviour into Roblox for the imported incubators (L1 / L2 / L3):
  • sliding glass doors (GlassLeft / GlassRight slide 2.5 studs sideways into the frame)
  • egg shake, jade glow pulse, warm lantern lights (L3)
  • a full Hatch() sequence: shake → flash → doors open → character appears on the egg platform
Setup also fixes import details: clear glass, Neon glow parts, real PointLights.

USAGE (Script in ServerScriptService):
  local Incubator = require(game.ReplicatedStorage.IncubatorController)
  local inc = Incubator.new(workspace.Incubator_L1_Apprentice)
  inc:Hatch(game.ServerStorage.Characters.TideCaptain, workspace.MyEgg) -- egg model optional
  -- or: inc:Open()  inc:Close()  inc:Shake(1.5)
--]]
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Incubator = {}
Incubator.__index = Incubator

local SLIDE = 2.5                       -- studs each door travels (matches the design)
local JADE = Color3.fromRGB(95, 224, 176)
local WARM = Color3.fromRGB(255, 184, 102)
local GLOW_WORDS = { "Jade", "Backlight", "Indicator_Cell", "Eave_Light", "Crown_Jewel", "Liquid" }
local WARM_WORDS = { "Lantern_Glow" }

local function has(name, words) for _, w in words do if string.find(name, w, 1, true) then return true end end return false end
local function find(root, name) return root:FindFirstChild(name, true) end
local function partsOf(x) local t = {}; if x:IsA("BasePart") then t[1] = x end; for _, d in x:GetDescendants() do if d:IsA("BasePart") then table.insert(t, d) end end; return t end
local function pivotOf(x) return x:IsA("Model") and x:GetPivot() or x.CFrame end
local function setPivot(x, cf) if x:IsA("Model") then x:PivotTo(cf) else x.CFrame = cf end end

function Incubator.new(model)
	assert(model and model:IsA("Model"), "Incubator.new needs the incubator Model")
	local self = setmetatable({ model = model, open = false, busy = false }, Incubator)
	local origin = model:GetPivot()
	self.right = origin.RightVector

	-- materials fixed for Roblox
	for _, p in partsOf(model) do
		p.Anchored = true
		if p.Name:find("Pane", 1, true) or p.Name:match("Glass%d*$") then
			p.Material = Enum.Material.Glass; p.Transparency = 0.82; p.CastShadow = false
		elseif has(p.Name, GLOW_WORDS) then
			p.Material = Enum.Material.Neon; p.Color = string.find(p.Name, "Dim", 1, true) and JADE:Lerp(Color3.new(0, 0, 0), 0.45) or JADE
			if string.find(p.Name, "Liquid", 1, true) then p.Transparency = 0.35 end
		elseif has(p.Name, WARM_WORDS) then
			p.Material = Enum.Material.Neon; p.Color = WARM
		end
	end

	-- doors: remember closed pivots; left slides toward -Right, right toward +Right (model space)
	self.doors = {}
	for _, n in { "GlassLeft", "GlassRight" } do
		local d = find(model, n)
		if d then table.insert(self.doors, { obj = d, closed = pivotOf(d), dir = (n == "GlassLeft" and -1 or 1) }) end
	end

	-- egg spot = top centre of the egg platform
	local plat = find(model, "EggPlatform")
	if plat then
		local cf, size
		if plat:IsA("Model") then cf, size = plat:GetBoundingBox() else cf, size = plat.CFrame, plat.Size end
		self.eggCF = CFrame.new(cf.Position + origin.UpVector * (size.Y / 2)) * origin.Rotation
	else
		self.eggCF = origin * CFrame.new(0, 2.25, 1.5)
	end

	-- lights (GLB lights don't import)
	local holder = Instance.new("Part")
	holder.Name = "IncubatorFX"; holder.Transparency = 1; holder.Anchored = true; holder.CanCollide = false; holder.CanQuery = false; holder.CanTouch = false
	holder.Size = Vector3.new(0.2, 0.2, 0.2); holder.CFrame = self.eggCF * CFrame.new(0, 3.3, 0); holder.Parent = model
	self.light = Instance.new("PointLight"); self.light.Color = JADE; self.light.Brightness = 1.6; self.light.Range = 11; self.light.Shadows = false; self.light.Parent = holder
	for _, p in partsOf(model) do
		if has(p.Name, WARM_WORDS) and not p:FindFirstChildOfClass("PointLight") then
			local l = Instance.new("PointLight"); l.Color = WARM; l.Brightness = 0.9; l.Range = 7; l.Parent = p
		end
	end
	-- burst emitter for the hatch flash
	local att = Instance.new("Attachment"); att.CFrame = holder.CFrame:ToObjectSpace(self.eggCF * CFrame.new(0, 1.5, 0)); att.Parent = holder
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Rate = 0; e.LightEmission = 1; e.LightInfluence = 0
	e.Color = ColorSequence.new(JADE, Color3.fromRGB(255, 240, 200)); e.Speed = NumberRange.new(4, 9); e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.5, 0.9); e.Drag = 4
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }); e.Parent = att
	self.burst = e

	-- idle glow breathing
	self._pulse = RunService.Heartbeat:Connect(function()
		if not model.Parent then self:Destroy(); return end
		if not self.busy then self.light.Brightness = 1.4 + 0.4 * math.sin(os.clock() * 1.5) end
	end)
	return self
end

local function tweenPivot(obj, from, to, t, style)
	local v = Instance.new("NumberValue")
	local con = v.Changed:Connect(function(a) setPivot(obj, from:Lerp(to, a)) end)
	local tw = TweenService:Create(v, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Value = 1 })
	tw:Play(); tw.Completed:Wait(); con:Disconnect(); v:Destroy()
end

function Incubator:_slide(open, t)
	local jobs = 0
	for _, d in self.doors do
		jobs += 1
		local target = open and (d.closed + self.right * (d.dir * SLIDE)) or d.closed
		task.spawn(function() tweenPivot(d.obj, pivotOf(d.obj), target, t or 0.7); jobs -= 1 end)
	end
	while jobs > 0 do task.wait() end
	self.open = open
	self.model:SetAttribute("DoorsOpen", open)
end
function Incubator:Open(t) if not self.open then self:_slide(true, t) end end
function Incubator:Close(t) if self.open then self:_slide(false, t) end end

function Incubator:PlaceEgg(egg)
	if not egg then return end
	local _, size = egg:GetBoundingBox()
	egg:PivotTo(self.eggCF * CFrame.new(0, size.Y / 2, 0))
	self.egg = egg
end

function Incubator:Shake(duration)
	duration = duration or 1.6
	local egg = self.egg; if not egg then task.wait(duration); return end
	local base = egg:GetPivot(); local t0 = os.clock()
	while os.clock() - t0 < duration do
		local t = os.clock() - t0
		local amp = math.min(1, t * 4) * (0.45 + 0.55 * t / duration)   -- builds up toward the hatch
		local rz, rx = math.sin(t * 38) * 0.16 * amp, math.sin(t * 29) * 0.07 * amp
		egg:PivotTo(base * CFrame.new(0, math.abs(math.sin(t * 19)) * 0.1 * amp, 0) * CFrame.Angles(rx, 0, rz))
		self.light.Brightness = 1.6 + 2.5 * amp * (0.5 + 0.5 * math.sin(t * 25))
		task.wait()
	end
	egg:PivotTo(base)
end

-- Full sequence. character: a Model to reveal (cloned). egg: optional egg Model already in the world.
function Incubator:Hatch(character, egg)
	if self.busy then return end
	self.busy = true
	if egg then self:PlaceEgg(egg) end
	self:Close(0.4)
	self:Shake(1.8)
	self.burst:Emit(60)
	self.light.Brightness = 6
	if self.egg then self.egg:Destroy(); self.egg = nil end
	local revealed
	if character then
		revealed = character:Clone()
		local _, size = revealed:GetBoundingBox()
		revealed:PivotTo(self.eggCF * CFrame.new(0, size.Y / 2, 0) * CFrame.Angles(0, math.pi, 0)) -- face the walkway
		for _, p in partsOf(revealed) do p.Anchored = true end
		revealed.Parent = self.model
	end
	TweenService:Create(self.light, TweenInfo.new(0.8), { Brightness = 1.6 }):Play()
	self:Open(0.8)
	self.busy = false
	return revealed
end

function Incubator:Destroy()
	if self._pulse then self._pulse:Disconnect(); self._pulse = nil end
end

return Incubator

