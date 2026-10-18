--[[ ServerScriptService.Leaderboard.LeaderboardChampions  (Script)
Stands the GLOBAL #1 and #2 players (Config.Champions.Stat) as avatar dummies on the podiums at each
end of every leaderboard board ("Podium1" / "Podium2" inside the board Model, built by
LeaderboardBoardBuilder / LeaderboardChampionsBuilder).

  • only real global rankings: no global data → no dummy, the plaque reads "Awaiting a champion"
  • a dummy is rebuilt only when the player on that spot changes; names / values update in place
  • dummies are anchored, can't die, show no default Humanoid name; a billboard shows name + value
  • avatars come from Players:CreateHumanoidModelFromUserId (server only, yields, can fail → retried)

Studio only: ChampionsStudioPreview (BindableFunction under this script) lets a play-test show
given players without global data, for checking the look. It does not exist in live servers.
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Leaderboard")
local Config = require(Shared:WaitForChild("LeaderboardConfig"))
local Format = require(Shared:WaitForChild("LeaderboardFormat"))
local Service = require(script.Parent:WaitForChild("LeaderboardService"))

local C = Config.Champions
local STAT = Config.StatById[C.Stat]
local RANK_WORD = { "1ST", "2ND", "3RD" }

local spots = {} -- [Podium Model] = { rank, spot (Attachment), title, sub, entry, dummy, token, userId }
local preview = nil -- Studio-only override list

---------------------------------------------------------------- dummies
local function clearDummy(state)
	state.token += 1
	state.userId = nil
	if state.dummy then state.dummy:Destroy() end
	state.dummy = nil
end

local function playIdle(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local animation = Instance.new("Animation")
	animation.AnimationId = humanoid.RigType == Enum.HumanoidRigType.R15 and C.IdleAnimationR15 or C.IdleAnimationR6
	local ok, track = pcall(animator.LoadAnimation, animator, animation)
	if ok and track then
		track.Looped = true
		track:Play(0)
	end
end

local function billboard(model, entry, rank)
	local head = model:FindFirstChild("Head")
	if not head then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "ChampionTag"
	gui.Size = UDim2.fromOffset(220, 54)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.Parent = head
	local name = Instance.new("TextLabel")
	name.Name = "DisplayName"
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 28)
	name.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	name.TextSize = 24
	name.TextColor3 = Color3.fromRGB(255, 244, 220)
	name.TextStrokeColor3 = Color3.fromRGB(74, 54, 44)
	name.TextStrokeTransparency = 0
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = gui
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Position = UDim2.fromOffset(0, 28)
	value.Size = UDim2.new(1, 0, 0, 22)
	value.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	value.TextSize = 18
	value.TextColor3 = rank == 1 and Color3.fromRGB(255, 214, 96) or Color3.fromRGB(226, 232, 240)
	value.TextStrokeColor3 = Color3.fromRGB(74, 54, 44)
	value.TextStrokeTransparency = 0
	value.Parent = gui
	return gui
end

local function setTag(state, entry)
	local tag = state.dummy and state.dummy:FindFirstChild("ChampionTag", true)
	if not tag then return end
	tag.DisplayName.Text = entry.d or entry.n or "Champion"
	tag.Value.Text = Format.Value(STAT.Kind, entry.v or 0)
end

local function spawnDummy(state, entry)
	clearDummy(state)
	local token = state.token
	state.userId = entry.u
	task.spawn(function()
		local ok, model = pcall(Players.CreateHumanoidModelFromUserId, Players, entry.u)
		if state.token ~= token then if ok and model then model:Destroy() end return end
		if not ok or not model then
			state.userId = nil -- try again on the next refresh
			warn("[LeaderboardChampions] could not load avatar " .. tostring(entry.u) .. ": " .. tostring(model))
			return
		end
		model.Name = "Champion" .. state.rank
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root then model:Destroy() state.userId = nil return end
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.BreakJointsOnDeath = false
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		humanoid.MaxHealth, humanoid.Health = math.huge, math.huge
		root.Anchored = true
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then part.CanTouch = false part.CanQuery = false end
		end
		model:ScaleTo(C.Scale)

		-- stand the feet exactly on the podium top, facing the spot's direction. Measured from the
		-- Humanoid, not the bounding box: before parenting, accessories can sit away from the body.
		local lift
		if humanoid.RigType == Enum.HumanoidRigType.R15 then
			lift = humanoid.HipHeight + root.Size.Y / 2
		else
			local leg = model:FindFirstChild("Left Leg")
			lift = root.Size.Y / 2 + (leg and leg.Size.Y or 2 * C.Scale)
		end
		model:PivotTo(state.spot.WorldCFrame * CFrame.new(0, lift, 0)) -- a character's pivot is its root
		model.Parent = state.podium
		billboard(model, entry, state.rank)
		state.dummy = model
		setTag(state, entry)
		playIdle(model)
	end)
end

---------------------------------------------------------------- plaques
local function setPlaque(state, entry, status)
	state.title.Text = "#" .. state.rank .. "  " .. (RANK_WORD[state.rank] or "")
	if entry then
		state.sub.Text = "GLOBAL " .. STAT.Tab
	elseif status == "loading" then
		state.sub.Text = "Loading..."
	else
		state.sub.Text = "Awaiting a champion"
	end
end

local function refresh()
	local status, top
	if preview then
		status, top = "ok", preview
	else
		status, top = Service.GetGlobalTop(C.Stat, C.Count)
	end
	for _, state in spots do
		local entry = top[state.rank]
		setPlaque(state, entry, status)
		if entry and entry.u and entry.u > 0 then
			if state.userId ~= entry.u then
				spawnDummy(state, entry)
			else
				setTag(state, entry)
			end
		elseif status ~= "stale" then
			-- no player for this spot (empty ranking or no global data); a stale read keeps the last one
			clearDummy(state)
		end
	end
end

---------------------------------------------------------------- podium discovery
local function makePlaque(face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ChampionPlaque"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Parent = face
	local plate = Instance.new("Frame")
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromScale(0.5, 0.5)
	plate.Size = UDim2.new(1, -24, 1, -20)
	plate.BackgroundColor3 = Color3.fromRGB(74, 54, 44)
	plate.Parent = gui
	Instance.new("UICorner", plate).CornerRadius = UDim.new(0, 10)
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.fromRGB(196, 160, 86)
	rim.Thickness = 4
	rim.Parent = plate
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromScale(0, 0.08)
	title.Size = UDim2.fromScale(1, 0.5)
	title.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 214, 96)
	title.Parent = plate
	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromScale(0.06, 0.6)
	sub.Size = UDim2.fromScale(0.88, 0.28)
	sub.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(240, 226, 196)
	sub.Parent = plate
	return title, sub
end

local function addBoard(board)
	for rank = 1, C.Count do
		local podium = board:WaitForChild("Podium" .. rank, 10)
		local face = podium and podium:FindFirstChild("PlaqueFace")
		local spot = podium and podium:FindFirstChild("ChampionSpot", true)
		if podium and face and spot and not spots[podium] then
			local old = face:FindFirstChild("ChampionPlaque")
			if old then old:Destroy() end
			local title, sub = makePlaque(face)
			spots[podium] = { rank = rank, podium = podium, spot = spot, title = title, sub = sub, token = 0 }
			podium.Destroying:Connect(function() spots[podium] = nil end)
		end
	end
	refresh()
end

for _, board in CollectionService:GetTagged(Config.Tag) do task.spawn(addBoard, board) end
CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(addBoard)

Service.GlobalUpdated.Event:Connect(function(statId)
	if statId == C.Stat then refresh() end
end)

if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "ChampionsStudioPreview"
	hook.OnInvoke = function(list) -- { { u = userId, d = displayName, n = username, v = value }, ... } or nil to stop
		preview = list
		refresh()
		return true
	end
	hook.Parent = script
end

while true do
	task.wait(C.Refresh)
	local ok, err = pcall(refresh)
	if not ok then warn("[LeaderboardChampions] " .. tostring(err)) end
end
