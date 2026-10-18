--[[ StarterPlayerScripts.CharacterInfoClient  (LocalScript)
Held card (ScreenGui, bottom centre) + placed labels (BillboardGui per placed model).
Display only. Reads server-set attributes through ReplicatedStorage.CharacterInfo.Adapter.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local folder = ReplicatedStorage:WaitForChild("CharacterInfo")
local Adapter = require(folder:WaitForChild("Adapter"))
local S = require(folder:WaitForChild("Style"))
local player = Players.LocalPlayer

---------------------------------------------------------------- HELD CARD
local HELD = { w = 372, h = 132, studs = 7, studW = 14, studGap = 30, nameSize = 24, powerSize = 32, incSize = 20, badge = 11, labelSize = 12, padX = 18, padY = 14, rowGap = 8 }
local gui = S.make("ScreenGui", { Name = "CharacterInfoHeld", ResetOnSpawn = false, Enabled = false, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))
local holder = S.make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -84), Size = UDim2.fromOffset(HELD.w, HELD.h + 12), BackgroundTransparency = 1 }, gui)
local fit = S.make("UIScale", {}, holder)
local held = S.Card(holder, HELD)
-- footer: divider + F Drop hint / touch button
local footY = held.y2 + HELD.labelSize + HELD.powerSize + 14
S.make("Frame", { Position = UDim2.fromOffset(18, footY), Size = UDim2.new(1, -36, 0, 2), BackgroundColor3 = Color3.fromRGB(217, 191, 146), BorderSizePixel = 0, ZIndex = 4 }, held.card)
local hintRow = S.make("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, footY + 7), Size = UDim2.fromOffset(120, 26), BackgroundTransparency = 1, ZIndex = 4 }, held.card)
local key = S.make("TextLabel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -46, 0.5, 0), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = Color3.new(1, 1, 1), FontFace = S.Font, TextSize = 13, TextColor3 = S.Ink, Text = Adapter.DropKey.Name, ZIndex = 5 }, hintRow)
S.corner(key, 6); S.stroke(key, 2)
S.label(hintRow, "Drop", 14, S.Ink, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(40, 20), TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 5 })
local touchBtn = S.make("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, footY + 6), Size = UDim2.fromOffset(86, 30), BackgroundColor3 = Color3.fromRGB(232, 69, 44), FontFace = S.Font, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Text = "Drop", Visible = false, ZIndex = 5 }, held.card)
S.corner(touchBtn, 10); S.stroke(touchBtn, 2.5)
local detail = S.label(held.card, "", 12, S.Muted, { Position = UDim2.fromOffset(18, footY + 10), Size = UDim2.new(1, -170, 0, 18), ZIndex = 4 })

local function refit()
	local v = workspace.CurrentCamera.ViewportSize
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	fit.Scale = math.clamp(math.min(v.X / 520, v.Y / 820), 0.7, 1)
	holder.Position = UDim2.new(0.5, 0, 1, touch and -150 or -84) -- clear of the jump button / hotbar
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refit); refit()

local current, conns = nil, {}
local function disconnect() for _, c in conns do c:Disconnect() end; table.clear(conns) end
local function updateHeld(first)
	local data = current and Adapter.Read(current)
	if not data then gui.Enabled = false; return end
	local wasEx = held.stripe.Visible
	S.Apply(held, data)
	detail.Text = ("Power %s"):format(S.Full(data.power))
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	touchBtn.Visible = touch and Adapter.Drop ~= nil
	hintRow.Visible = not touch
	if data.exceptional and (first or not wasEx) then S.Celebrate(held, Adapter.ReducedMotion()) end
end
local function showTool(tool)
	disconnect()
	current = tool
	for _, a in Adapter.Watched() do table.insert(conns, tool:GetAttributeChangedSignal(a):Connect(function() updateHeld(false) end)) end
	updateHeld(true)
	if not Adapter.Read(tool) then return end
	gui.Enabled = true
	if Adapter.ReducedMotion() then holder.Position = UDim2.new(0.5, 0, 1, holder.Position.Y.Offset); return end
	local target = holder.Position
	holder.Position = target + UDim2.fromOffset(0, 18)
	TweenService:Create(holder, TweenInfo.new(0.42, Enum.EasingStyle.Back), { Position = target }):Play()
end
local function hide() disconnect(); current = nil; gui.Enabled = false; refit() end
touchBtn.Activated:Connect(function() if current and Adapter.Drop then Adapter.Drop(current) end end)

local function watchCharacter(char)
	hide()
	local function check(child) if Adapter.IsCharacterTool(child) then showTool(child) end end
	for _, c in char:GetChildren() do check(c) end
	char.ChildAdded:Connect(check) -- equip
	char.ChildRemoved:Connect(function(c) if c == current then hide() end end) -- unequip / drop / place
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.Died:Connect(hide) end
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then watchCharacter(player.Character) end

---------------------------------------------------------------- PLACED LABELS
local PLACED = { w = 228, h = 82, studs = 3, studW = 12, studGap = 34, nameSize = 17, powerSize = 21, incSize = 14, badge = 9, labelSize = 9, padX = 13, padY = 9, rowGap = 5 }
local STUDS_W = 4.4   -- in-world width in studs (shrinks with distance, never grows)
local FADE_START, FADE_END = 45, 60
local labels = {}
local pending = {} -- tagged models whose Power hasn't replicated yet

local function topOffset(model)
	local cf, size = model:GetBoundingBox()
	local pivot = model:GetPivot().Position
	return (cf.Position.Y + size.Y / 2) - pivot.Y + 1.2
end
local addLabel
addLabel = function(model)
	if labels[model] or not model:IsA("Model") then return end
	local data = Adapter.Read(model)
	if not data then
		-- the tag can arrive before the server's Power attribute: try again once it does
		if not pending[model] then
			pending[model] = model:GetAttributeChangedSignal(Adapter.Attr.Power):Connect(function()
				local c = pending[model]; pending[model] = nil; if c then c:Disconnect() end
				if CollectionService:HasTag(model, Adapter.PlacedTag) then addLabel(model) end
			end)
		end
		return
	end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true); if not anchor then return end
	local bb = S.make("BillboardGui", { Name = "CharacterInfoLabel", Adornee = anchor, LightInfluence = 0, AlwaysOnTop = false, ResetOnSpawn = false,
		Size = UDim2.new(STUDS_W, 0, STUDS_W * (PLACED.h + 18) / PLACED.w, 0), StudsOffsetWorldSpace = Vector3.new(0, topOffset(model) - (anchor.Position.Y - model:GetPivot().Position.Y), 0),
		MaxDistance = FADE_END + 2 }, player.PlayerGui)
	local group = S.make("CanvasGroup", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), GroupTransparency = 1 }, bb)
	-- drop shadow behind the label
	local shadow = S.make("Frame", { Position = UDim2.new(0, 4, 0, 16), Size = UDim2.new(1, -8, 1, -18), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.72 }, group)
	S.corner(shadow, 14)
	local inner = S.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(PLACED.w, PLACED.h + 12) }, group)
	local sc = S.make("UIScale", {}, inner)
	local ui = S.Card(inner, PLACED)
	local st = { bb = bb, group = group, ui = ui, scale = sc, model = model, conns = {} }
	labels[model] = st
	local function upd(first)
		local d = Adapter.Read(model); if not d then return end
		local was = ui.stripe.Visible
		S.Apply(ui, d)
		if d.exceptional and (first or not was) then S.Celebrate(ui, Adapter.ReducedMotion()) end
	end
	for _, a in Adapter.Watched() do table.insert(st.conns, model:GetAttributeChangedSignal(a):Connect(function() upd(false) end)) end
	upd(true)
	-- fit the pixel layout into the stud-sized billboard
	table.insert(st.conns, bb:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() sc.Scale = bb.AbsoluteSize.X / PLACED.w end))
	sc.Scale = math.max(0.01, bb.AbsoluteSize.X / PLACED.w)
	st.appear = true
end
local function removeLabel(model)
	if pending[model] then pending[model]:Disconnect(); pending[model] = nil end
	local st = labels[model]; if not st then return end
	for _, c in st.conns do c:Disconnect() end
	st.bb:Destroy(); labels[model] = nil
end
for _, m in CollectionService:GetTagged(Adapter.PlacedTag) do task.spawn(addLabel, m) end
CollectionService:GetInstanceAddedSignal(Adapter.PlacedTag):Connect(function(m) task.defer(addLabel, m) end) -- also fires when streamed in
CollectionService:GetInstanceRemovedSignal(Adapter.PlacedTag):Connect(removeLabel) -- pickup / streamed out

-- one shared, throttled loop for every label: distance fade + first-appear settle
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt; if acc < 0.1 then return end; acc = 0
	local cam = workspace.CurrentCamera; if not cam then return end
	local cp = cam.CFrame.Position
	for model, st in labels do
		if not model.Parent then removeLabel(model) else
			local d = (st.bb.Adornee and (st.bb.Adornee.Position - cp).Magnitude) or 999
			local target = math.clamp((d - FADE_START) / (FADE_END - FADE_START), 0, 1)
			if st.appear then
				st.appear = false
				if Adapter.ReducedMotion() then st.group.GroupTransparency = target else
					st.scale.Scale *= 0.88
					TweenService:Create(st.group, TweenInfo.new(0.32), { GroupTransparency = target }):Play()
					TweenService:Create(st.scale, TweenInfo.new(0.32, Enum.EasingStyle.Back), { Scale = st.bb.AbsoluteSize.X / PLACED.w }):Play()
				end
			elseif math.abs(st.group.GroupTransparency - target) > 0.02 then
				st.group.GroupTransparency = target
			end
		end
	end
end)
