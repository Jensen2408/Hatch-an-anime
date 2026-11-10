--[[ ReplicatedStorage.EventUI (ModuleScript, client) - 2026-11-10
One family for every event HUD: the announcement banner, the boss health bar, the live event pills, the event timer
rows and the big pop texts ("STUNNED!"). They share shapes, the font, the text outline and the motion, so a boss,
the rapids, an egg rush and the arena all read as the same game. Built on ReplicatedStorage.FolkStudUI (M.H helpers).

  EventUI.announce({ title, text, theme | color, icon, seconds, sound })   queued banner, one at a time
  EventUI.pill(parent, opts)      icon + name + countdown slab (live event pills, timer rows, warn strips)
  EventUI.chip(parent, opts)      small slab with one centred text (timer chip)
  EventUI.bar(parent, opts)       health bar: white track, black outline, gradient fill + gloss, damage ghost, shake
  EventUI.toast(gui, yScale)      big centred pop text
  EventUI.label(parent, props)    text in the house style (FredokaOne, black bevel outline 3.7)
  EventUI.stackSet / stackTop     the shared top-centre column: pills -> staff banner -> boss -> arena -> banner,
                                  so none of them ever covers another
Look only: it reads no remotes and writes no attributes. Reduced motion (GuiService.ReducedMotionEnabled or the
player's ReducedMotion attribute) turns every pop, pulse, shake and sweep off. ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local TextService = game:GetService("TextService")

local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local hex = H.hex
local WHITE, BLACK = H.WHITE, H.BLACK

local EventUI = {}
EventUI.FONT = M.FONT
EventUI.STROKE = 3.7
EventUI.HOT = hex("FFE600") -- countdown in its last seconds, top damage, highlights
EventUI.LIVE = hex("8CF56A")
EventUI.GAP = 8 -- between the stacked top-centre pieces, in pixels

local ICON = {
    boss = "rbxassetid://79711631278660",
    sword = "rbxassetid://79302902202299",
    fire = "rbxassetid://106124079616526",
    moon = "rbxassetid://112411971879268",
    cash = "rbxassetid://136807180106184",
    bolt = "rbxassetid://115412194685542",
    clock = "rbxassetid://123064760828653",
    egg = "rbxassetid://72466978369063",
    eggGold = "rbxassetid://132296043153963",
    trophy = "rbxassetid://133620970719071",
    star = M.ART.star,
    sparkle = M.ART.sparkle,
    gift = M.ART.gift,
    wave = "🌊", -- no wave art uploaded yet: a glyph works as an icon too
}
EventUI.ICON = ICON

-- { top, bottom } face colours (vivid only) + the icon that goes with the event
EventUI.THEMES = {
    boss = { top = hex("FF8A1F"), bottom = hex("E50A1F"), icon = ICON.boss }, -- red / orange
    tide = { top = hex("2FE0FF"), bottom = hex("0283FB"), icon = ICON.wave }, -- blue / cyan
    eggrush = { top = hex("FCC505"), bottom = hex("F99001"), icon = ICON.eggGold }, -- gold
    night = { top = hex("6A5BFF"), bottom = hex("3A1FD1"), icon = ICON.moon }, -- indigo
    fail = { top = hex("9C31FB"), bottom = hex("6C0FE3"), icon = ICON.boss }, -- purple: escaped / lost
    win = { top = hex("A6F51E"), bottom = hex("2FC92B"), icon = ICON.trophy }, -- lime
    arena = { top = hex("35A8FF"), bottom = hex("1B6BF5"), icon = ICON.sword },
    volcano = { top = hex("FFC43D"), bottom = hex("F27A00"), icon = ICON.fire },
    meteor = { top = hex("FA2DB0"), bottom = hex("9C31FB"), icon = ICON.fire },
    cash = { top = hex("12D67A"), bottom = hex("03AE59"), icon = ICON.cash },
    info = { top = hex("2FB8FF"), bottom = hex("005DF9"), icon = ICON.star },
    alert = { top = hex("FC253A"), bottom = hex("E50A1F"), icon = ICON.star },
    pink = { top = hex("FA2DB0"), bottom = hex("F8108E"), icon = ICON.sparkle },
}
local COLOR_THEME = { red = "alert", blue = "info", tide = "tide", green = "cash", gold = "eggrush", pink = "pink", purple = "fail" }

function EventUI.theme(theme)
    if type(theme) == "table" then
        return theme
    end
    return EventUI.THEMES[theme] or EventUI.THEMES.info
end

-- the theme of a server announcement ({ title, text, color }): the title decides first, then the colour
function EventUI.themeFor(data)
    if data.theme then
        return EventUI.theme(data.theme)
    end
    local title = string.upper(tostring(data.title or ""))
    if title:find("ESCAPED", 1, true) or title:find("FAILED", 1, true) then
        return EventUI.THEMES.fail
    elseif title:find("DEFEATED", 1, true) or title:find("YOU WIN", 1, true) then
        return EventUI.THEMES.win
    elseif title:find("BOSS", 1, true) or title:find("RIVER STIRS", 1, true) then
        return EventUI.THEMES.boss
    elseif data.color == "tide" or title:find("RAPIDS", 1, true) or title:find("TIDE", 1, true) then
        return EventUI.THEMES.tide
    elseif title:find("EGG RUSH", 1, true) or title:find("GOLDEN", 1, true) then
        return EventUI.THEMES.eggrush
    elseif title:find("NIGHT", 1, true) then
        return EventUI.THEMES.night
    elseif title:find("ARENA", 1, true) then
        return EventUI.THEMES.arena
    elseif title:find("VOLCANO", 1, true) then
        return EventUI.THEMES.volcano
    elseif title:find("METEOR", 1, true) then
        return EventUI.THEMES.meteor
    end
    return EventUI.THEMES[COLOR_THEME[data.color] or "info"]
end

function EventUI.reduced()
    if GuiService.ReducedMotionEnabled then
        return true
    end
    local player = Players.LocalPlayer
    return player ~= nil and player:GetAttribute("ReducedMotion") == true
end

-- "1:05", "1:02:03"; pad = true gives "01:05"
function EventUI.clock(seconds, pad)
    seconds = math.max(0, math.ceil(seconds))
    if seconds >= 3600 then
        return string.format("%d:%02d:%02d", seconds // 3600, seconds // 60 % 60, seconds % 60)
    end
    return string.format(pad and "%02d:%02d" or "%d:%02d", seconds // 60, seconds % 60)
end

-- top-centre pieces: full size on desktop, shrinking so they never pass 92% of the width or crowd a short screen
function EventUI.fitTop(screenSize, designWidth)
    if screenSize.X < 10 then
        return 1
    end
    return math.clamp(math.min(screenSize.X * 0.92 / designWidth, screenSize.Y / 560), 0.5, 1)
end

local function measure(text, size)
    local ok, bounds = pcall(TextService.GetTextSize, TextService, text, size, Enum.Font.FredokaOne, Vector2.new(4000, size * 2))
    if ok and bounds then
        return bounds.X + 4
    end
    return #text * size * 0.6 + 4
end
EventUI.measure = measure

-- the biggest text size from max down to min at which text fits in width
local function fitSize(text, max, min, width)
    local wide = measure(text, max)
    if wide <= width then
        return max
    end
    return math.max(min, math.floor(max * width / wide))
end

-- ===== text =====
local drops = setmetatable({}, { __mode = "k" }) -- [label] = its drop shadow label
-- House text: FredokaOne, white unless told otherwise, black bevel outline. Drop = true adds the hard shadow that
-- only text of 30px and up gets. Change the words with EventUI.setText so the shadow follows.
function EventUI.label(parent, props)
    local drop = props.Drop
    local base = {
        Name = "Label",
        BackgroundTransparency = 1,
        FontFace = M.FONT,
        Text = "",
        TextSize = 20,
        TextColor3 = WHITE,
        ZIndex = 5,
    }
    for key, value in props do
        if key ~= "Drop" then
            base[key] = value
        end
    end
    local shadow
    if drop and base.TextSize >= 30 then
        shadow = H.new("TextLabel", base, parent)
        shadow.Name = base.Name .. "Drop"
        shadow.TextColor3 = BLACK
        shadow.Position = base.Position and (base.Position + UDim2.fromOffset(0, 4)) or UDim2.fromOffset(0, 4)
        H.new("UIStroke", { Name = "UIStroke", Thickness = EventUI.STROKE, Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, shadow)
    end
    local label = H.new("TextLabel", base, parent)
    H.new("UIStroke", { Name = "UIStroke", Thickness = EventUI.STROKE, Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, label)
    drops[label] = shadow
    return label
end
function EventUI.setText(label, text, size)
    local shadow = drops[label]
    if label.Text ~= text then
        label.Text = text
        if shadow then
            shadow.Text = text
        end
    end
    if size and label.TextSize ~= size then
        label.TextSize = size
        if shadow then
            shadow.TextSize = size
        end
    end
end
-- fades a label, its outline and its shadow together (0 = solid, 1 = gone)
local function setFade(label, alpha)
    for _, item in { label, drops[label] } do
        item.TextTransparency = alpha
        local stroke = item:FindFirstChild("UIStroke")
        if stroke then
            stroke.Transparency = alpha
        end
    end
end

-- ===== icon sticker =====
-- An image id (black ink copies underneath, like H.sticker but scaled to the icon) or a glyph such as an emoji.
-- Returns a zero-size holder centred on cx, cy with its own UIScale "Pop".
function EventUI.icon(parent, name, icon, cx, cy, size, z)
    local holder = H.new("Frame", { Name = name, BackgroundTransparency = 1, Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(0, 0), ZIndex = z }, parent)
    H.new("UIScale", { Name = "Pop" }, holder)
    if type(icon) == "table" then
        icon = icon.id
    end
    if type(icon) == "string" and icon:sub(1, 8) == "rbxasset" then
        local d = math.max(2, math.floor(size * 0.05 + 0.5))
        for _, offset in { { 0, d * 2, 0.5 }, { -d, 0, 0 }, { d, 0, 0 }, { 0, -d, 0 }, { 0, d, 0 } } do
            local ink = H.art(holder, "Ink", icon, offset[1], offset[2], size, z, offset[3])
            ink.ImageColor3 = BLACK
        end
        H.art(holder, "Art", icon, 0, 0, size, z)
    else
        EventUI.label(holder, {
            Name = "Glyph",
            Text = tostring(icon or ""),
            TextSize = math.floor(size * 0.78),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.fromOffset(size, size),
            ZIndex = z,
        })
    end
    return holder
end

local BACK_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
-- pops a UIScale in with a little overshoot (from 'from' to 1); snaps when motion is reduced
function EventUI.popIn(scale, from, info)
    if EventUI.reduced() then
        scale.Scale = 1
        return nil
    end
    scale.Scale = from or 0.6
    local tween = TweenService:Create(scale, info or BACK_OUT, { Scale = 1 })
    tween:Play()
    return tween
end

-- eases a number toward a moving target between calls: local y = glide(targetY). Snaps on the first call,
-- after a pause and when motion is reduced.
function EventUI.glider(rate)
    local value, last = nil, 0
    return function(target, snap)
        local now = os.clock()
        if value == nil or snap or now - last > 0.5 or EventUI.reduced() then
            value = target
        else
            value += (target - value) * (1 - math.exp(-(now - last) * (rate or 14)))
        end
        last = now
        return value
    end
end

-- ===== slab pieces =====
local function slab(parent, name, x, y, w, h, top, bottom, z, inkWidth)
    local face = H.new("Frame", { Name = name, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z }, parent)
    H.round(face, 14)
    H.grad(face, top, bottom)
    H.ink(face, inkWidth or 3)
    H.studs(face, Vector2.new(40, 40), 0.82, 14, z)
    H.gloss(face, 14, z + 1)
    return face
end

local PULSE = TweenInfo.new(0.42, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

--[[ A read-only slab (flat: no lip): icon + name + countdown, the countdown right-aligned in a fixed column so the
name never jumps while the clock ticks.
opts: name, top, bottom (or theme), icon, height (36), width (fixed; nil = hugs its text), nameSize (19),
      timeSize (19), timeWidth, iconSize, breakout (the icon hangs over the left end), shadow, pad, order, z
Returns { frame, slab, nameLabel, timeLabel, iconPop, pop, setName, setTime, setUrgent, popIn, popOut, destroy } ]]
function EventUI.pill(parent, opts)
    local theme = opts.theme and EventUI.theme(opts.theme) or nil
    local top, bottom = opts.top or (theme and theme.top) or WHITE, opts.bottom or (theme and theme.bottom) or WHITE
    local icon = opts.icon or (theme and theme.icon) or nil
    local h = opts.height or 36
    local z = opts.z or 2
    local pad = opts.pad or 12
    local nameSize, timeSize = opts.nameSize or 19, opts.timeSize or 19
    local baseTimeW = opts.timeWidth or measure("00:00", timeSize)
    local iconSize = icon and (opts.iconSize or (h - 10)) or 0
    local inset = (icon and opts.breakout) and math.floor(iconSize * 0.45) or 0
    local iconX = opts.breakout and iconSize / 2 or (pad - 2 + iconSize / 2)
    local textX = icon and (iconX + iconSize / 2 + 6) or pad

    local self = {}
    local holder = H.new("Frame", { Name = opts.name or "Pill", BackgroundTransparency = 1, Size = UDim2.fromOffset(opts.width or 120, h), LayoutOrder = opts.order or 0, ZIndex = z }, parent)
    local body = H.new("Frame", { Name = "Body", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = z }, holder)
    local pop = H.new("UIScale", { Name = "Pop" }, body)
    local shadow = opts.shadow and H.shadow(body, "Slab", inset, 0, 10, h, 14, z - 1) or nil
    local face = slab(body, "Slab", inset, 0, 10, h, top, bottom, z)
    local nameLabel = EventUI.label(body, {
        Name = "Name",
        TextSize = nameSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(textX, 0),
        Size = UDim2.fromOffset(10, h - 2),
        ZIndex = z + 3,
    })
    local timeLabel = EventUI.label(body, {
        Name = "Time",
        TextSize = timeSize,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -pad, 0, 0),
        Size = UDim2.fromOffset(baseTimeW, h - 2),
        ZIndex = z + 3,
    })
    local iconHolder = icon and EventUI.icon(body, "Icon", icon, iconX, h / 2 - (opts.breakout and 2 or 1), iconSize, z + 4) or nil

    local nameText, timeText, timeColor, urgent, pulse = "", nil, WHITE, false, nil
    local function layout()
        local timeW = timeText and math.max(baseTimeW, measure(timeText, timeSize)) or 0
        local gap = timeText and 8 or 0
        local width = opts.width
        local nameW
        if width then
            nameW = math.max(10, width - textX - gap - timeW - pad)
            nameLabel.TextSize = fitSize(nameText, nameSize, 11, nameW)
        else
            nameW = measure(nameText, nameSize)
            width = math.ceil(textX + nameW + gap + timeW + pad)
            holder.Size = UDim2.fromOffset(width, h)
        end
        nameLabel.Size = UDim2.fromOffset(nameW, h - 2)
        timeLabel.Size = UDim2.fromOffset(math.max(timeW, 1), h - 2)
        face.Size = UDim2.fromOffset(width - inset, h)
        if shadow then
            shadow.Size = UDim2.fromOffset(width - inset, h)
        end
    end
    function self.setName(text)
        if text ~= nameText then
            nameText = text
            nameLabel.Text = text
            layout()
        end
    end
    -- text = nil hides the countdown column
    function self.setTime(text, color)
        if text ~= timeText then
            local reflow = (text == nil) ~= (timeText == nil) or (text ~= nil and #text ~= #(timeText or ""))
            timeText = text
            timeLabel.Text = text or ""
            timeLabel.Visible = text ~= nil
            if reflow then
                layout()
            end
        end
        timeColor = color or WHITE
        timeLabel.TextColor3 = urgent and EventUI.HOT or timeColor
    end
    -- the last seconds: hot countdown and a soft pulse
    function self.setUrgent(on)
        on = on == true
        if on == urgent then
            return
        end
        urgent = on
        timeLabel.TextColor3 = on and EventUI.HOT or timeColor
        if pulse then
            pulse:Cancel()
            pulse = nil
        end
        if on and not EventUI.reduced() then
            pop.Scale = 1
            pulse = TweenService:Create(pop, PULSE, { Scale = 1.07 })
            pulse:Play()
        else
            pop.Scale = 1
        end
    end
    function self.popIn()
        if not urgent then
            EventUI.popIn(pop, 0.5)
        end
    end
    local dead = false
    function self.destroy()
        if dead then
            return
        end
        dead = true
        if pulse then
            pulse:Cancel()
            pulse = nil
        end
        holder:Destroy()
    end
    function self.popOut()
        if dead then
            return
        end
        if pulse then
            pulse:Cancel()
            pulse = nil
        end
        if EventUI.reduced() then
            self.destroy()
            return
        end
        local tween = TweenService:Create(pop, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
        tween.Completed:Once(self.destroy)
        tween:Play()
    end
    self.frame, self.slab, self.nameLabel, self.timeLabel, self.pop = holder, face, nameLabel, timeLabel, pop
    self.iconPop = iconHolder and iconHolder:FindFirstChild("Pop") or nil
    layout()
    return self
end

-- A small slab with one centred text: the timer chip. opts: name, theme | top, bottom, width, height, textSize, z
-- Returns { frame, label, set(text, urgent) }
function EventUI.chip(parent, opts)
    local theme = EventUI.theme(opts.theme)
    local w, h, z = opts.width or 92, opts.height or 30, opts.z or 2
    local holder = H.new("Frame", { Name = opts.name or "Chip", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), ZIndex = z }, parent)
    slab(holder, "Slab", 0, 0, w, h, opts.top or theme.top, opts.bottom or theme.bottom, z)
    local label = EventUI.label(holder, { Name = "Text", TextSize = opts.textSize or 20, Size = UDim2.fromOffset(w, h - 2), ZIndex = z + 3 })
    local self = { frame = holder, label = label }
    function self.set(text, urgent)
        if label.Text ~= text then
            label.Text = text
        end
        label.TextColor3 = urgent and EventUI.HOT or WHITE
    end
    return self
end

--[[ Health bar. White track with a black outline, a vivid gradient fill with gloss, a hot "ghost" that lags behind
the fill after damage, the numbers in the middle and a small shake + flash when the value drops.
opts: name, width, height (30), top, bottom (fill colours), textSize (18), z
Call bar.set(fraction, text) every frame while it shows (it does its own easing); bar.reset(fraction) snaps. ]]
function EventUI.bar(parent, opts)
    local w, h, z = opts.width or 520, opts.height or 30, opts.z or 2
    local holder = H.new("Frame", { Name = opts.name or "Bar", BackgroundTransparency = 1, Size = UDim2.fromOffset(w, h), ZIndex = z }, parent)
    local body = H.new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = z }, holder)
    local track = H.rect(body, "Track", 0, 0, w, h, 14, z, WHITE)
    track.ClipsDescendants = true
    H.ink(track, 4)
    local ghost = H.rect(track, "Ghost", 0, 0, w, h, 14, z + 1, EventUI.HOT)
    local fill = H.rect(track, "Fill", 0, 0, w, h, 14, z + 2, WHITE)
    local fillGradient = H.grad(fill, opts.top or hex("FF5A3D"), opts.bottom or hex("E50A1F"))
    H.gloss(fill, 14, z + 3)
    local flash = H.rect(track, "Flash", 0, 0, w, h, 14, z + 3, WHITE)
    flash.BackgroundTransparency = 1
    local label = EventUI.label(body, { Name = "Text", TextSize = opts.textSize or 18, Size = UDim2.fromOffset(w, h - 1), ZIndex = z + 5 })

    local self = { frame = holder, label = label, fill = fill }
    local target, shown, lag = 1, 1, 1
    local last, holdUntil, shakeUntil = os.clock(), 0, 0
    local function apply()
        fill.Size = UDim2.new(shown, 0, 1, 0)
        fill.Visible = shown > 0.001
        ghost.Size = UDim2.new(lag, 0, 1, 0)
        ghost.Visible = lag > shown + 0.001
    end
    function self.reset(fraction)
        fraction = math.clamp(fraction, 0, 1)
        target, shown, lag = fraction, fraction, fraction
        last, holdUntil, shakeUntil = os.clock(), 0, 0
        body.Position = UDim2.fromOffset(0, 0)
        flash.BackgroundTransparency = 1
        apply()
    end
    function self.setColors(top, bottom)
        fillGradient.Color = ColorSequence.new(top, bottom)
    end
    function self.set(fraction, text)
        fraction = math.clamp(fraction, 0, 1)
        local now = os.clock()
        local dt = math.min(now - last, 0.1)
        last = now
        local calm = EventUI.reduced()
        if fraction < target - 0.0005 then -- damage: the ghost waits, then drains
            holdUntil = now + 0.35
            if not calm then
                shakeUntil = now + 0.22
                flash.BackgroundTransparency = 0.35
            end
        end
        target = fraction
        if calm then
            shown, lag = target, target
        else
            shown += (target - shown) * (1 - math.exp(-dt * 20))
            if math.abs(target - shown) < 0.001 then
                shown = target
            end
            if lag < shown then
                lag = shown
            elseif now >= holdUntil then
                lag = math.max(shown, lag - dt * 0.55)
            end
        end
        apply()
        if flash.BackgroundTransparency < 1 then
            flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 4)
        end
        if now < shakeUntil then
            local k = (shakeUntil - now) / 0.22
            body.Position = UDim2.fromOffset(math.sin(now * 90) * 4 * k, math.cos(now * 70) * 2 * k)
        elseif body.Position.X.Offset ~= 0 or body.Position.Y.Offset ~= 0 then
            body.Position = UDim2.fromOffset(0, 0)
        end
        if text and label.Text ~= text then
            label.Text = text
        end
    end
    apply()
    return self
end

--[[ A big centred pop text ("STUNNED!", "KNOCKOUT!"). gui: the ScreenGui it lives in, yScale: how far down.
Returns { show(text, color?, seconds?), hide() }. 34px and up, so it carries the hard drop shadow. ]]
function EventUI.toast(gui, yScale, opts)
    opts = opts or {}
    local size = opts.textSize or 38
    local holder = H.new("Frame", { Name = opts.name or "Toast", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, yScale),
        Size = UDim2.fromOffset(640, size * 2.6), Visible = false, ZIndex = opts.z or 30 }, gui)
    local fit = H.new("UIScale", { Name = "Fit" }, holder)
    local stage = H.new("Frame", { Name = "Stage", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = opts.z or 30 }, holder)
    local pop = H.new("UIScale", { Name = "Pop" }, stage)
    local label = EventUI.label(stage, { Name = "Text", TextSize = size, TextWrapped = true, Size = UDim2.fromScale(1, 1), ZIndex = (opts.z or 30) + 1, Drop = true })
    local token, tweens = 0, {}
    local function stop()
        for _, tween in tweens do
            tween:Cancel()
        end
        table.clear(tweens)
    end
    local self = {}
    function self.hide()
        token += 1
        stop()
        holder.Visible = false
    end
    function self.show(text, color, seconds)
        token += 1
        local mine = token
        stop()
        fit.Scale = EventUI.fitTop(gui.AbsoluteSize, 680)
        EventUI.setText(label, text)
        label.TextColor3 = color or WHITE
        setFade(label, 0)
        holder.Visible = true
        local popTween = EventUI.popIn(pop, 0.4, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
        if popTween then
            table.insert(tweens, popTween)
        end
        task.delay(seconds or 2.5, function()
            if mine ~= token then
                return
            end
            if EventUI.reduced() then
                holder.Visible = false
                return
            end
            local fade = TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 })
            table.insert(tweens, fade)
            for _, item in { label:FindFirstChild("UIStroke"), drops[label], drops[label] and drops[label]:FindFirstChild("UIStroke") } do
                local goal = item:IsA("UIStroke") and { Transparency = 1 } or { TextTransparency = 1 }
                local tween = TweenService:Create(item, TweenInfo.new(0.4), goal)
                table.insert(tweens, tween)
                tween:Play()
            end
            fade.Completed:Once(function(state)
                if mine == token and state == Enum.PlaybackState.Completed then
                    holder.Visible = false
                end
            end)
            fade:Play()
        end)
    end
    return self
end

-- ===== the shared top-centre column =====
-- Heights and tops are in AbsolutePosition pixels, so pieces in different ScreenGuis (with or without the topbar
-- inset) line up. A piece calls stackSet(name, height) every time its height changes (0 = hidden) and places itself
-- at stackTop(name) - originY(itsGui).
local ORDER = { "pills", "staff", "boss", "arena", "banner" }
local STACK_BASE = 14
local slots = {}
function EventUI.stackSet(name, height, top)
    local slot = slots[name]
    if not slot then
        slot = {}
        slots[name] = slot
    end
    slot.height = math.max(0, height or 0)
    slot.top = top
end
-- the bottom edge of a staff / server announcement banner that is on screen right now (drawn by StaffAnnouncements)
local function staffBottom()
    local player = Players.LocalPlayer
    local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
    local gui = playerGui and playerGui:FindFirstChild("StaffAnnouncements")
    if not gui then
        return nil
    end
    local bottom = nil
    for _, child in gui:GetChildren() do
        if child:IsA("GuiObject") and child.Visible then
            local y, height = child.AbsolutePosition.Y, child.AbsoluteSize.Y
            if height > 0 and height < 400 and y + height > 8 and y < 300 then
                bottom = math.max(bottom or 0, y + height)
            end
        end
    end
    return bottom
end
function EventUI.stackTop(name)
    local y = STACK_BASE
    for _, key in ORDER do
        if key == name then
            break
        end
        if key == "staff" then
            local bottom = staffBottom()
            if bottom then
                y = math.max(y, bottom + EventUI.GAP)
            end
        else
            local slot = slots[key]
            if slot then
                if slot.top then
                    y = math.max(y, slot.top)
                end
                if slot.height > 0 then
                    y = math.max(y, (slot.top or y) + slot.height + EventUI.GAP)
                end
            end
        end
    end
    return y
end
-- where a ScreenGui's own 0 sits in AbsolutePosition pixels
function EventUI.originY(gui)
    local probe = gui:FindFirstChild("EventUIOrigin")
    if not probe then
        probe = H.new("Frame", { Name = "EventUIOrigin", BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1) }, gui)
    end
    return probe.AbsolutePosition.Y
end

-- ===== announcement banner =====
local BANNER_W, BANNER_H = 560, 84
local banner = { queue = {}, busy = false, gui = nil, current = nil }

local function bannerGui()
    if banner.gui and banner.gui.Parent then
        return banner.gui
    end
    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    banner.gui = H.new("ScreenGui", { Name = "EventBanners", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 58, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
    return banner.gui
end

local function playBanner(data)
    local gui = bannerGui()
    local theme = EventUI.themeFor(data)
    local icon = data.icon or theme.icon
    local title = string.upper(tostring(data.title or ""))
    local text = tostring(data.text or "")
    local calm = EventUI.reduced()
    local W, HT = BANNER_W, BANNER_H

    local holder = H.new("Frame", { Name = "Banner", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -400), Size = UDim2.fromOffset(W, HT) }, gui)
    local fit = H.new("UIScale", { Name = "Fit" }, holder)
    local stage = H.new("Frame", { Name = "Stage", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1) }, holder)
    local pop = H.new("UIScale", { Name = "Pop" }, stage)
    H.shadow(stage, "Card", 0, 0, W, HT, 18, 1)
    local card = H.rect(stage, "Card", 0, 0, W, HT, 18, 2, WHITE)
    H.grad(card, theme.top, theme.bottom)
    H.ink(card, 4)
    H.studs(card, Vector2.new(48, 48), 0.8, 18, 2)
    H.gloss(card, 18, 3)
    -- the thin shine that sweeps across once
    local sweep = H.rect(card, "Sweep", 0, 0, W, HT, 18, 3, WHITE)
    sweep.Size = UDim2.fromScale(1, 1)
    local sweepGradient = H.new("UIGradient", {
        Rotation = 25,
        Offset = Vector2.new(-1, 0),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.42, 1),
            NumberSequenceKeypoint.new(0.5, 0.25),
            NumberSequenceKeypoint.new(0.58, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, sweep)
    local iconHolder = EventUI.icon(stage, "Icon", icon, 46, HT / 2 - 2, 78, 6)
    local iconPop = iconHolder:FindFirstChild("Pop")
    local textX = 96
    local textW = W - textX - 18
    local hasText = text ~= ""
    local titleSize = fitSize(title, 34, 20, textW)
    EventUI.label(stage, {
        Name = "Title",
        Text = title,
        TextSize = titleSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(textX, hasText and 8 or (HT - 44) / 2),
        Size = UDim2.fromOffset(textW, 40),
        ZIndex = 7,
        Drop = true,
    })
    if hasText then
        EventUI.label(stage, {
            Name = "Subtitle",
            Text = text,
            TextSize = fitSize(text, 19, 14, textW),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(textX, 48),
            Size = UDim2.fromOffset(textW, 26),
            ZIndex = 7,
        })
    end

    local glide = EventUI.glider(16)
    local function place()
        local size = gui.AbsoluteSize
        local scale = EventUI.fitTop(size, W + 30)
        fit.Scale = scale
        -- under whatever else is stacked at the top, but never lower than the upper part of the screen
        local top = EventUI.stackTop("banner") - EventUI.originY(gui)
        top = math.min(top, math.max(8, size.Y * 0.5 - HT * scale))
        holder.Position = UDim2.new(0.5, 0, 0, glide(top))
    end
    place()
    local follow = RunService.RenderStepped:Connect(place)
    local tweens = {}
    local function play(object, info, goal)
        local tween = TweenService:Create(object, info, goal)
        table.insert(tweens, tween)
        tween:Play()
        return tween
    end
    if data.sound then
        task.spawn(function()
            local ok, UISound = pcall(require, ReplicatedStorage:FindFirstChild("UISound"))
            if ok and UISound and UISound.Play then
                pcall(UISound.Play, data.sound)
            end
        end)
    end
    if not calm then
        pop.Scale = 0.5
        stage.Position = UDim2.new(0.5, 0, 0.5, -50)
        iconPop.Scale = 0
        play(pop, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
        play(stage, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) })
        play(iconPop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.14), { Scale = 1 })
        play(sweepGradient, TweenInfo.new(0.75, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, 0.4), { Offset = Vector2.new(1, 0) })
    end
    task.wait(math.clamp(tonumber(data.seconds) or 4.5, 1.5, 12))
    if not calm and holder.Parent then
        play(stage, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0.5, -36) })
        play(pop, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
        task.wait(0.28)
    end
    follow:Disconnect()
    for _, tween in tweens do
        tween:Cancel()
    end
    holder:Destroy()
end

local function runBanners()
    if banner.busy then
        return
    end
    banner.busy = true
    task.spawn(function()
        while #banner.queue > 0 do
            local data = table.remove(banner.queue, 1)
            banner.current = data
            local ok, problem = pcall(playBanner, data)
            if not ok then
                warn("[EventUI] banner failed: " .. tostring(problem))
                local gui = banner.gui
                local stuck = gui and gui:FindFirstChild("Banner")
                if stuck then
                    stuck:Destroy()
                end
            end
            banner.current = nil
            task.wait(0.12)
        end
        banner.busy = false
    end)
end

--[[ Queues a banner: { title, text, theme = "boss" | "tide" | "eggrush" | "night" | "fail" | "win" | ...,
color = the server announcement colour (used when there is no theme), icon, seconds, sound = UISound name }.
The same shape as the OwnerPanel.Announcement payload, so that remote's data can be passed straight in.
Banners never overlap: one shows at a time, the rest wait (at most 4; a repeat of the one showing is dropped). ]]
function EventUI.announce(data)
    if type(data) ~= "table" or not Players.LocalPlayer then
        return
    end
    local function same(other)
        return other ~= nil and other.title == data.title and other.text == data.text
    end
    if same(banner.current) or same(banner.queue[#banner.queue]) then
        return
    end
    if #banner.queue >= 4 then
        table.remove(banner.queue, 1)
    end
    table.insert(banner.queue, data)
    runBanners()
end

return EventUI
