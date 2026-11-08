--[[ Event timers (top right, under the bag counter): one row per scheduled event with its icon on a slanted dark bar
and "In: MM:SS" until it starts, "LIVE!" while it runs (the arena says "JOIN!" while its portal is open).
Reads only the workspace attributes the event services publish (BossNextAt / BossActive, ArenaNextAt / ArenaPhase,
VolcanoNextAt / VolcanoStart) and server time, so every player sees the same clock. Before the server has published a
time it falls back to the event's own config schedule. The soonest event is always the top row.
Icons: FOLK Icon Pack (Brain note "FOLK icon pack"), bar art: Steal Anime Egg/assets/ui/events. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer

local BAR_IMAGE = "rbxassetid://118353931408740"
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
local WHITE = Color3.new(1, 1, 1)
local SOON = Color3.fromRGB(255, 214, 64) -- the last minute
local LIVE = Color3.fromRGB(110, 255, 120)

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
        config = config("BossEvent", "BossConfig"),
        live = function()
            return workspace:GetAttribute("BossActive") == true and "LIVE!" or nil
        end,
    },
    {
        key = "Arena",
        icon = "rbxassetid://79302902202299", -- sword
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
        config = config("VolcanoEvent", "VolcanoConfig"),
        live = function(now, cfg)
            local started = workspace:GetAttribute("VolcanoStart")
            local total = cfg and cfg.TotalSeconds or 150
            return typeof(started) == "number" and now - started < total and "LIVE!" or nil
        end,
    },
}

-- ===== UI =====
local gui = Instance.new("ScreenGui")
gui.Name = "EventTimersHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 14
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

local holder = Instance.new("Frame")
holder.Name = "Timers"
holder.AnchorPoint = Vector2.new(1, 0)
holder.Position = UDim2.new(1, -14, 0, 14)
holder.Size = UDim2.fromOffset(236, 3 * 48 + 2 * 6)
holder.BackgroundTransparency = 1
holder.Parent = gui

local fit = Instance.new("UIScale")
fit.Parent = holder

local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 6)
list.HorizontalAlignment = Enum.HorizontalAlignment.Right
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = holder

for _, event in EVENTS do
    local row = Instance.new("Frame")
    row.Name = event.key
    row.Size = UDim2.fromOffset(236, 48)
    row.BackgroundTransparency = 1
    row.Parent = holder

    local bar = Instance.new("ImageLabel")
    bar.Name = "Bar"
    bar.Position = UDim2.fromOffset(24, 2)
    bar.Size = UDim2.fromOffset(212, 44)
    bar.BackgroundTransparency = 1
    bar.Image = BAR_IMAGE
    bar.Parent = row

    local text = Instance.new("TextLabel")
    text.Name = "Time"
    text.Position = UDim2.fromOffset(40, 0)
    text.Size = UDim2.new(1, -54, 1, 0)
    text.BackgroundTransparency = 1
    text.FontFace = FONT
    text.TextSize = 25
    text.TextColor3 = WHITE
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Text = ""
    text.Parent = bar
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(0, 0, 0)
    stroke.Thickness = 2.5
    stroke.LineJoinMode = Enum.LineJoinMode.Miter
    stroke.Parent = text

    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Position = UDim2.fromOffset(0, -3)
    icon.Size = UDim2.fromOffset(54, 54)
    icon.BackgroundTransparency = 1
    icon.Image = event.icon
    icon.ZIndex = 2
    icon.Parent = row
    local pop = Instance.new("UIScale")
    pop.Parent = icon

    event.row, event.text, event.pop = row, text, pop
end

-- Scale with the screen: full size on a PC, smaller on a phone (never under 0.7).
local function refit()
    local camera = workspace.CurrentCamera
    local height = camera and camera.ViewportSize.Y or 800
    fit.Scale = math.clamp(height / 800, 0.7, 1.1)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(refit)
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
end
refit()

gui.Parent = player:WaitForChild("PlayerGui")

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

while true do
    local now = workspace:GetServerTimeNow()
    for _, event in EVENTS do
        local cfg = event.config
        local nextAt = workspace:GetAttribute(event.key .. "NextAt")
        if typeof(nextAt) ~= "number" and cfg and cfg.NextScheduled then
            nextAt = cfg.NextScheduled(now)
        end
        local liveText = event.live(now, cfg)
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
    end
    task.wait(0.25)
end
