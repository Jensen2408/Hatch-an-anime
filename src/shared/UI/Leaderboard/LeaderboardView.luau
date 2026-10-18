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
]]
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(script.Parent.LeaderboardConfig)
local Format = require(script.Parent.LeaderboardFormat)

local T = Config.Theme
local HEAD = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BOLD = Font.new("rbxasset://fonts/families/FredokaOne.json")
local HEAVY = Font.new("rbxasset://fonts/families/FredokaOne.json")
local QUICK = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local PRESS = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local PULSE = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local COUNT_TIME = 0.6

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

---------------------------------------------------------------- helpers
local function make(class, props, parent)
    local inst = Instance.new(class)
    for k, v in props do
        inst[k] = v
    end
    inst.Parent = parent
    return inst
end

local function corner(parent, radius)
    return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent, color, thickness, transparency, contextual)
    return make("UIStroke", {
        Color = color,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = contextual and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function gradient(parent, top, bottom, rotation)
    return make("UIGradient", { Rotation = rotation or 90, Color = ColorSequence.new(top, bottom) }, parent)
end

local function label(parent, props)
    local base = {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        TextColor3 = T.Ink,
        FontFace = BODY,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }
    for k, v in props do
        base[k] = v
    end
    return make("TextLabel", base, parent)
end

-- Embossed gold lettering: white text tinted by a gold gradient, with a dark-brown outline.
local function goldText(parent, props, outline)
    local t = label(parent, props)
    t.TextColor3 = Color3.new(1, 1, 1)
    make("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 244, 200)),
            ColorSequenceKeypoint.new(0.35, T.GoldLight),
            ColorSequenceKeypoint.new(0.62, T.Gold),
            ColorSequenceKeypoint.new(1, T.GoldDeep),
        }),
    }, t)
    stroke(t, T.GoldInk, outline or 2, 0, true)
    return t
end

-- A pressable button: a darker lip with the face on top; pressing pushes the face onto the lip.
local function lipButton(parent, props, lip, selectable)
    local holder = make("Frame", {
        Name = props.Name or "Button",
        AnchorPoint = props.AnchorPoint or Vector2.zero,
        Position = props.Position,
        Size = props.Size,
        BackgroundColor3 = props.Lip or T.CharcoalLip,
        BorderSizePixel = 0,
        LayoutOrder = props.LayoutOrder or 0,
    }, parent)
    corner(holder, props.Radius or 10)
    local scale = make("UIScale", {}, holder)
    local face = make("TextButton", {
        Name = "Face",
        Size = UDim2.new(1, 0, 1, -lip),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Selectable = selectable,
        ClipsDescendants = true,
    }, holder)
    corner(face, props.Radius or 10)
    local fill = gradient(face, props.Top or T.Charcoal, props.Bottom or T.CharcoalLow)
    local edge = stroke(face, props.Edge or T.CharcoalLip, props.EdgeWidth or 1.5)
    local pressed = false
    local function down()
        TweenService:Create(face, PRESS, { Position = UDim2.fromOffset(0, lip - 1) }):Play()
        TweenService:Create(scale, PRESS, { Scale = 0.98 }):Play()
    end
    local function up()
        TweenService:Create(face, RELEASE, { Position = UDim2.fromOffset(0, 0) }):Play()
        TweenService:Create(scale, RELEASE, { Scale = 1 }):Play()
    end
    face.InputBegan:Connect(function(input)
        local kind = input.UserInputType
        if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
            pressed = true
            down()
        end
    end)
    face.InputEnded:Connect(function(input)
        local kind = input.UserInputType
        if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
            pressed = false
            up()
        end
    end)
    face.Activated:Connect(function()
        if not pressed then
            down()
            task.delay(0.07, up)
        end -- gamepad / keyboard: the same press, played through
    end)
    return holder, face, fill, edge
end

-- Small gold cloud scroll (three rounded bars) that frames the title.
local function cloud(parent, width, mirror)
    local f = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(width, width * 0.36) }, parent)
    local h = math.max(3, math.floor(width * 0.07))
    local bars = { { 0.0, 0.62, 0.55 }, { 0.22, 1.0, 0.70 }, { 0.5, 0.22, 0.45 } } -- x, y (0..1), width share
    for _, b in bars do
        local x = mirror and (1 - b[1] - b[3]) or b[1]
        local bar = make("Frame", {
            BackgroundColor3 = T.Accent,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(x, 0, b[2] * 0.8 + 0.1, 0),
            Size = UDim2.new(b[3], 0, 0, h),
        }, f)
        corner(bar, h)
        stroke(bar, T.GoldInk, 1, 0.2)
    end
    return f
end

-- Tab icons drawn from frames: a coin stack, rising bars, an egg.
local function icon(parent, kind, size)
    local f = make(
        "Frame",
        { Name = "Icon", BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), LayoutOrder = 1 },
        parent
    )
    if kind == "money" then
        for i = 0, 2 do
            local c = make("Frame", {
                BackgroundColor3 = i == 2 and T.GoldLight or T.Gold,
                BorderSizePixel = 0,
                Position = UDim2.new(0.08, 0, 0.62 - i * 0.24, 0),
                Size = UDim2.new(0.84, 0, 0.3, 0),
            }, f)
            corner(c, size)
            stroke(c, T.GoldInk, 1)
        end
    elseif kind == "rate" then
        for i, h in { 0.4, 0.66, 0.92 } do
            local b = make("Frame", {
                BackgroundColor3 = Color3.new(1, 1, 1),
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0, 1),
                Position = UDim2.new((i - 1) * 0.34 + 0.02, 0, 1, 0),
                Size = UDim2.new(0.26, 0, h, 0),
                Name = "Tint",
            }, f)
            corner(b, 2)
        end
    else
        local egg = make("Frame", {
            BackgroundColor3 = T.Paper,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.52),
            Size = UDim2.new(0.74, 0, 0.96, 0),
        }, f)
        make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, egg)
        stroke(egg, T.InkSoft, 1)
        local band = make("Frame", {
            BackgroundColor3 = T.Medal[3][2],
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.12, 0.5),
            Size = UDim2.new(0.76, 0, 0.1, 0),
        }, egg)
        corner(band, 2)
    end
    return f
end

local function setIconTint(f, color)
    for _, c in f:GetChildren() do
        if c.Name == "Tint" then
            c.BackgroundColor3 = color
        end
    end
end

local function medalStyle(rank)
    return rank and T.Medal[rank]
end

local function buildRow(parent, M, name, pinned)
    local row = { pinned = pinned }
    local h = pinned and M.You or (M.Row - M.Gap)
    local holder = make("Frame", {
        Name = name,
        Size = UDim2.new(1, 0, 0, h),
        BackgroundColor3 = pinned and T.CrimsonLip or T.CreamLip,
        BorderSizePixel = 0,
    }, parent)
    corner(holder, 12)
    row.frame = holder
    local face = make("Frame", {
        Name = "Face",
        Size = UDim2.new(1, 0, 1, -3),
        BackgroundColor3 = pinned and Color3.new(1, 1, 1) or T.Cream,
        BorderSizePixel = 0,
    }, holder)
    corner(face, 12)
    row.face = face
    row.fill = pinned and gradient(face, T.Crimson, T.CrimsonLow)
        or gradient(face, Color3.new(1, 1, 1), Color3.fromRGB(234, 222, 200))
    row.edge = stroke(face, pinned and T.Gold or T.CreamEdge, pinned and 2 or 1.5)

    local x = 8
    local badge = pinned and M.YouRank or M.Badge
    row.badge = make("Frame", {
        Name = "Rank",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, x, 0.5, 0),
        Size = UDim2.fromOffset(badge + (pinned and 8 or 0), badge),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, face)
    corner(row.badge, 10)
    row.badgeFill = gradient(row.badge, T.Charcoal, T.CharcoalLow, 135)
    row.badgeStroke = stroke(row.badge, pinned and T.Gold or T.CharcoalLip, pinned and 2 or 1.5)
    row.rank = label(row.badge, {
        Size = UDim2.fromScale(1, 1),
        FontFace = HEAD,
        TextSize = math.floor(badge * 0.5),
        TextColor3 = pinned and T.TabTextOn or T.Paper,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
    })

    x += badge + (pinned and 8 or 0) + 10
    row.avatar = make("ImageLabel", {
        Name = "Avatar",
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, x, 0.5, 0),
        Size = UDim2.fromOffset(M.Avatar, M.Avatar),
        BackgroundColor3 = T.Avatar,
        BorderSizePixel = 0,
        ScaleType = Enum.ScaleType.Crop,
        Image = "",
    }, face)
    corner(row.avatar, 10)
    row.avatarStroke = stroke(row.avatar, pinned and T.Gold or T.CreamEdge, 1.5)

    x += M.Avatar + 12
    local names = make("Frame", {
        Name = "Names",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(x, 0),
        Size = UDim2.new(1, -(x + M.ValueW + 22), 1, 0),
        ClipsDescendants = true,
    }, face)
    local nameRow = make("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 0.5, pinned and 8 or 4),
        Size = UDim2.new(1, 0, 0, M.Name + 6),
    }, names)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, nameRow)
    row.name = label(nameRow, {
        Name = "DisplayName",
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        FontFace = HEAD,
        TextSize = M.Name,
        TextColor3 = pinned and T.YouText or T.Ink,
        LayoutOrder = 1,
    })
    make("UISizeConstraint", { MaxSize = Vector2.new(math.max(80, 340 - M.ValueW), 1000) }, row.name)
    if not pinned then
        row.you = label(nameRow, {
            Name = "You",
            Text = "YOU",
            FontFace = HEAVY,
            TextSize = math.max(9, M.User - 2),
            TextColor3 = T.TabTextOn,
            BackgroundTransparency = 0,
            BackgroundColor3 = T.CrimsonLow,
            Size = UDim2.fromOffset(0, M.User + 4),
            AutomaticSize = Enum.AutomaticSize.X,
            TextXAlignment = Enum.TextXAlignment.Center,
            Visible = false,
            LayoutOrder = 2,
        })
        corner(row.you, 4)
        make("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5) }, row.you)
    end
    row.user = label(names, {
        Name = "Username",
        Position = UDim2.new(0, 0, 0.5, pinned and 8 or 4),
        Size = UDim2.new(1, 0, 0, M.User + 4),
        FontFace = BOLD,
        TextSize = M.User,
        TextColor3 = pinned and T.YouSub or T.InkFaint,
    })
    if pinned then
        row.value = goldText(face, {
            Name = "Value",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -16, 0.5, 0),
            Size = UDim2.new(0, M.ValueW, 1, 0),
            FontFace = HEAD,
            TextSize = M.Value + 6,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.None,
        }, 2)
    else
        row.value = label(face, {
            Name = "Value",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, -16, 0.5, 0),
            Size = UDim2.new(0, M.ValueW, 1, 0),
            FontFace = HEAD,
            TextSize = M.Value,
            TextXAlignment = Enum.TextXAlignment.Right,
            TextTruncate = Enum.TextTruncate.None,
        })
        -- hover: lift the face off its lip a little
        face.MouseEnter:Connect(function()
            TweenService:Create(face, QUICK, { Position = UDim2.fromOffset(0, -2) }):Play()
        end)
        face.MouseLeave:Connect(function()
            TweenService:Create(face, QUICK, { Position = UDim2.fromOffset(0, 0) }):Play()
        end)
    end
    return row
end

-- e = { r = rank?, u = userId, n = username?, d = displayName?, v = value? }
local function fillRow(row, e, kind, isSelf, alt, shown)
    local medal = medalStyle(e.r)
    if not row.pinned then
        local bg, edge, lip = alt and T.CreamAlt or T.Cream, T.CreamEdge, T.CreamLip
        if medal then
            bg, edge, lip = medal[4], medal[2], medal[2]:Lerp(T.Ink, 0.35)
        end
        row.face.BackgroundColor3 = bg
        row.frame.BackgroundColor3 = lip
        row.edge.Color = isSelf and T.CrimsonLow or edge
        row.edge.Thickness = isSelf and 2.5 or 1.5
        if row.you then
            row.you.Visible = isSelf
        end
        row.value.TextColor3 = medal and medal[3] or T.Ink
    end
    if medal then
        row.badgeFill.Color = ColorSequence.new(medal[1], medal[2])
        row.badgeStroke.Color = medal[2]:Lerp(T.Ink, 0.4)
        row.rank.TextColor3 = medal[3]
    elseif row.pinned then
        row.badgeFill.Color = ColorSequence.new(T.CrimsonLip, T.CrimsonLip)
        row.badgeStroke.Color = T.Gold
        row.rank.TextColor3 = T.TabTextOn
    else
        row.badgeFill.Color = ColorSequence.new(T.Charcoal, T.CharcoalLow)
        row.badgeStroke.Color = T.CharcoalLip
        row.rank.TextColor3 = T.Paper
    end
    row.rank.Text = e.r and ((row.pinned and "#" or "") .. tostring(e.r)) or "—"
    local image = (e.u and e.u > 0) and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60", e.u) or ""
    if row.avatar.Image ~= image then
        row.avatar.Image = image
    end
    row.name.Text = e.d or e.n or "Unknown player"
    row.user.Text = e.n and ("@" .. e.n) or (e.u and ("ID " .. e.u) or "")
    row.target = e.v
    local v = shown or e.v
    row.value.Text = v and Format.Value(kind, v) or "—"
end

---------------------------------------------------------------- construction
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

function View:_build(parent)
    local M = self.M
    local root = make("Frame", {
        Name = "Leaderboard",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, parent)
    gradient(root, T.WoodTop, T.Wood)
    local edge = M.Edge or 0
    make("UIPadding", {
        PaddingLeft = UDim.new(0, M.Pad + edge),
        PaddingRight = UDim.new(0, M.Pad + edge),
        PaddingTop = UDim.new(0, M.Pad - 6 + edge),
        PaddingBottom = UDim.new(0, M.Pad - 8 + edge),
    }, root)
    self.root = root
    local y = 0

    -- header: title between gold cloud scrolls (close on the right of the expanded view)
    local header =
        make("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, M.Header) }, root)
    local titleRow = make("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
    }, header)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        Padding = UDim.new(0, math.floor(M.Title * 0.4)),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, titleRow)
    if M.Cloud > 0 then
        cloud(titleRow, M.Cloud, false).LayoutOrder = 1
    end
    -- embossed gold title
    local title = goldText(titleRow, {
        Name = "Title",
        Text = "LEADERBOARD",
        FontFace = HEAD,
        TextSize = M.Title,
        LayoutOrder = 2,
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        TextTruncate = Enum.TextTruncate.None,
    }, M.Title >= 36 and 3 or 2)
    if M.Cloud > 0 then
        cloud(titleRow, M.Cloud, true).LayoutOrder = 3
    end
    self.title = title

    if self.mode ~= "Board" then
        local size = M.ScopeH
        local _, close = lipButton(header, {
            Name = "Close",
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(size, size + M.Lip),
            Top = T.Crimson,
            Bottom = T.CrimsonLow,
            Lip = T.CrimsonLip,
            Edge = T.CrimsonLip,
        }, M.Lip, true)
        for _, rotation in { 45, -45 } do
            make("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.new(0.46, 0, 0, 3),
                Rotation = rotation,
                BackgroundColor3 = T.TabTextOn,
                BorderSizePixel = 0,
                ZIndex = 2,
            }, close)
        end
        close.Activated:Connect(function()
            self.callbacks.onClose()
        end)
        self.closeButton = close
    end
    y += M.Header + 2

    -- stat tabs
    local tabs = make("Frame", {
        Name = "Tabs",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, M.Tabs),
    }, root)
    self.tabs = {}
    local count = #Config.Stats
    local gap = self.mode == "Compact" and 6 or 10
    for i, stat in Config.Stats do
        local holder, face, fill, faceEdge = lipButton(tabs, {
            Name = stat.Id,
            Position = UDim2.new((i - 1) / count, (i - 1) * gap / count, 0, 0),
            Size = UDim2.new(1 / count, -gap * (count - 1) / count, 1, 0),
        }, M.Lip, self.interactive)
        local glow = stroke(holder, T.Gold, 3, 1)
        local content = make("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            ZIndex = 2,
        }, face)
        make("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            Padding = UDim.new(0, math.floor(M.Icon * 0.4)),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, content)
        local glyph = icon(content, stat.Kind, M.Icon)
        local text = label(content, {
            Name = "Label",
            Text = stat.Tab,
            FontFace = HEAD,
            TextSize = M.TabText,
            TextColor3 = T.TabText,
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
            text = text,
            icon = glyph,
        }
    end
    y += M.Tabs + M.Gap + 2

    -- scope: a recessed track with two segments
    local track = make("Frame", {
        Name = "Scope",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, y),
        Size = UDim2.fromOffset(M.ScopeW, M.ScopeH),
        BackgroundColor3 = T.Well,
        BorderSizePixel = 0,
    }, root)
    corner(track, 10)
    stroke(track, T.WellEdge, 1.5)
    self.scopeButtons = {}
    for i, id in { "Server", "Global" } do
        local position, size = UDim2.new((i - 1) * 0.5, i == 1 and 3 or 1, 0, 3), UDim2.new(0.5, -4, 1, -6)
        -- the selected pill sits behind the text (a gradient on the button itself would tint its text too)
        local pill = make("Frame", {
            Name = id .. "Pill",
            Position = position,
            Size = size,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
        }, track)
        corner(pill, 8)
        gradient(pill, T.Crimson, T.CrimsonLow)
        local edgeStroke = stroke(pill, T.Gold, 1.5, 1)
        local b = make("TextButton", {
            Name = id,
            Position = position,
            Size = size,
            BackgroundTransparency = 1,
            Text = id == "Server" and "THIS SERVER" or "GLOBAL",
            FontFace = HEAD,
            TextSize = M.Scope + 1,
            TextColor3 = T.PageSoft,
            AutoButtonColor = false,
            Selectable = self.interactive,
            BorderSizePixel = 0,
            ZIndex = 2,
        }, track)
        b.Activated:Connect(function()
            self.callbacks.onScope(id)
        end)
        self.scopeButtons[id] = { button = b, pill = pill, edge = edgeStroke }
    end
    y += M.ScopeH + M.Gap

    -- column labels
    if M.Column > 0 then
        local columns = make("Frame", {
            Name = "Columns",
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, y),
            Size = UDim2.new(1, 0, 0, M.Column),
        }, root)
        label(columns, {
            Text = "RANK",
            FontFace = HEAVY,
            TextSize = M.ColText,
            TextColor3 = T.PageFaint,
            TextXAlignment = Enum.TextXAlignment.Center,
            Position = UDim2.fromOffset(16, 0),
            Size = UDim2.new(0, M.Badge, 1, 0),
        })
        label(columns, {
            Text = "PLAYER",
            FontFace = HEAVY,
            TextSize = M.ColText,
            TextColor3 = T.PageFaint,
            Position = UDim2.fromOffset(16 + M.Badge + 10 + M.Avatar + 12, 0),
            Size = UDim2.new(0, 160, 1, 0),
        })
        self.columnValue = label(columns, {
            Text = "",
            FontFace = HEAVY,
            TextSize = M.ColText,
            TextColor3 = T.PageFaint,
            TextXAlignment = Enum.TextXAlignment.Right,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -24 - M.Bar, 0, 0),
            Size = UDim2.new(0, M.ValueW, 1, 0),
        })
        y += M.Column
    end

    -- the well with pooled rows
    local bottom = M.You + M.Meta + M.Gap + 4
    local well = make("Frame", {
        Name = "Well",
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 1, -(y + bottom)),
        BackgroundColor3 = T.Well,
        BorderSizePixel = 0,
    }, root)
    corner(well, 12)
    stroke(well, T.WellEdge, 1.5)
    self.well = well
    self.list = make("ScrollingFrame", {
        Name = "List",
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(1, -12, 1, -12),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        ScrollBarThickness = M.Bar,
        ScrollBarImageColor3 = T.Scroll,
        ScrollBarImageTransparency = 0.15,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        Selectable = self.interactive,
        SelectionGroup = false,
    }, well)

    -- states: loading skeleton / empty trophy / unavailable
    local status = make("Frame", {
        Name = "Status",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 3,
    }, well)
    self.status = status
    self.skeleton = make("Frame", {
        Name = "Skeleton",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.new(1, -16, 1, -16),
        ZIndex = 3,
    }, status)
    for i = 1, 4 do
        local s = make("Frame", {
            BackgroundColor3 = T.Cream,
            BackgroundTransparency = 0.35,
            BorderSizePixel = 0,
            ZIndex = 3,
            Position = UDim2.fromOffset(0, (i - 1) * M.Row),
            Size = UDim2.new(1, 0, 0, M.Row - M.Gap - 3),
        }, self.skeleton)
        corner(s, 12)
        table.insert(self.tweens, TweenService:Create(s, PULSE, { BackgroundTransparency = 0.7 }))
    end
    self.trophy = make("Frame", {
        Name = "Trophy",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 0.5, -M.Name),
        Size = UDim2.fromOffset(M.Avatar * 1.8, M.Avatar * 1.5),
        ZIndex = 3,
    }, status)
    do
        local t = self.trophy
        local cup = make("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.22, 0),
            Size = UDim2.fromScale(0.56, 0.56),
            ZIndex = 3,
        }, t)
        make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, cup)
        gradient(cup, T.GoldLight, T.GoldDeep)
        stroke(cup, T.GoldInk, 2)
        local gem = make("Frame", {
            BackgroundColor3 = T.CrimsonLow,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.42),
            Size = UDim2.fromScale(0.3, 0.3),
            ZIndex = 4,
        }, cup)
        make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, gem)
        local stem = make("Frame", {
            BackgroundColor3 = T.GoldDeep,
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.42, 0.54),
            Size = UDim2.fromScale(0.16, 0.2),
            ZIndex = 3,
        }, t)
        stroke(stem, T.GoldInk, 1)
        local foot = make("Frame", {
            BackgroundColor3 = T.WoodTop,
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.26, 0.74),
            Size = UDim2.fromScale(0.48, 0.2),
            ZIndex = 3,
        }, t)
        corner(foot, 3)
        stroke(foot, T.Gold, 1.5)
        for _, x in { 0.02, 0.84 } do
            local coin = make("Frame", {
                BackgroundColor3 = T.Gold,
                BorderSizePixel = 0,
                Position = UDim2.fromScale(x, 0.8),
                Size = UDim2.fromScale(0.14, 0.12),
                ZIndex = 3,
            }, t)
            make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, coin)
            stroke(coin, T.GoldInk, 1)
        end
    end
    self.statusTitle = label(status, {
        FontFace = HEAD,
        TextSize = M.Name + 4,
        TextColor3 = T.PageText,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 3,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, -M.Name + 4),
        Size = UDim2.new(1, -40, 0, M.Name + 8),
    })
    self.statusBody = label(status, {
        TextSize = M.User + 1,
        TextColor3 = T.PageSoft,
        TextXAlignment = Enum.TextXAlignment.Center,
        FontFace = BOLD,
        ZIndex = 3,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        TextTruncate = Enum.TextTruncate.None,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, 14),
        Size = UDim2.new(1, -60, 0, (M.User + 4) * 2),
    })
    local statusHolder, statusFace = lipButton(status, {
        Name = "ViewServer",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0.5, 14 + (M.User + 4) * 2 + 4),
        Size = UDim2.fromOffset(M.ScopeW - 40, M.ScopeH + M.Lip),
        Top = T.GoldLight,
        Bottom = T.GoldDeep,
        Lip = T.GoldInk,
        Edge = T.GoldInk,
    }, M.Lip, self.interactive)
    label(statusFace, {
        Text = "VIEW THIS SERVER",
        FontFace = HEAD,
        TextSize = M.Scope + 2,
        TextColor3 = T.GoldInk,
        TextXAlignment = Enum.TextXAlignment.Center,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 3,
    })
    statusFace.Activated:Connect(function()
        self.callbacks.onScope("Server")
    end)
    self.statusButton = statusHolder

    -- YOUR RANK: dark brown and gold, always pinned under the list
    local youHolder = make("Frame", {
        Name = "YourRank",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, -(M.Meta + 2)),
        Size = UDim2.new(1, 0, 0, M.You),
        BackgroundTransparency = 1,
    }, root)
    self.youRow = buildRow(youHolder, M, "You", true)
    self.youLabel = label(self.youRow.face, {
        Name = "Label",
        Text = "YOUR RANK",
        FontFace = HEAVY,
        TextSize = math.max(9, M.User - 1),
        TextColor3 = T.YouSub,
        Position = UDim2.fromOffset(8 + M.YouRank + 8 + 10 + M.Avatar + 12, 4),
        Size = UDim2.new(0.5, 0, 0, M.User + 2),
    })

    -- meta line
    if M.Meta == 0 then
        return
    end
    self.metaLeft = label(root, {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 4, 1, 0),
        Size = UDim2.new(0.6, 0, 0, M.Meta),
        TextSize = M.MetaText,
        TextColor3 = T.PageFaint,
        FontFace = BOLD,
    })
    self.metaRight = label(root, {
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -4, 1, 0),
        Size = UDim2.new(0.4, 0, 0, M.Meta),
        TextSize = M.MetaText,
        TextColor3 = T.PageFaint,
        TextXAlignment = Enum.TextXAlignment.Right,
        FontFace = BOLD,
    })
end

function View:_row(i)
    local row = buildRow(self.list, self.M, "Row" .. i, false)
    row.frame.Position = UDim2.fromOffset(0, (i - 1) * self.M.Row + 2)
    self.rows[i] = row
    return row
end

---------------------------------------------------------------- state changes
function View:_selectTab(index, animate)
    for i, tab in self.tabs do
        local on = i == index
        tab.fill.Color = on and ColorSequence.new(T.Crimson, T.CrimsonLow)
            or ColorSequence.new(T.Charcoal, T.CharcoalLow)
        tab.holder.BackgroundColor3 = on and T.CrimsonLip or T.CharcoalLip
        tab.edge.Color = on and T.Gold or T.CharcoalLip
        tab.edge.Thickness = on and 2 or 1.5
        setIconTint(tab.icon, on and T.TabTextOn or T.TabText)
        local goal = on and 0.55 or 1
        if animate then
            TweenService:Create(tab.glow, QUICK, { Transparency = goal }):Play()
            TweenService:Create(tab.text, QUICK, { TextColor3 = on and T.TabTextOn or T.TabText }):Play()
        else
            tab.glow.Transparency = goal
            tab.text.TextColor3 = on and T.TabTextOn or T.TabText
        end
    end
    self.tabIndex = index
end

function View:_selectScope(scope, animate)
    for id, s in self.scopeButtons do
        local on = id == scope
        local fill, ink = on and 0 or 1, on and T.TabTextOn or T.PageSoft
        if animate then
            TweenService:Create(s.pill, QUICK, { BackgroundTransparency = fill }):Play()
            TweenService:Create(s.button, QUICK, { TextColor3 = ink }):Play()
        else
            s.pill.BackgroundTransparency = fill
            s.button.TextColor3 = ink
        end
        s.edge.Transparency = on and 0 or 1
    end
    self.scopeId = scope
end

function View:_setStatus(kind, title, body, showButton)
    self.status.Visible = kind ~= nil
    self.list.Visible = kind == nil
    local loading = kind == "loading"
    self.skeleton.Visible = loading
    for _, tw in self.tweens do
        if loading then
            tw:Play()
        else
            tw:Cancel()
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
    local snap = state.snapshot
    if state.scope == "Server" then
        local n = snap and snap.total
        self.metaLeft.Text = n and string.format("THIS SERVER  ·  %d ranked", n) or "THIS SERVER"
    else
        self.metaLeft.Text = "GLOBAL  ·  all servers, top " .. Config.MaxRows
    end
    local right = ""
    if snap and snap.updated then
        local age = workspace:GetServerTimeNow() - snap.updated
        right = snap.status == "stale" and ("Couldn't refresh  ·  from " .. Format.Age(age))
            or ("Updated " .. Format.Age(age))
    end
    self.metaRight.Text = right
end

-- Values roll up from 0 to the server's number, then show it exactly.
function View:_countUp(kind)
    if self.counter then
        self.counter:Disconnect()
        self.counter = nil
    end
    local reduced = Players.LocalPlayer and Players.LocalPlayer:GetAttribute("ReducedMotion") == true
    if reduced then
        return
    end
    local rows = {}
    for _, row in self.rows do
        if row.frame.Visible and row.target then
            table.insert(rows, row)
        end
    end
    if self.youRow.target then
        table.insert(rows, self.youRow)
    end
    if #rows == 0 then
        return
    end
    local start = os.clock()
    self.counter = RunService.Heartbeat:Connect(function()
        local u = math.clamp((os.clock() - start) / COUNT_TIME, 0, 1)
        local e = 1 - (1 - u) ^ 3
        for _, row in rows do
            if row.target then
                row.value.Text = Format.Value(kind, u >= 1 and row.target or math.floor(row.target * e))
            end
        end
        if u >= 1 and self.counter then
            self.counter:Disconnect()
            self.counter = nil
        end
    end)
end

---------------------------------------------------------------- public
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

    local snap = state.snapshot
    local entries = snap and snap.entries or {}
    local count = math.min(#entries, Config.MaxRows)
    -- count up once per tab + scope, the first time it has rows
    local animate = count > 0 and self.counted ~= key
    if animate then
        self.counted = key
    end
    for i = 1, count do
        local row = self.rows[i] or self:_row(i)
        local e = entries[i]
        fillRow(row, e, stat.Kind, e.u == state.localUserId, i % 2 == 0, animate and 0 or nil)
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
    local status = snap and snap.status
    if count > 0 then
        self:_setStatus(nil)
    elseif state.phase == "error" and not snap then
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
    local you = snap and snap.you
    local mine =
        { r = you and you.r, u = state.localUserId, n = state.localName, d = state.localDisplayName, v = you and you.v }
    fillRow(self.youRow, mine, stat.Kind, false, false, animate and mine.v and 0 or nil)
    self.youLabel.Text = "YOUR RANK  ·  " .. (state.scope == "Server" and "THIS SERVER" or "GLOBAL")
    local note
    if mine.r and mine.r > 1 and entries[mine.r - 1] and entries[mine.r - 1].v and mine.v then
        local ahead = entries[mine.r - 1]
        note = Format.Value(stat.Kind, math.max(0, ahead.v - mine.v))
            .. " to pass "
            .. (ahead.d or ahead.n or "the next player")
    elseif mine.r == 1 then
        note = "You lead " .. (state.scope == "Server" and "this server" or "everyone")
    elseif not snap or status == "loading" then
        note = "Loading"
    elseif status == "unavailable" then
        note = "Global unavailable"
    elseif state.scope == "Global" and mine.v and mine.v > 0 then
        note = (snap.total or 0) >= (snap.depth or 100)
                and ("Outside the top " .. (snap.depth or 100) .. "  ·  keep climbing")
            or "Not on the global board yet"
    else
        note = "Not ranked yet"
    end
    self.youRow.user.Text = note
    self.youRow.rank.Text = mine.r and ("#" .. mine.r) or "—"
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
    for _, tw in self.tweens do
        tw:Cancel()
    end
    if self.root then
        self.root:Destroy()
    end
    self.root = nil
end

return View
