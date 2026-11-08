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
Old version: ServerStorage._ARCHIVE.EventTimers_BeforeStud_2026-11-07 ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local HudScale = require(ReplicatedStorage:WaitForChild("HudScale"))
local H = M.H

local player = Players.LocalPlayer

local WHITE = Color3.new(1, 1, 1)
local SOON = Color3.fromRGB(255, 225, 77) -- the last minute
local LIVE = Color3.fromRGB(140, 245, 106)

local function config(folderName, moduleName)
	local folder = ReplicatedStorage:WaitForChild(folderName, 10)
	local module = folder and folder:WaitForChild(moduleName, 10)
	local ok, result = pcall(require, module)
	return ok and result or nil
end

local EVENTS = {
	{
		key = "Boss",
		icon = "rbxassetid://79711631278660", -- angry face with horns
		color = M.COLOR.lilac,
		config = config("BossEvent", "BossConfig"),
		live = function()
			return workspace:GetAttribute("BossActive") == true and "LIVE!" or nil
		end,
	},
	{
		key = "Arena",
		icon = "rbxassetid://79302902202299", -- sword
		color = M.COLOR.azure,
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
		icon = "rbxassetid://106124079616526", -- fire
		color = M.COLOR.coral,
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

for _, event in EVENTS do
	local row = H.new("Frame", { Name = event.key, Size = UDim2.fromOffset(ROW_W, ROW_H), BackgroundTransparency = 1 }, holder)
	-- the slab: read only, so no lip
	local SX, SY, SW, SH = 26, 3, ROW_W - 28, ROW_H - 10
	H.shadow(row, "Bar", SX, SY, SW, SH, 14, 1)
	local bar = H.rect(row, "Bar", SX, SY, SW, SH, 14, 2, WHITE)
	H.grad(bar, event.color[1], event.color[2])
	H.ink(bar, 4)
	H.studs(bar, Vector2.new(48, 48), 0.78, 14, 2)
	H.shine(bar, 14, 3)

	local text = H.new("TextLabel", { Name = "Time", BackgroundTransparency = 1, FontFace = M.FONT, TextSize = 26, TextColor3 = WHITE, Text = "",
		TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -44, 1, -4), ZIndex = 5 }, bar)
	H.new("UIStroke", { Name = "UIStroke", Thickness = 3.5, Color = Color3.new(0, 0, 0), LineJoinMode = Enum.LineJoinMode.Bevel }, text)

	if event.key == "Arena" then
		local join = H.new("TextButton", {
			Name = "JoinArena", Text = "", BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), ZIndex = 7, Visible = false,
		}, bar)
		join.Activated:Connect(function()
			local arena = game:GetService("ReplicatedStorage"):FindFirstChild("ArenaEvent")
			local remote = arena and arena:FindFirstChild("Join")
			if remote and typeof(player:GetAttribute("ArenaPortalCFrame")) == "CFrame" then
				remote:FireServer("GoToPortal")
			end
		end)
		event.join = join
	end

	local icon = H.new("ImageLabel", { Name = "Icon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(28, ROW_H / 2 - 3), Size = UDim2.fromOffset(58, 58),
		BackgroundTransparency = 1, Image = event.icon, ZIndex = 6 }, row)
	icon:SetAttribute("Wiggle", 0)
	local pop = Instance.new("UIScale")
	pop.Parent = icon

	local rowPop = Instance.new("UIScale") -- the pop when this event becomes the shown one
	rowPop.Parent = row
	row.Visible = false
	event.row, event.text, event.pop, event.rowPop = row, text, pop, rowPop
end
M.animate(holder, { sounds = false })

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
		if not GuiService.ReducedMotionEnabled then
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
	if GuiService.ReducedMotionEnabled then
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
		local text, color
		if liveText then
			text, color = liveText, LIVE
		elseif typeof(nextAt) == "number" then
			local left = nextAt - now
			text, color = "In: " .. format(left), left <= 60 and SOON or WHITE
		else
			text, color = "In: --:--", WHITE
		end
		if event.text.Text ~= text then
			event.text.Text = text
		end
		event.text.TextColor3 = color
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
