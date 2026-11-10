--[[ StarterPlayerScripts.LiveEventsBar (LocalScript) - 2026-11-10
A row of event pills (ReplicatedStorage.EventUI: the same slab as the event timers and banners, all one height,
icon + name + countdown, a soft pulse in the last 10 seconds) under the day / night bar showing every event and boost running in this server, with a
countdown: "10x CASH 4:32", "EGG RUSH 2:10", "RAPIDS 0:41" ... They stack side by side when several run at once.
Reads only workspace attributes (no remotes):
  Boost<Target>Multiplier / Boost<Target>EndsAt           BoostService (admin panel Boost event)
  OwnerEvent_<EggRush|DoubleCash|GoldenHour>Ends          OwnerControlServer live events
  HighTideActive / HighTideEndsAt                         Rapids
  ReplicatedStorage.MeteorEvent EndsAt                    Meteor Shower
Night, boss, arena and volcano already have their own HUD (NightBar, EventTimers). ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local EventUI = require(ReplicatedStorage:WaitForChild("EventUI"))
local ICON, THEMES = EventUI.ICON, EventUI.THEMES
local PILL_H = 36
-- { id, theme (EventUI colours), icon, read() -> text?, endsAt? }
local function boost(target, label, theme, icon)
    return {
        id = "Boost" .. target,
        theme = theme,
        icon = icon,
        read = function()
            local x = workspace:GetAttribute("Boost" .. target .. "Multiplier")
            if x then
                return tostring(x) .. "x " .. label, workspace:GetAttribute("Boost" .. target .. "EndsAt")
            end
        end,
    }
end
local function ownerEvent(kind, label, theme, icon)
    return {
        id = kind,
        theme = theme,
        icon = icon,
        read = function()
            local ends = workspace:GetAttribute("OwnerEvent_" .. kind .. "Ends")
            if ends and ends > workspace:GetServerTimeNow() then
                return label, ends
            end
        end,
    }
end
local ENTRIES = {
    boost("Cash", "CASH", THEMES.cash, ICON.cash),
    boost("Luck", "LUCK", THEMES.eggrush, ICON.star),
    boost("Hatch", "HATCH SPEED", THEMES.fail, ICON.clock),
    boost("Mutation", "MUTATION", THEMES.pink, ICON.sparkle),
    boost("RiverSpeed", "RIVER SPEED", THEMES.info, ICON.bolt),
    ownerEvent("DoubleCash", "2x CASH", THEMES.cash, ICON.cash),
    ownerEvent("EggRush", "EGG RUSH", THEMES.eggrush, ICON.egg),
    ownerEvent("GoldenHour", "GOLDEN HOUR", THEMES.eggrush, ICON.eggGold),
    {
        id = "Rapids",
        theme = THEMES.tide,
        icon = ICON.wave,
        read = function()
            if workspace:GetAttribute("HighTideActive") then
                return "RAPIDS", workspace:GetAttribute("HighTideEndsAt")
            end
        end,
    },
    {
        id = "Meteor",
        theme = THEMES.meteor,
        icon = ICON.fire,
        read = function()
            local folder = ReplicatedStorage:FindFirstChild("MeteorEvent")
            local ends = folder and folder:GetAttribute("EndsAt") or 0
            if ends > workspace:GetServerTimeNow() then
                return "METEOR SHOWER", ends
            end
        end,
    },
}

local gui = Instance.new("ScreenGui")
gui.Name = "LiveEventsBar"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 12
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
local row = Instance.new("Frame")
row.Name = "Row"
row.BackgroundTransparency = 1
row.AnchorPoint = Vector2.new(0.5, 0)
row.Size = UDim2.fromOffset(900, 0)
row.AutomaticSize = Enum.AutomaticSize.Y
row.Parent = gui
local fit = Instance.new("UIScale")
fit.Parent = row
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Wraps = true -- many events: a second line instead of running under the side menus
layout.Parent = row

-- sit just under the day / night bar (top centre), between the left and right side menus
local function place()
    local size = gui.AbsoluteSize
    if size.X < 10 then
        return
    end
    fit.Scale = math.clamp(size.X / 1600, 0.55, 1)
    -- room between the side menus: about half the screen
    row.Size = UDim2.fromOffset(math.max(360, size.X * 0.52 / fit.Scale), 0)
    row.Position = UDim2.new(0.5, 0, 0, math.max(GuiService.TopbarInset.Max.Y, 36) + 14 * fit.Scale)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
place()

local pills = {} -- [id] = EventUI.pill
local function makePill(entry, order)
    local pill = EventUI.pill(row, {
        name = entry.id,
        top = entry.theme.top,
        bottom = entry.theme.bottom,
        icon = entry.icon,
        height = PILL_H,
        nameSize = 19,
        timeSize = 19,
        iconSize = 28,
        order = order,
    })
    pill.popIn()
    return pill
end

local function clockText(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds >= 3600 then
        return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
    end
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- tells the shared top-centre column where the pills end, so the boss / arena HUD and banners sit under them
local function reportStack()
    if next(pills) == nil then
        EventUI.stackSet("pills", 0)
    else
        EventUI.stackSet("pills", row.AbsoluteSize.Y, row.AbsolutePosition.Y)
    end
end
row:GetPropertyChangedSignal("AbsoluteSize"):Connect(reportStack)
row:GetPropertyChangedSignal("AbsolutePosition"):Connect(reportStack)

local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
    accumulator += dt
    if accumulator < 0.25 then
        return
    end
    accumulator = 0
    local now = workspace:GetServerTimeNow()
    local seen = {}
    for order, entry in ENTRIES do
        local text, ends = entry.read()
        if text then
            seen[entry.id] = true
            local pill = pills[entry.id]
            if not pill then
                pill = makePill(entry, order)
                pills[entry.id] = pill
            end
            pill.setName(text)
            pill.setTime(ends and clockText(ends - now) or nil)
            pill.setUrgent(ends ~= nil and ends - now <= 10)
        end
    end
    for id, pill in pills do
        if not seen[id] then
            pills[id] = nil
            pill.popOut()
        end
    end
    reportStack()
end)
