--[[ ReplicatedStorage.Leaderboard.LeaderboardView  (ModuleScript)
Builds one leaderboard UI inside a container: the board's SurfaceGui ("Board") or the expanded
ScreenGui panel ("Screen" / "Compact"). Every view renders the same state from LeaderboardClient,
so the board and the expanded screen always show the same tab, scope and data.

Look (the shrine redesign): a dark-wood page, an embossed gold title between cloud scrolls, charcoal
tabs with icons that turn crimson + gold when selected, a dark well holding cream rows, gold / silver /
bronze medals for the top three, and a crimson-and-gold YOUR RANK card pinned below.

Motion: tabs press down onto their lip, rows lift slightly on hover, and values count up from 0
to the server's number when you switch tab or scope (then hold exactly). Rows are pooled and only
their text changes on data updates; the scroll position is kept per tab + scope.

Pure UI: owns no data and talks to no remote; input goes out through the callbacks table
({ onTab(statId), onScope(scope), onClose() }) passed to View.new.
]]
-- ===== 1. Setup and constants =====
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(script.Parent.LeaderboardConfig)
local Format = require(script.Parent.LeaderboardFormat)

local Theme = Config.Theme
-- Four font roles; they currently all use Fredoka One but stay separate so each can be restyled.
local HEAD_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BOLD_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local HEAVY_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local QUICK_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS_TWEEN = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE_TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PULSE_TWEEN = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local COUNT_TIME = 0.6 -- seconds for the count-up animation

-- Pixel metrics per view mode. Board = in-world SurfaceGui, Screen = expanded panel,
-- Compact = expanded panel on small viewports (no column labels, meta line or cloud scrolls when 0).

local METRICS = {
    Board = {
        Pad = 22,
        Header = 62,
        Title = 44,
        Tabs = 54,
        TabText = 19,
        Icon = 24,
        Scope = 14,
        ScopeW = 300,
        ScopeH = 38,
        Column = 22,
        ColText = 12,
        Row = 60,
        Badge = 40,
        Avatar = 42,
        Name = 20,
        User = 13,
        Value = 22,
        ValueW = 200,
        You = 74,
        YouRank = 52,
        Meta = 22,
        MetaText = 13,
        Gap = 8,
        Bar = 6,
        Lip = 4,
        Cloud = 70,
        Edge = 13, -- the board's gold lining covers the outer 0.25 stud of the screen
    },
    Screen = {
        Pad = 18,
        Header = 56,
        Title = 38,
        Tabs = 50,
        TabText = 17,
        Icon = 22,
        Scope = 13,
        ScopeW = 260,
        ScopeH = 34,
        Column = 20,
        ColText = 11,
        Row = 56,
        Badge = 36,
        Avatar = 38,
        Name = 18,
        User = 12,
        Value = 20,
        ValueW = 160,
        You = 68,
        YouRank = 48,
        Meta = 20,
        MetaText = 12,
        Gap = 7,
        Bar = 5,
        Lip = 4,
        Cloud = 58,
    },
    Compact = {
        Pad = 10,
        Header = 34,
        Title = 24,
        Tabs = 38,
        TabText = 13,
        Icon = 16,
        Scope = 11,
        ScopeW = 200,
        ScopeH = 28,
        Column = 0,
        ColText = 10,
        Row = 46,
        Badge = 30,
        Avatar = 30,
        Name = 15,
        User = 10,
        Value = 15,
        ValueW = 100,
        You = 54,
        YouRank = 40,
        Meta = 0,
        MetaText = 10,
        Gap = 5,
        Bar = 4,
        Lip = 3,
        Cloud = 0,
    },
}

local View = {}
View.__index = View

-- ===== 2. Private builders =====
local function create(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end

local function addCorner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function addStroke(parent, color, thickness, transparency, contextual)
    return create("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = contextual and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function addGradient(parent, top, bottom, rotation)
    return create("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(top, bottom) }, parent)
end

local function createLabel(parent, props)
    local merged = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = Theme.Ink,
        FontFace = BODY_FONT,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }
    for key, value in props do
        merged[key] = value
    end
    return create("TextLabel", merged, parent)
end

-- Embossed gold lettering: white text tinted by a gold gradient, with a dark-brown outline.
local function createGoldText(parent, props, outline)
    local textLabel = createLabel(parent, props)
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 200)),
            ColorSequenceKeypoint.new(0.35, Theme.GoldLight),
            ColorSequenceKeypoint.new(0.62, Theme.Gold),
            ColorSequenceKeypoint.new(1, Theme.GoldDeep),
        }),
    }, textLabel)
    addStroke(textLabel, Theme.GoldInk, outline or 2, 0, true)
    return textLabel
end

-- A pressable button: a darker lip with the face on top; pressing pushes the face onto the lip.
local function createLipButton(parent, props, lip, selectable)
    local holder = create("Frame", {
        Name = props.Name or "Button",
        AnchorPoint = props.AnchorPoint or Vector2.zero,
        Position = props.Position,
        Size = props.Size,
        BackgroundColor3 = props.Lip or Theme.CharcoalLip,
        BorderSizePixel = 0,
        LayoutOrder = props.LayoutOrder or 0,
    }, parent)
    addCorner(holder, props.Radius or 10)
    local scale = create("UIScale", {}, holder)
    local face = create("TextButton", {
        Name = "Face",
        Size = UDim2.new(1, 0, 1, -lip),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Selectable = selectable,
        ClipsDescendants = true,
    }, holder)
    addCorner(face, props.Radius or 10)
    local fill = addGradient(face, props.Top or Theme.Charcoal, props.Bottom or Theme.CharcoalLow)
    local edge = addStroke(face, props.Edge or Theme.CharcoalLip, props.EdgeWidth or 1.5)
    local pressed = false
    local function playPress()
        TweenService:Create(face, PRESS_TWEEN, { Position = UDim2.fromOffset(0, lip - 1) }):Play()
        TweenService:Create(scale, PRESS_TWEEN, { Scale = 0.98 }):Play()
    end
    local function playRelease()
        TweenService:Create(face, RELEASE_TWEEN, { Position = UDim2.fromOffset(0, 0) }):Play()
        TweenService:Create(scale, RELEASE_TWEEN, { Scale = 1 }):Play()
    end
    face.InputBegan:Connect(function(input)
        local inputType = input.UserInputType
        if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
            pressed = true
            playPress()
        end
    end)
    face.InputEnded:Connect(function(input)
        local inputType = input.UserInputType
        if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
            pressed = false
            playRelease()
        end
    end)
    face.Activated:Connect(function()
        if not pressed then
            playPress()
            task.delay(0.07, playRelease)
        end -- gamepad / keyboard: the same press, played through
    end)
    return holder, face, fill, edge
end

-- Small gold cloud scroll (three rounded bars) that frames the title.
local function createCloudScroll(parent, width, mirror)
    local holder = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(width, width * 0.36) }, parent)
    local barHeight = math.max(3, math.floor(width * 0.07))
    local barSpecs = { { 0.0, 0.62, 0.55 }, { 0.22, 1.0, 0.70 }, { 0.5, 0.22, 0.45 } } -- x, y (0..1), width share
    for _, spec in barSpecs do
        local x = mirror and (1 - spec[1] - spec[3]) or spec[1]
        local bar = create("Frame", {
            BackgroundColor3 = Theme.Accent,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(x, 0, spec[2] * 0.8 + 0.1, 0),
            Size = UDim2.new(spec[3], 0, 0, barHeight),
        }, holder)
        addCorner(bar, barHeight)
        addStroke(bar, Theme.GoldInk, 1, 0.2)
    end
    return holder
end

-- Tab icons drawn from frames: a coin stack, rising bars, an egg.
local function createStatIcon(parent, kind, size)
    local holder = create(
        "Frame",
        { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), LayoutOrder = 1 },
        parent
    )
    if kind == "money" then
        for i = 0, 2 do
            local coin = create("Frame", {
                BackgroundColor3 = i == 2 and Theme.GoldLight or Theme.Gold,
                BorderSizePixel = 0,
                Position = UDim2.new(0.08, 0, 0.62 - i * 0.24, 0),
                Size = UDim2.new(0.84, 0, 0.3, 0),
            }, holder)
            addCorner(coin, size)
            addStroke(coin, Theme.GoldInk, 1)
        end
    elseif kind == "rate" then
        for i, heightScale in { 0.4, 0.66, 0.92 } do
            local bar = create("Frame", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.new((i - 1) * 0.34 + 0.02, 0, 1, 0),
                Size = UDim2.new(0.26, 0, heightScale, 0),
                Name = "Tint",
            }, holder)
            addCorner(bar, 2)
        end
    else
        local egg = create("Frame", {
            BackgroundColor3 = Theme.Paper,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.52),
            Size = UDim2.new(0.74, 0, 0.96, 0),
        }, holder)
        create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, egg)
        addStroke(egg, Theme.InkSoft, 1)
        local band = create("Frame", {
            BackgroundColor3 = Theme.Medal[3][2],
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.12, 0.5),
            Size = UDim2.new(0.76, 0, 0.1, 0),
        }, egg)
        addCorner(band, 2)
    end
    return holder
end

local function setIconTint(iconFrame, color)
    for _, child in iconFrame:GetChildren() do
        if child.Name == "Tint" then
            child.BackgroundColor3 = color
        end
    end
end

local function medalStyle(rank)
    return rank and Theme.Medal[rank]
end

-- One ranking row (pinned = the YOUR RANK card). Returns the table of parts fillRow updates.
local function buildRow(parent, metrics, name, pinned)
    local row = { pinned = pinned }
    local rowHeight = pinned and metrics.You or (metrics.Row - metrics.Gap)
    local holder = create("Frame", {
        Name = name,
        Size = UDim2.new(1, 0, 0, rowHeight),
        BackgroundColor3 = pinned and Theme.CrimsonLip or Theme.CreamLip,
        BorderSizePixel = 0,
    }, parent)
    addCorner(holder, 12)
    row.frame = holder
    local face = create("Frame", {
        Name = "Face",
        Size = UDim2.new(1, 0, 1, -3),
        BackgroundColor3 = pinned and Color3.new(1, 1, 1) or Theme.Cream,
        BorderSizePixel = 0,
    }, holder)
    addCorner(face, 12)
    row.face = face
    row.fill = pinned and addGradient(face, Theme.Crimson, Theme.CrimsonLow)
        or addGradient(face, Color3.new(1, 1, 1), Color3.fromRGB(234, 222, 200))
    row.edge = addStroke(face, pinned and Theme.Gold or Theme.CreamEdge, pinned and 2 or 1.5)

    local offsetX = 8
    local badgeSize = pinned and metrics.YouRank or metrics.Badge
    row.badge = create("Frame", {
        Name = "Rank",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, offsetX, 0.5, 0),
        Size = UDim2.fromOffset(badgeSize + (pinned and 8 or 0), badgeSize),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, face)
    addCorner(row.badge, 10)
    row.badgeFill = addGradient(row.badge, Theme.Charcoal, Theme.CharcoalLow, 135)
    row.badgeStroke = addStroke(row.badge, pinned and Theme.Gold or Theme.CharcoalLip, pinned and 2 or 1.5)
    row.rank = createLabel(row.badge, {
        Size = UDim2.fromScale(1, 1),
        FontFace = HEAD_FONT,
        TextSize = math.floor(badgeSize * 0.5),
        TextColor3 = pinned and Theme.TabTextOn or Theme.Paper,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
    })

    offsetX += badgeSize + (pinned and 8 or 0) + 10
    row.avatar = create("ImageLabel", {
        Name = "Avatar",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, offsetX, 0.5, 0),
        Size = UDim2.fromOffset(metrics.Avatar, metrics.Avatar),
        BackgroundColor3 = Theme.Avatar,
        BorderSizePixel = 0,
        ScaleType = Enum.ScaleType.Crop,
        Image = "",
    }, face)
    addCorner(row.avatar, 10)
    row.avatarStroke = addStroke(row.avatar, pinned and Theme.Gold or Theme.CreamEdge, 1.5)

    offsetX += metrics.Avatar + 12
    local names = create("Frame", {
        Name = "Names",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(offsetX, 0),
        Size = UDim2.new(1, -(offsetX + metrics.ValueW + 22), 1, 0),
        ClipsDescendants = true,
    }, face)
    local nameRow = create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 0.5, pinned and 8 or 4),
        Size = UDim2.new(1, 0, 0, metrics.Name + 6),
    }, names)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, nameRow)
    row.name = createLabel(nameRow, {
        Name = "DisplayName",
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        FontFace = HEAD_FONT,
        TextSize = metrics.Name,
        TextColor3 = pinned and Theme.YouText or Theme.Ink,
        LayoutOrder = 1,
    })
    create("UISizeConstraint", { MaxSize = Vector2.new(math.max(80, 340 - metrics.ValueW), 1000) }, row.name)
    if not pinned then
        row.you = createLabel(nameRow, {
            Name = "You",
            Text = "YOU",
            FontFace = HEAVY_FONT,
            TextSize = math.max(9, metrics.User - 2),
            TextColor3 = Theme.TabTextOn,
            BackgroundTransparency = 0,
            BackgroundColor3 = Theme.CrimsonLow,
            Size = UDim2.fromOffset(0, metrics.User + 4),
            AutomaticSize = Enum.AutomaticSize.X,
            TextXAlignment = Enum.TextXAlignment.Center,
            Visible = false,
            LayoutOrder = 2,
        })
        addCorner(row.you, 4)
        create("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, row.you)
    end
    row.user = createLabel(names, {
        Name = "Username",
        Position = UDim2.new(0, 0, 0.5, pinned and 8 or 4),
        Size = UDim2.new(1, 0, 0, metrics.User + 4),
        FontFace = BOLD_FONT,
        TextSize = metrics.User,
        TextColor3 = pinned and Theme.YouSub or Theme.InkFaint,
    })
    if pinned then
        row.value = createGoldText(face, {
            Name = "Value",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -16, 0.5, 0),
            Size = UDim2.new(0, metrics.ValueW, 1, 0),
            FontFace = HEAD_FONT,
            TextSize = metrics.Value + 6,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.None,
        }, 2)
    else
        row.value = createLabel(face, {
            Name = "Value",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -16, 0.5, 0),
            Size = UDim2.new(0, metrics.ValueW, 1, 0),
            FontFace = HEAD_FONT,
            TextSize = metrics.Value,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.None,
        })
        -- hover: lift the face off its lip a little
        face.MouseEnter:Connect(function()
            TweenService:Create(face, QUICK_TWEEN, { Position = UDim2.fromOffset(0, -2) }):Play()
        end)
        face.MouseLeave:Connect(function()
            TweenService:Create(face, QUICK_TWEEN, { Position = UDim2.fromOffset(0, 0) }):Play()
        end)
    end
    return row
end

-- entry = { r = rank?, u = userId, n = username?, d = displayName?, v = value? }
-- `shownValue` (0 when a count-up starts) is displayed instead of entry.v; row.target keeps the real value.
local function fillRow(row, entry, kind, isSelf, isAlternate, shownValue)
    local medal = medalStyle(entry.r)
    if not row.pinned then
        local faceColor, edgeColor, lipColor =
            isAlternate and Theme.CreamAlt or Theme.Cream, Theme.CreamEdge, Theme.CreamLip
        if medal then
            faceColor, edgeColor, lipColor = medal[4], medal[2], medal[2]:Lerp(Theme.Ink, 0.35)
        end
        row.face.BackgroundColor3 = faceColor
        row.frame.BackgroundColor3 = lipColor
        row.edge.Color = isSelf and Theme.CrimsonLow or edgeColor
        row.edge.Thickness = isSelf and 2.5 or 1.5
        if row.you then
            row.you.Visible = isSelf
        end
        row.value.TextColor3 = medal and medal[3] or Theme.Ink
    end
    if medal then
        row.badgeFill.Color = ColorSequence.new(medal[1], medal[2])
        row.badgeStroke.Color = medal[2]:Lerp(Theme.Ink, 0.4)
        row.rank.TextColor3 = medal[3]
    elseif row.pinned then
        row.badgeFill.Color = ColorSequence.new(Theme.CrimsonLip, Theme.CrimsonLip)
        row.badgeStroke.Color = Theme.Gold
        row.rank.TextColor3 = Theme.TabTextOn
    else
        row.badgeFill.Color = ColorSequence.new(Theme.Charcoal, Theme.CharcoalLow)
        row.badgeStroke.Color = Theme.CharcoalLip
        row.rank.TextColor3 = Theme.Paper
    end
    row.rank.Text = entry.r and ((row.pinned and "#" or "") .. tostring(entry.r)) or "—"
    local image = (entry.u and entry.u > 0) and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60", entry.u)
        or ""
    if row.avatar.Image ~= image then
        row.avatar.Image = image
    end
    row.name.Text = entry.d or entry.n or "Unknown player"
    row.user.Text = entry.n and ("@" .. entry.n) or (entry.u and ("ID " .. entry.u) or "")
    row.target = entry.v
    local displayValue = shownValue or entry.v
    row.value.Text = displayValue and Format.Value(kind, displayValue) or "—"
end

-- The hint under YOUR RANK: the gap to the player above, a lead message, or why there is no rank.
local function yourRankNote(ownEntry, entries, snapshot, status, scope, kind)
    if ownEntry.r and ownEntry.r > 1 and entries[ownEntry.r - 1] and entries[ownEntry.r - 1].v and ownEntry.v then
        local ahead = entries[ownEntry.r - 1]
        return Format.Value(kind, math.max(0, ahead.v - ownEntry.v))
            .. " to pass "
            .. (ahead.d or ahead.n or "the next player")
    elseif ownEntry.r == 1 then
        return "You lead " .. (scope == "Server" and "this server" or "everyone")
    elseif not snapshot or status == "loading" then
        return "Loading"
    elseif status == "unavailable" then
        return "Global unavailable"
    elseif scope == "Global" and ownEntry.v and ownEntry.v > 0 then
        return (snapshot.total or 0) >= (snapshot.depth or 100)
                and ("Outside the top " .. (snapshot.depth or 100) .. "  ·  keep climbing")
            or "Not on the global board yet"
    else
        return "Not ranked yet"
    end
end

-- ===== 3. Construction =====
function View.new(parent, mode, callbacks)
    local self = setmetatable({}, View)
    self.mode = mode
    self.M = METRICS[mode]
    self.interactive = mode ~= "Board" -- gamepad selection lives in the ScreenGui
    self.callbacks = callbacks
    self.scroll = {}
    self.rows = {}
    self.tweens = {}
    self:_build(parent)
    return self
end

-- Header: the embossed title between gold cloud scrolls (plus a close button outside Board mode).
local function buildHeader(self, root)
    local metrics = self.M
    local header = create(
        "Frame",
        { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, metrics.Header) },
        root
    )
    local titleRow = create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
    }, header)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, math.floor(metrics.Title * 0.4)),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, titleRow)
    if metrics.Cloud > 0 then
        createCloudScroll(titleRow, metrics.Cloud, false).LayoutOrder = 1
    end
    -- embossed gold title
    local title = createGoldText(titleRow, {
        Name = "Title",
        Text = "LEADERBOARD",
        FontFace = HEAD_FONT,
        TextSize = metrics.Title,
        LayoutOrder = 2,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        TextTruncate = Enum.TextTruncate.None,
    }, metrics.Title >= 36 and 3 or 2)
    if metrics.Cloud > 0 then
        createCloudScroll(titleRow, metrics.Cloud, true).LayoutOrder = 3
    end
    self.title = title

    if self.mode ~= "Board" then
        local closeSize = metrics.ScopeH
        local _, closeFace = createLipButton(header, {
            Name = "Close",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(closeSize, closeSize + metrics.Lip),
            Top = Theme.Crimson,
            Bottom = Theme.CrimsonLow,
            Lip = Theme.CrimsonLip,
            Edge = Theme.CrimsonLip,
        }, metrics.Lip, true)
        for _, rotation in { 45, -45 } do
            create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(0.46, 0, 0, 3),
                Rotation = rotation,
                BackgroundColor3 = Theme.TabTextOn,
                BorderSizePixel = 0,
                ZIndex = 2,
            }, closeFace)
        end
        closeFace.Activated:Connect(function()
            self.callbacks.onClose()
        end)
        self.closeButton = closeFace
    end
end

-- Stat tabs: one lip button per Config.Stats entry, sharing the row width.
local function buildTabs(self, root, y)
    local metrics = self.M
    local tabs = create("Frame", {
        Name = "Tabs",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, metrics.Tabs),
    }, root)
    self.tabs = {}
    local statCount = #Config.Stats
    local tabGap = self.mode == "Compact" and 6 or 10
    for i, stat in Config.Stats do
        local holder, face, fill, faceEdge = createLipButton(tabs, {
            Name = stat.Id,
            Position = UDim2.new((i - 1) / statCount, (i - 1) * tabGap / statCount, 0, 0),
            Size = UDim2.new(1 / statCount, -tabGap * (statCount - 1) / statCount, 1, 0),
        }, metrics.Lip, self.interactive)
        local glow = addStroke(holder, Theme.Gold, 3, 1)
        local content = create("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            ZIndex = 2,
        }, face)
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, math.floor(metrics.Icon * 0.4)),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, content)
        local glyph = createStatIcon(content, stat.Kind, metrics.Icon)
        local tabLabel = createLabel(content, {
            Name = "Label",
            Text = stat.Tab,
            FontFace = HEAD_FONT,
            TextSize = metrics.TabText,
            TextColor3 = Theme.TabText,
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            TextTruncate = Enum.TextTruncate.None,
            LayoutOrder = 2,
        })
        face.Activated:Connect(function()
            self.callbacks.onTab(stat.Id)
        end)
        self.tabs[i] = {
            id = stat.Id,
            holder = holder,
            button = face,
            fill = fill,
            edge = faceEdge,
            glow = glow,
            text = tabLabel,
            icon = glyph,
        }
    end
end

-- Scope: a recessed track with two segments (THIS SERVER / GLOBAL).
local function buildScopeToggle(self, root, y)
    local metrics = self.M
    local track = create("Frame", {
        Name = "Scope",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, y),
        Size = UDim2.fromOffset(metrics.ScopeW, metrics.ScopeH),
        BackgroundColor3 = Theme.Well,
        BorderSizePixel = 0,
    }, root)
    addCorner(track, 10)
    addStroke(track, Theme.WellEdge, 1.5)
    self.scopeButtons = {}
    for i, id in { "Server", "Global" } do
        local segmentPosition, segmentSize =
            UDim2.new((i - 1) * 0.5, i == 1 and 3 or 1, 0, 3), UDim2.new(0.5, -4, 1, -6)
        -- the selected pill sits behind the text (a gradient on the button itself would tint its text too)
        local pill = create("Frame", {
            Name = id .. "Pill",
            Position = segmentPosition,
            Size = segmentSize,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, track)
        addCorner(pill, 8)
        addGradient(pill, Theme.Crimson, Theme.CrimsonLow)
        local edgeStroke = addStroke(pill, Theme.Gold, 1.5, 1)
        local scopeButton = create("TextButton", {
            Name = id,
            Position = segmentPosition,
            Size = segmentSize,
            BackgroundTransparency = 1,
            Text = id == "Server" and "THIS SERVER" or "GLOBAL",
            FontFace = HEAD_FONT,
            TextSize = metrics.Scope + 1,
            TextColor3 = Theme.PageSoft,
            AutoButtonColor = false,
            Selectable = self.interactive,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, track)
        scopeButton.Activated:Connect(function()
            self.callbacks.onScope(id)
        end)
        self.scopeButtons[id] = { button = scopeButton, pill = pill, edge = edgeStroke }
    end
end

-- Column labels (only when metrics.Column > 0).
local function buildColumnLabels(self, root, y)
    local metrics = self.M
    local columns = create("Frame", {
        Name = "Columns",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, metrics.Column),
    }, root)
    createLabel(columns, {
        Text = "RANK",
        FontFace = HEAVY_FONT,
        TextSize = metrics.ColText,
        TextColor3 = Theme.PageFaint,
        TextXAlignment = Enum.TextXAlignment.Center,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(0, metrics.Badge, 1, 0),
    })
    createLabel(columns, {
        Text = "PLAYER",
        FontFace = HEAVY_FONT,
        TextSize = metrics.ColText,
        TextColor3 = Theme.PageFaint,
        Position = UDim2.fromOffset(16 + metrics.Badge + 10 + metrics.Avatar + 12, 0),
        Size = UDim2.new(0, 160, 1, 0),
    })
    self.columnValue = createLabel(columns, {
        Text = "",
        FontFace = HEAVY_FONT,
        TextSize = metrics.ColText,
        TextColor3 = Theme.PageFaint,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -24 - metrics.Bar, 0, 0),
        Size = UDim2.new(0, metrics.ValueW, 1, 0),
    })
end

-- The well holding the pooled rows' ScrollingFrame.
local function buildWell(self, root, y)
    local metrics = self.M
    local bottom = metrics.You + metrics.Meta + metrics.Gap + 4
    local well = create("Frame", {
        Name = "Well",
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 1, -(y + bottom)),
        BackgroundColor3 = Theme.Well,
        BorderSizePixel = 0,
    }, root)
    addCorner(well, 12)
    addStroke(well, Theme.WellEdge, 1.5)
    self.well = well
    self.list = create("ScrollingFrame", {
        Name = "List",
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(1, -12, 1, -12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        ScrollBarThickness = metrics.Bar,
        ScrollBarImageColor3 = Theme.Scroll,
        ScrollBarImageTransparency = 0.15,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        Selectable = self.interactive,
        SelectionGroup = false,
    }, well)
end

-- Overlays for the loading skeleton / empty trophy / unavailable states.
local function buildStatusStates(self, well)
    local metrics = self.M
    local status = create("Frame", {
        Name = "Status",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 3,
    }, well)
    self.status = status
    self.skeleton = create("Frame", {
        Name = "Skeleton",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(1, -16, 1, -16),
        ZIndex = 3,
    }, status)
    for i = 1, 4 do
        local skeletonBar = create("Frame", {
            BackgroundColor3 = Theme.Cream,
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            ZIndex = 3,
            Position = UDim2.fromOffset(0, (i - 1) * metrics.Row),
            Size = UDim2.new(1, 0, 0, metrics.Row - metrics.Gap - 3),
        }, self.skeleton)
        addCorner(skeletonBar, 12)
        table.insert(self.tweens, TweenService:Create(skeletonBar, PULSE_TWEEN, { BackgroundTransparency = 0.7 }))
    end
    self.trophy = create("Frame", {
        Name = "Trophy",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 0.5, -metrics.Name),
        Size = UDim2.fromOffset(metrics.Avatar * 1.8, metrics.Avatar * 1.5),
        ZIndex = 3,
    }, status)
    do
        local trophy = self.trophy
        local cup = create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.22, 0),
            Size = UDim2.fromScale(0.56, 0.56),
            ZIndex = 3,
        }, trophy)
        create("UICorner", { CornerRadius = UDim.new(0.3, 0) }, cup)
        addGradient(cup, Theme.GoldLight, Theme.GoldDeep)
        addStroke(cup, Theme.GoldInk, 2)
        local gem = create("Frame", {
            BackgroundColor3 = Theme.CrimsonLow,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.42),
            Size = UDim2.fromScale(0.3, 0.3),
            ZIndex = 4,
        }, cup)
        create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, gem)
        local stem = create("Frame", {
            BackgroundColor3 = Theme.GoldDeep,
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.42, 0.54),
            Size = UDim2.fromScale(0.16, 0.2),
            ZIndex = 3,
        }, trophy)
        addStroke(stem, Theme.GoldInk, 1)
        local foot = create("Frame", {
            BackgroundColor3 = Theme.WoodTop,
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.26, 0.74),
            Size = UDim2.fromScale(0.48, 0.2),
            ZIndex = 3,
        }, trophy)
        addCorner(foot, 3)
        addStroke(foot, Theme.Gold, 1.5)
        for _, x in { 0.02, 0.84 } do
            local coin = create("Frame", {
                BackgroundColor3 = Theme.Gold,
                BorderSizePixel = 0,
                Position = UDim2.fromScale(x, 0.8),
                Size = UDim2.fromScale(0.14, 0.12),
                ZIndex = 3,
            }, trophy)
            create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, coin)
            addStroke(coin, Theme.GoldInk, 1)
        end
    end
    self.statusTitle = createLabel(status, {
        FontFace = HEAD_FONT,
        TextSize = metrics.Name + 4,
        TextColor3 = Theme.PageText,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, -metrics.Name + 4),
        Size = UDim2.new(1, -40, 0, metrics.Name + 8),
    })
    self.statusBody = createLabel(status, {
        TextSize = metrics.User + 1,
        TextColor3 = Theme.PageSoft,
        TextXAlignment = Enum.TextXAlignment.Center,
        FontFace = BOLD_FONT,
        ZIndex = 3,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, 14),
        Size = UDim2.new(1, -60, 0, (metrics.User + 4) * 2),
    })
    local statusHolder, statusFace = createLipButton(status, {
        Name = "ViewServer",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, 14 + (metrics.User + 4) * 2 + 4),
        Size = UDim2.fromOffset(metrics.ScopeW - 40, metrics.ScopeH + metrics.Lip),
        Top = Theme.GoldLight,
        Bottom = Theme.GoldDeep,
        Lip = Theme.GoldInk,
        Edge = Theme.GoldInk,
    }, metrics.Lip, self.interactive)
    createLabel(statusFace, {
        Text = "VIEW THIS SERVER",
        FontFace = HEAD_FONT,
        TextSize = metrics.Scope + 2,
        TextColor3 = Theme.GoldInk,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
    })
    statusFace.Activated:Connect(function()
        self.callbacks.onScope("Server")
    end)
    self.statusButton = statusHolder
end

-- YOUR RANK: crimson and gold, always pinned under the list.
local function buildYourRank(self, root)
    local metrics = self.M
    local youHolder = create("Frame", {
        Name = "YourRank",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, -(metrics.Meta + 2)),
        Size = UDim2.new(1, 0, 0, metrics.You),
        BackgroundTransparency = 1,
    }, root)
    self.youRow = buildRow(youHolder, metrics, "You", true)
    self.youLabel = createLabel(self.youRow.face, {
        Name = "Label",
        Text = "YOUR RANK",
        FontFace = HEAVY_FONT,
        TextSize = math.max(9, metrics.User - 1),
        TextColor3 = Theme.YouSub,
        Position = UDim2.fromOffset(8 + metrics.YouRank + 8 + 10 + metrics.Avatar + 12, 4),
        Size = UDim2.new(0.5, 0, 0, metrics.User + 2),
    })
end

-- Meta line under the card (scope summary left, data age right).
local function buildMetaLine(self, root)
    local metrics = self.M
    self.metaLeft = createLabel(root, {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 4, 1, 0),
        Size = UDim2.new(0.6, 0, 0, metrics.Meta),
        TextSize = metrics.MetaText,
        TextColor3 = Theme.PageFaint,
        FontFace = BOLD_FONT,
    })
    self.metaRight = createLabel(root, {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -4, 1, 0),
        Size = UDim2.new(0.4, 0, 0, metrics.Meta),
        TextSize = metrics.MetaText,
        TextColor3 = Theme.PageFaint,
        TextXAlignment = Enum.TextXAlignment.Right,
        FontFace = BOLD_FONT,
    })
end

-- Builds the whole view top to bottom; `y` is the running vertical offset inside the padded root.
function View:_build(parent)
    local metrics = self.M
    local root = create("Frame", {
        Name = "Leaderboard",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, parent)
    addGradient(root, Theme.WoodTop, Theme.Wood)
    local edge = metrics.Edge or 0
    create("UIPadding", {
        PaddingLeft = UDim.new(0, metrics.Pad + edge),
        PaddingRight = UDim.new(0, metrics.Pad + edge),
        PaddingTop = UDim.new(0, metrics.Pad - 6 + edge),
        PaddingBottom = UDim.new(0, metrics.Pad - 8 + edge),
    }, root)
    self.root = root
    local y = 0

    buildHeader(self, root)
    y += metrics.Header + 2
    buildTabs(self, root, y)
    y += metrics.Tabs + metrics.Gap + 2
    buildScopeToggle(self, root, y)
    y += metrics.ScopeH + metrics.Gap
    if metrics.Column > 0 then
        buildColumnLabels(self, root, y)
        y += metrics.Column
    end
    buildWell(self, root, y)
    buildStatusStates(self, self.well)
    buildYourRank(self, root)
    if metrics.Meta == 0 then
        return
    end
    buildMetaLine(self, root)
end

function View:_row(i)
    local row = buildRow(self.list, self.M, "Row" .. i, false)
    row.frame.Position = UDim2.fromOffset(0, (i - 1) * self.M.Row + 2)
    self.rows[i] = row
    return row
end

-- ===== 4. State changes =====
function View:_selectTab(index, animate)
    for i, tab in self.tabs do
        local isSelected = i == index
        tab.fill.Color = isSelected and ColorSequence.new(Theme.Crimson, Theme.CrimsonLow)
            or ColorSequence.new(Theme.Charcoal, Theme.CharcoalLow)
        tab.holder.BackgroundColor3 = isSelected and Theme.CrimsonLip or Theme.CharcoalLip
        tab.edge.Color = isSelected and Theme.Gold or Theme.CharcoalLip
        tab.edge.Thickness = isSelected and 2 or 1.5
        setIconTint(tab.icon, isSelected and Theme.TabTextOn or Theme.TabText)
        local goal = isSelected and 0.55 or 1
        if animate then
            TweenService:Create(tab.glow, QUICK_TWEEN, { Transparency = goal }):Play()
            TweenService:Create(tab.text, QUICK_TWEEN, { TextColor3 = isSelected and Theme.TabTextOn or Theme.TabText })
                :Play()
        else
            tab.glow.Transparency = goal
            tab.text.TextColor3 = isSelected and Theme.TabTextOn or Theme.TabText
        end
    end
    self.tabIndex = index
end

function View:_selectScope(scope, animate)
    for id, segment in self.scopeButtons do
        local isSelected = id == scope
        local pillTransparency, textColor = isSelected and 0 or 1, isSelected and Theme.TabTextOn or Theme.PageSoft
        if animate then
            TweenService:Create(segment.pill, QUICK_TWEEN, { BackgroundTransparency = pillTransparency }):Play()
            TweenService:Create(segment.button, QUICK_TWEEN, { TextColor3 = textColor }):Play()
        else
            segment.pill.BackgroundTransparency = pillTransparency
            segment.button.TextColor3 = textColor
        end
        segment.edge.Transparency = isSelected and 0 or 1
    end
    self.scopeId = scope
end

function View:_setStatus(kind, title, body, showButton)
    self.status.Visible = kind ~= nil
    self.list.Visible = kind == nil
    local loading = kind == "loading"
    self.skeleton.Visible = loading
    for _, tween in self.tweens do
        if loading then
            tween:Play()
        else
            tween:Cancel()
        end
    end
    self.trophy.Visible = kind == "empty"
    self.statusTitle.Visible = not loading
    self.statusBody.Visible = not loading
    if title then
        self.statusTitle.Text = title
        self.statusBody.Text = body or ""
    end
    self.statusButton.Visible = showButton == true
end

function View:_meta(state)
    if not self.metaLeft then
        return
    end
    local snapshot = state.snapshot
    if state.scope == "Server" then
        local rankedCount = snapshot and snapshot.total
        self.metaLeft.Text = rankedCount and string.format("THIS SERVER  ·  %d ranked", rankedCount) or "THIS SERVER"
    else
        self.metaLeft.Text = "GLOBAL  ·  all servers, top " .. Config.MaxRows
    end
    local rightText = ""
    if snapshot and snapshot.updated then
        local age = workspace:GetServerTimeNow() - snapshot.updated
        rightText = snapshot.status == "stale" and ("Couldn't refresh  ·  from " .. Format.Age(age))
            or ("Updated " .. Format.Age(age))
    end
    self.metaRight.Text = rightText
end

-- Values roll up from 0 to the server's number, then show it exactly.
function View:_countUp(kind)
    if self.counter then
        self.counter:Disconnect()
        self.counter = nil
    end
    local reducedMotion = Players.LocalPlayer and Players.LocalPlayer:GetAttribute("ReducedMotion") == true
    if reducedMotion then
        return
    end
    local countingRows = {}
    for _, row in self.rows do
        if row.frame.Visible and row.target then
            table.insert(countingRows, row)
        end
    end
    if self.youRow.target then
        table.insert(countingRows, self.youRow)
    end
    if #countingRows == 0 then
        return
    end
    local startedAt = os.clock()
    self.counter = RunService.Heartbeat:Connect(function()
        local progress = math.clamp((os.clock() - startedAt) / COUNT_TIME, 0, 1)
        local eased = 1 - (1 - progress) ^ 3
        for _, row in countingRows do
            if row.target then
                row.value.Text = Format.Value(kind, progress >= 1 and row.target or math.floor(row.target * eased))
            end
        end
        if progress >= 1 and self.counter then
            self.counter:Disconnect()
            self.counter = nil
        end
    end)
end

-- ===== 5. Public API =====
--[[ state = {
	tab, scope, phase = "loading" | "ready" | "error",
	snapshot = { status, entries, total, updated, depth, you = { r, v } } | nil,
	localUserId, localName, localDisplayName,
} ]]
function View:Render(state)
    self.state = state
    local stat = Config.StatById[state.tab]
    local index = 1
    for i, tab in self.tabs do
        if tab.id == state.tab then
            index = i
        end
    end
    if index ~= self.tabIndex then
        self:_selectTab(index, self.tabIndex ~= nil)
    end
    if state.scope ~= self.scopeId then
        self:_selectScope(state.scope, self.scopeId ~= nil)
    end
    if self.columnValue then
        self.columnValue.Text = stat.Column
    end

    -- remember scroll per tab + scope; a data update for the same key never moves the list
    local key = state.tab .. "|" .. state.scope
    local restore
    if key ~= self.key then
        if self.key then
            self.scroll[self.key] = self.list.CanvasPosition
        end
        self.key = key
        restore = self.scroll[key] or Vector2.zero
    end

    local snapshot = state.snapshot
    local entries = snapshot and snapshot.entries or {}
    local count = math.min(#entries, Config.MaxRows)
    -- count up once per tab + scope, the first time it has rows
    local animate = count > 0 and self.counted ~= key
    if animate then
        self.counted = key
    end
    for i = 1, count do
        local row = self.rows[i] or self:_row(i)
        local entry = entries[i]
        fillRow(row, entry, stat.Kind, entry.u == state.localUserId, i % 2 == 0, animate and 0 or nil)
        row.frame.Visible = true
    end
    for i = count + 1, #self.rows do
        self.rows[i].frame.Visible = false
        self.rows[i].target = nil
    end
    self.list.CanvasSize = UDim2.fromOffset(0, count * self.M.Row + 4)
    if restore then
        local list = self.list
        task.defer(function()
            if list.Parent then
                list.CanvasPosition = restore
            end
        end)
    end

    -- loading / empty / unavailable
    local status = snapshot and snapshot.status
    if count > 0 then
        self:_setStatus(nil)
    elseif state.phase == "error" and not snapshot then
        self:_setStatus("error", "Couldn't load rankings", "Trying again in a few seconds.")
    elseif state.phase == "loading" or status == "loading" then
        self:_setStatus("loading")
    elseif status == "unavailable" then
        self:_setStatus(
            "error",
            "Global rankings are resting",
            "We couldn't reach the global scores. Your score is safe.",
            true
        )
    else
        self:_setStatus("empty", "The first spot is open", stat.Empty)
    end

    -- YOUR RANK
    local yourRank = snapshot and snapshot.you
    local ownEntry = {
        r = yourRank and yourRank.r,
        u = state.localUserId,
        n = state.localName,
        d = state.localDisplayName,
        v = yourRank and yourRank.v,
    }
    fillRow(self.youRow, ownEntry, stat.Kind, false, false, animate and ownEntry.v and 0 or nil)
    self.youLabel.Text = "YOUR RANK  ·  " .. (state.scope == "Server" and "THIS SERVER" or "GLOBAL")
    self.youRow.user.Text = yourRankNote(ownEntry, entries, snapshot, status, state.scope, stat.Kind)
    self.youRow.rank.Text = ownEntry.r and ("#" .. ownEntry.r) or "—"
    if animate then
        self:_countUp(stat.Kind)
    end

    self:_meta(state)
end

function View:Tick()
    if self.state then
        self:_meta(self.state)
    end
end

function View:DefaultSelection()
    local tab = self.tabs[self.tabIndex or 1]
    return tab and tab.button
end

function View:Destroy()
    if self.counter then
        self.counter:Disconnect()
        self.counter = nil
    end
    for _, tween in self.tweens do
        tween:Cancel()
    end
    if self.root then
        self.root:Destroy()
    end
    self.root = nil
end

return View
