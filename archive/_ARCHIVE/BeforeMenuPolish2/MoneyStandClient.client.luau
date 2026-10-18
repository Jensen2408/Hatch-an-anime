--[[ StarterPlayerScripts.MoneyStandClient  (LocalScript)
Cosmetic only: plate spring, shine, +$ text, gold squares, display countdown and sounds.
Reads the server's Pressed / Stored attributes and MoneyCollected event. Never grants money.
]]
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local Config = {
	PressDepth = 0.16,
	-- Sound slots: paste verified Creator Store IDs. Empty = silent.
	Sounds = { PlatePress = "", PlateRelease = "", CollectChime = "", Empty = "" },
	Volume = 0.5,
	SoundGroup = "SFX",
}
local GOLD = Color3.fromRGB(255, 207, 85)

local function fmt(n)
 return require(game:GetService("ReplicatedStorage").CharacterInventory.InventoryFormat).Money(n)
end

local function sound(model, name)
	local id = Config.Sounds[name]
	if not id or id == "" then return end
	local s = Instance.new("Sound")
	s.SoundId, s.Volume, s.RollOffMaxDistance = id, Config.Volume, 60
	local g = SoundService:FindFirstChild(Config.SoundGroup)
	if g and g:IsA("SoundGroup") then s.SoundGroup = g end
	s.Parent = model:FindFirstChild("Plate") or model
	s:Play()
	Debris:AddItem(s, 4)
end

local stands = {}

local function setStatus(st, text, dim)
	if st.status then st.status.Text = text end
	if st.amount then st.amount.TextColor3 = dim and Color3.fromRGB(138, 124, 102) or Color3.fromRGB(255, 246, 220) end
end

local function press(st, down)
	if st.pressTween then st.pressTween:Cancel() end
	local cf = down and st.restCF * CFrame.new(0, -Config.PressDepth, 0) or st.restCF
	-- Back easing gives the small spring overshoot
	st.pressTween = TweenService:Create(st.plate, TweenInfo.new(down and 0.14 or 0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = cf })
	st.pressTween:Play()
	sound(st.model, down and "PlatePress" or "PlateRelease")
	if down then setStatus(st, "COLLECTED", false) elseif not st.busy then setStatus(st, (st.model:GetAttribute("Stored") or 0) >= 1 and "STEP TO COLLECT" or "EMPTY", false) end
end

local function shine(st)
	local g = st.shineGrad
	if not g then return end
	g.Offset = Vector2.new(-1, 0)
	st.shineFrame.BackgroundTransparency = 0
	local tw = TweenService:Create(g, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) })
	tw:Play()
	tw.Completed:Once(function() st.shineFrame.BackgroundTransparency = 1 end)
end

local function popText(st, amount)
	local a = Instance.new("Part")
	a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch, a.Transparency = true, false, false, false, 1
	a.Size = Vector3.new(0.2, 0.2, 0.2)
	a.CFrame = st.restCF * CFrame.new(0, 2.2, 0)
	a.Parent = workspace
	local bb = Instance.new("BillboardGui")
	bb.Size, bb.AlwaysOnTop, bb.LightInfluence = UDim2.fromOffset(220, 56), true, 0
	bb.Parent = a
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	t.Font, t.TextScaled, t.Text, t.TextColor3 = Enum.Font.FredokaOne, true, "+" .. fmt(amount), Color3.fromRGB(255, 224, 138)
	local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Color = Color3.fromRGB(12, 14, 13); stroke.Parent = t
	t.Parent = bb
	TweenService:Create(a, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = a.CFrame * CFrame.new(0, 2.2, 0) }):Play()
	task.delay(0.55, function()
		TweenService:Create(t, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.45), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(a, 1.1)
end

local function burst(st)
	for i = 1, 8 do
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Size = Vector3.new(0.25, 0.25, 0.25)
		p.Color, p.Material = GOLD, Enum.Material.Neon
		local a = (i / 8) * math.pi * 2
		local start = st.restCF * CFrame.new(math.cos(a) * 0.6, 0.4, math.sin(a) * 0.6)
		p.CFrame = start
		p.Parent = workspace
		local vel = Vector3.new(math.cos(a) * 1.8, 5 + math.random() * 2, math.sin(a) * 1.8)
		local t0, life = os.clock(), 0.65 + math.random() * 0.2
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if t >= life or not p.Parent then conn:Disconnect(); p:Destroy(); return end
			local pos = start.Position + vel * t + Vector3.new(0, -8 * t * t, 0)
			local k = t / life
			p.Size = Vector3.new(0.25, 0.25, 0.25) * (k > 0.7 and (1 - (k - 0.7) / 0.3) or 1)
			p.CFrame = CFrame.new(pos) * CFrame.Angles(t * 7, t * 5, 0)
		end)
	end
end

local function countdown(st, amount)
	st.busy = true
	setStatus(st, "COLLECTING", false)
	local v = Instance.new("NumberValue"); v.Value = amount
	local c = v.Changed:Connect(function(x) if st.amount then st.amount.Text = fmt(x) end end)
	local tw = TweenService:Create(v, TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Value = 0 })
	tw:Play()
	tw.Completed:Wait()
	c:Disconnect(); v:Destroy()
	setStatus(st, "EMPTY", true)
	task.wait(0.6)
	st.busy = false
	setStatus(st, st.model:GetAttribute("Pressed") and "COLLECTED" or "STEP TO COLLECT", false)
end

local function add(model)
	if stands[model] then return end
	local plate = model:WaitForChild("Plate", 10)
	if not plate then return end
	local display = model:FindFirstChild("Display", true)
	local gui = display and display:FindFirstChild("Screen")
	local st = { model = model, plate = plate, restCF = plate.CFrame, busy = false,
		amount = gui and gui:FindFirstChild("Amount", true), status = gui and gui:FindFirstChild("Status", true) }
	local sg = plate:FindFirstChild("Shine")
	if sg then st.shineFrame = sg:FindFirstChild("Band"); st.shineGrad = st.shineFrame and st.shineFrame:FindFirstChildOfClass("UIGradient") end
	stands[model] = st
	local function refresh()
		if st.busy or not st.amount then return end
		local v = model:GetAttribute("Stored") or 0
		st.amount.Text = fmt(v)
		if not model:GetAttribute("Pressed") then setStatus(st, v >= 1 and "STEP TO COLLECT" or "EMPTY", v < 1) end
	end
	model:GetAttributeChangedSignal("Stored"):Connect(refresh)
	model:GetAttributeChangedSignal("Pressed"):Connect(function() press(st, model:GetAttribute("Pressed") == true) end)
	refresh()
end

for _, m in CollectionService:GetTagged("MoneyStand") do task.spawn(add, m) end
CollectionService:GetInstanceAddedSignal("MoneyStand"):Connect(add)
CollectionService:GetInstanceRemovedSignal("MoneyStand"):Connect(function(m) stands[m] = nil end)

ReplicatedStorage:WaitForChild("MoneyCollected").OnClientEvent:Connect(function(model, amount)
	local st = stands[model]
	if not st then return end
	if amount <= 0 then sound(model, "Empty"); setStatus(st, "EMPTY", true) return end
	sound(model, "CollectChime")
	popText(st, amount)
	burst(st)
	task.spawn(countdown, st, amount)
end)

