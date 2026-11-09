--[[ Event timers (bottom right since 2026-11-08): ONE row at a time - whichever event is live, else the one that starts
soonest; when it ends the next one takes its place (pops in). Sized by ReplicatedStorage.HudScale like the rest of the HUD.
Old version: ServerStorage._ARCHIVE.Scripts_BeforeTimerQueue_2026-11-08.EventTimers
One row per scheduled event, in the Folk Stud look (2026-11-07):
a candy slab per event (black outline, faint studs, light sweep, hard shadow) with the event's icon breaking out over
its left end, and "In: MM:SS" until it starts, "LIVE!" while it runs (the arena says "JOIN!" while its portal is open).
Reads only the workspace attributes the event services publish (BossNextAt / BossActive, ArenaNextAt / ArenaPhase,
VolcanoNextAt / VolcanoStart) and server time, so every player sees the same clock. Before the server has published a
time it falls back to the event's own config schedule. The soonest event is always the top row.
Icons: FOLK Icon Pack (Brain note "FOLK icon pack"). Looks: ReplicatedStorage.FolkStudUI.
Old version: ServerStorage._ARCHIVE.EventTimers_BeforeStud_2026-11-07
2026-11-10: the row is an EventUI.pill (ReplicatedStorage.EventUI), the same slab as the live event pills and banners:
icon + event name + a right-aligned countdown ("04:32", "LIVE!", "JOIN!"), soft pulse in the last 10 seconds. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local EventUI = require(ReplicatedStorage:WaitForChild("EventUI"))
local HudScale = require(ReplicatedStorage:WaitForChild("HudScale"))
local H = M.H

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local SOON = EventUI.HOT -- the last minute
local LIVE = EventUI.LIVE

local function config(folderName, moduleName)
	local folder = ReplicatedStorage:WaitForChild(folderName, 10)
	local module = folder and folder:WaitForChild(moduleName, 10)
	local ok, result = pcall(require, module)
	return ok and result or nil
end

local EVENTS = {
	{
		key = "Boss",
		name = "BOSS",
		icon = "rbxassetid://79711631278660", -- angry face with horns
		theme = EventUI.THEMES.boss,
		config = config("BossEvent", "BossConfig"),
		live = function()
			return workspace:GetAttribute("BossActive") == true and "LIVE!" or nil
		end,
	},
	{
		key = "Arena",
		name = "ARENA",
		icon = "rbxassetid://79302902202299", -- sword
		theme = EventUI.THEMES.arena,
		config = config("ArenaEvent", "ArenaConfig"),
		live = function()
			local phase = workspace:GetAttribute("ArenaPhase")
			if phase == "Lobby" then
				return "JOIN!"
			elseif phase == "Countdown" or phase == "Fight" then
				return "LIVE!"
			end
			return nil
		end,
	},
	{
		key = "Volcano",
		name = "VOLCANO",
		icon = "rbxassetid://106124079616526", -- fire
		theme = EventUI.THEMES.volcano,
		config = config("VolcanoEvent", "VolcanoConfig"),
		live = function(now, cfg)
			local started = workspace:GetAttribute("VolcanoStart")
			local total = cfg and cfg.TotalSeconds or 150
			return typeof(started) == "number" and now - started < total and "LIVE!" or nil
		end,
	},
}

-- ===== UI =====
local ROW_W, ROW_H, GAP = 236, 50, 8
local gui = Instance.new("ScreenGui")
gui.Name = "EventTimersHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 14
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

local holder = Instance.new("Frame")
holder.Name = "Timers"
holder.AnchorPoint = Vector2.new(1, 1)
holder.Position = UDim2.new(1, -14, 1, -14) -- bottom right, beside the hotbar
holder.Size = UDim2.fromOffset(ROW_W, ROW_H)
holder.BackgroundTransparency = 1
holder.Parent = gui

local fit = Instance.new("UIScale")
fit.Parent = holder

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, GAP)
list.HorizontalAlignment = Enum.HorizontalAlignment.Right
list.VerticalAlignment = Enum.VerticalAlignment.Bottom
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = holder

local PILL_H = 40
for _, event in EVENTS do
	local row = H.new("Frame", { Name = event.key, Size = UDim2.fromOffset(ROW_W, ROW_H), BackgroundTransparency = 1 }, holder)
	-- the slab: read only, so no lip. The icon hangs over its left end.
	local pill = EventUI.pill(row, {
		name = "Bar",
		top = event.theme.top,
		bottom = event.theme.bottom,
		icon = event.icon,
		width = ROW_W,
		height = PILL_H,
		nameSize = 22,
		timeSize = 24,
		iconSize = 56,
		breakout = true,
		shadow = true,
	})
	pill.frame.Position = UDim2.fromOffset(0, (ROW_H - PILL_H) / 2 - 2)
	pill.setName(event.name)

	if event.key == "Arena" then
		local join = H.new("TextButton", {
			Name = "JoinArena", Text = "", BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), ZIndex = 9, Visible = false,
		}, pill.slab)
		join.Activated:Connect(function()
			local arena = game:GetService("ReplicatedStorage"):FindFirstChild("ArenaEvent")
			local remote = arena and arena:FindFirstChild("Join")
			if remote and typeof(player:GetAttribute("ArenaPortalCFrame")) == "CFrame" then
				remote:FireServer("GoToPortal")
			end
		end)
		event.join = join
	end

	local rowPop = Instance.new("UIScale") -- the pop when this event becomes the shown one
	rowPop.Parent = row
	row.Visible = false
	event.row, event.pill, event.pop, event.rowPop = row, pill, pill.iconPop, rowPop
end

-- Same size rule as the rest of the HUD (ReplicatedStorage.HudScale).
local function refit()
	fit.Scale = HudScale.For(gui.AbsoluteSize)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

gui.Parent = player:WaitForChild("PlayerGui")
refit()

-- ===== Clock =====
local function format(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
	end
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

local pulse = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local function setPulsing(event, on)
	if (event.pulse ~= nil) == on then
		return
	end
	if on then
		event.pulse = TweenService:Create(event.pop, pulse, { Scale = 1.12 })
		if not EventUI.reduced() then
			event.pulse:Play()
		end
	else
		event.pulse:Cancel()
		event.pulse = nil
		event.pop.Scale = 1
	end
end

local shown -- the event whose row is on screen
local popIn = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function show(event)
	if shown == event then
		return
	end
	if shown then
		shown.row.Visible = false
	end
	shown = event
	event.row.Visible = true
	if EventUI.reduced() then
		event.rowPop.Scale = 1
	else
		event.rowPop.Scale = 0.6
		TweenService:Create(event.rowPop, popIn, { Scale = 1 }):Play()
	end
end

while true do
	local now = workspace:GetServerTimeNow()
	local best, bestOrder = nil, math.huge
	for _, event in EVENTS do
		local cfg = event.config
		local nextAt = workspace:GetAttribute(event.key .. "NextAt")
		if typeof(nextAt) ~= "number" and cfg and cfg.NextScheduled then
			nextAt = cfg.NextScheduled(now)
		end
		local liveText = event.live(now, cfg)
		if event.join then
			event.join.Visible = liveText == "JOIN!" and typeof(player:GetAttribute("ArenaPortalCFrame")) == "CFrame"
		end
		local text, color, lastSeconds
		if liveText then
			text, color, lastSeconds = liveText, LIVE, false
		elseif typeof(nextAt) == "number" then
			local left = nextAt - now
			text, color, lastSeconds = format(left), left <= 60 and SOON or WHITE, left <= 10
		else
			text, color, lastSeconds = "--:--", WHITE, false
		end
		event.pill.setTime(text, color)
		event.pill.setUrgent(lastSeconds)
		setPulsing(event, liveText ~= nil)
		-- live events first, then the soonest
		local order = liveText and 0 or (typeof(nextAt) == "number" and math.clamp(math.floor(nextAt - now), 1, 1e6) or 1e6)
		event.row.LayoutOrder = order
		if order < bestOrder then
			best, bestOrder = event, order
		end
	end
	if best then
		show(best)
	end
	task.wait(0.25)
end
