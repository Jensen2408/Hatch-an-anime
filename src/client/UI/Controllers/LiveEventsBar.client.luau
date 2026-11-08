--[[ StarterPlayerScripts.LiveEventsBar (LocalScript) - 2026-11-08
A row of Folk Stud pills under the day / night bar showing every event and boost running in this server, with a
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
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local INK = Color3.fromRGB(10, 10, 14)
local function hex(s)
    return Color3.fromHex(s)
end
-- { id, label(x) -> text, top colour, bottom colour, read() -> multiplier?, endsAt? }
local function boost(target, label, top, bottom)
    return {
        id = "Boost" .. target,
        top = top,
        bottom = bottom,
        read = function()
            local x = workspace:GetAttribute("Boost" .. target .. "Multiplier")
            if x then
                return tostring(x) .. "x " .. label, workspace:GetAttribute("Boost" .. target .. "EndsAt")
            end
        end,
    }
end
local function ownerEvent(kind, label, top, bottom)
    return {
        id = kind,
        top = top,
        bottom = bottom,
        read = function()
            local ends = workspace:GetAttribute("OwnerEvent_" .. kind .. "Ends")
            if ends and ends > workspace:GetServerTimeNow() then
                return label, ends
            end
        end,
    }
end
local ENTRIES = {
    boost("Cash", "CASH", hex("5BF37A"), hex("12A43A")),
    boost("Luck", "LUCK", hex("FFE14A"), hex("F59A00")),
    boost("Hatch", "HATCH SPEED", hex("C08CFF"), hex("7A2CE6")),
    boost("Mutation", "MUTATION", hex("FF8AD0"), hex("E0249A")),
    boost("RiverSpeed", "RIVER SPEED", hex("5EE8FF"), hex("1690E0")),
    ownerEvent("DoubleCash", "2x CASH", hex("5BF37A"), hex("12A43A")),
    ownerEvent("EggRush", "EGG RUSH", hex("FFB04A"), hex("F06A00")),
    ownerEvent("GoldenHour", "GOLDEN HOUR", hex("FFE14A"), hex("F59A00")),
    {
        id = "Rapids",
        top = hex("5EE8FF"),
        bottom = hex("1690E0"),
        read = function()
            if workspace:GetAttribute("HighTideActive") then
                return "RAPIDS", workspace:GetAttribute("HighTideEndsAt")
            end
        end,
    },
    {
        id = "Meteor",
        top = hex("FF8AD0"),
        bottom = hex("B01CFF"),
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

local pills = {} -- [id] = { frame, label, time, shine, scale }
local function makePill(entry, order)
    local frame = Instance.new("Frame")
    frame.Name = entry.id
    frame.LayoutOrder = order
    frame.Size = UDim2.fromOffset(0, 34)
    frame.AutomaticSize = Enum.AutomaticSize.X
    frame.BackgroundColor3 = Color3.new(1, 1, 1)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new(entry.top, entry.bottom)
    gradient.Parent = frame
    local outline = Instance.new("UIStroke")
    outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    outline.Thickness = 3
    outline.Color = INK
    outline.Parent = frame
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = frame
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Padding = UDim.new(0, 10)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = frame
    local function text(name, size, color, layoutOrder)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromOffset(0, 34)
        label.AutomaticSize = Enum.AutomaticSize.X
        label.FontFace = FONT
        label.TextSize = size
        label.TextColor3 = color
        label.LayoutOrder = layoutOrder
        local stroke = Instance.new("UIStroke")
        stroke.Name = "UIStroke"
        stroke.Thickness = 3.7
        stroke.LineJoinMode = Enum.LineJoinMode.Bevel
        stroke.Color = INK
        stroke.Parent = label
        label.Parent = frame
        return label
    end
    local label = text("Label", 19, Color3.new(1, 1, 1), 1)
    local time = text("Time", 17, Color3.fromRGB(255, 246, 190), 2)
    -- a glint that runs along the outline now and then
    local glint = Instance.new("UIGradient")
    glint.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, INK),
        ColorSequenceKeypoint.new(0.45, INK),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 160)),
        ColorSequenceKeypoint.new(0.55, INK),
        ColorSequenceKeypoint.new(1, INK),
    })
    glint.Parent = outline
    local scale = Instance.new("UIScale")
    scale.Scale = 0.2
    scale.Parent = frame
    frame.Parent = row
    TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
    return { frame = frame, label = label, time = time, glint = glint, scale = scale, seed = math.random() * 3 }
end

local function clockText(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds >= 3600 then
        return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
    end
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local accumulator = 0
RunService.RenderStepped:Connect(function(dt)
    local now = workspace:GetServerTimeNow()
    local t = os.clock()
    local calm = GuiService.ReducedMotionEnabled
    -- motion every frame: gentle breathing + the outline glint
    for _, pill in pills do
        if not calm then
            pill.scale.Scale = 1 + math.max(0, math.sin((t + pill.seed) * 3)) * 0.03
            local phase = ((t + pill.seed) % 3) / 0.9
            pill.glint.Offset = Vector2.new(phase <= 1 and (phase * 2 - 1) or 1, 0)
        end
    end
    accumulator += dt
    if accumulator < 0.25 then
        return
    end
    accumulator = 0
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
            pill.label.Text = text
            pill.time.Text = ends and clockText(ends - now) or ""
            pill.time.Visible = ends ~= nil
        end
    end
    for id, pill in pills do
        if not seen[id] then
            pills[id] = nil
            local frame = pill.frame
            TweenService:Create(pill.scale, TweenInfo.new(0.2), { Scale = 0 }):Play()
            task.delay(0.22, function()
                frame:Destroy()
            end)
        end
    end
end)
