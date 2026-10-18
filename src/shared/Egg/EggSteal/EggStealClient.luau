--[[ ReplicatedStorage.EggSteal.EggStealClient  (ModuleScript, CLIENT ONLY)
Pure presentation. The client never tells the server anything; it only reacts to the server's
"Start" / "Alert" / "Pos" / "End" messages. If this script is deleted the steal system still works.

Thief:   top-centre card (EGG STOLEN! → STOLEN EGG), alarm, red edge pulse, "YOUR BASE 82m" waypoint,
         EGG SECURED! celebration → the egg flies into the backpack bar.
Owner:   top-centre card (YOUR EGG IS BEING STOLEN!), warning tones, waypoint to the egg.

Performance: one RenderStepped connection exists only while a steal is on screen. It moves two markers,
rotates two arrows, spins the egg icons and sets one CanvasGroup transparency. Texts update only when the
rounded distance changes. Sounds are 5 pre-loaded instances. Particles are short tweens that clean up.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")

local Config = require(script.Parent:WaitForChild("EggStealConfig"))
local K, UI, A, S = Config.Colors, Config.UI, Config.Alarm, Config.Sounds
local player = Players.LocalPlayer

local Client = {}
local Banner = require(ReplicatedStorage:WaitForChild("StolenEggBanner"))

local run = { thief = nil, victim = nil }
local danger = { level = 0, target = 0, phase = 0, since = 0 }
local sounds = {}
local gui, stack, stackScale, vignette, tint, markerLayer, fx
local stepConn
local started = false

-- ═══════════════════════════ small helpers ═══════════════════════════
local EASE_OUT, EASE_IN, EASE_IO = Enum.EasingDirection.Out, Enum.EasingDirection.In, Enum.EasingDirection.InOut

local function new(class, props)
    local inst = Instance.new(class)
    local parent
    for k, v in props do
        if k == "Parent" then
            parent = v
        else
            inst[k] = v
        end
    end
    inst.Parent = parent
    return inst
end

local function tw(inst, time, props, style, dir)
    local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or EASE_OUT), props)
    t:Play()
    return t
end

local function reduced()
    return player:GetAttribute("ReducedMotion") == true
end
local function lerp(a, b, t)
    return a + (b - a) * t
end

local function commas(n)
    local s = tostring(math.floor((tonumber(n) or 0) + 0.5))
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

-- ═══════════════════════════ sound ═══════════════════════════
local function play(name, volume, speed)
    local s = sounds[name]
    if not s then
        return
    end
    s.Volume = volume * A.Volume
    s.PlaybackSpeed = speed or 1
    s.TimePosition = 0
    s:Play()
end

local function twoTone(volume)
    task.spawn(function()
        for _ = 1, 2 do
            play("Beep", volume, 1.0)
            task.wait(0.22)
            play("Beep", volume, 1.5)
            task.wait(0.3)
        end
    end)
end

-- ═══════════════════════════ UI building blocks (same look as EggUIStyle) ═══════════════════════════
local function makePanel(parent, color)
    local frame = new("Frame", {
        Name = "Panel",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = parent,
    })
    new("UICorner", { CornerRadius = UDim.new(0, 16), Parent = frame })
    new("UIStroke", { Thickness = 3, Color = K.Outline, Parent = frame })
    new("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 212)),
        Parent = frame,
    })
    -- low-contrast egg silhouettes, the same motif as the other panels
    for row = 0, 2 do
        for col = 0, 10 do
            local dot = new("Frame", {
                Name = "EggPattern",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(col * 0.1 + (row % 2) * 0.05, row * 0.4 + 0.1),
                Size = UDim2.fromScale(0.045, 0.3),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.9,
                BorderSizePixel = 0,
                Parent = frame,
            })
            new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dot })
        end
    end
    return frame
end

local function makeText(parent, props)
    props.BackgroundTransparency = 1
    props.Font = props.Font or Enum.Font.Cartoon
    props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    props.ZIndex = props.ZIndex or 4
    props.Parent = parent
    local label = new("TextLabel", props)
    local stroke = new("UIStroke", { Color = K.Outline, Thickness = 2, Parent = label })
    return label, stroke
end

local function makeEggViewport(parent, eggType)
    local visuals = ReplicatedStorage:FindFirstChild("EggVisuals")
    local template = visuals and visuals:FindFirstChild(eggType)
    if template and template:IsA("BasePart") then
        local vp = new("ViewportFrame", {
            Size = UDim2.fromScale(0.9, 0.9),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            BackgroundTransparency = 1,
            Ambient = Color3.fromRGB(175, 175, 190),
            LightColor = Color3.new(1, 1, 1),
            LightDirection = Vector3.new(-0.6, -1, -0.8),
            ZIndex = 4,
            Parent = parent,
        })
        local cam = new("Camera", { FieldOfView = 30, Parent = vp })
        vp.CurrentCamera = cam
        local egg = template:Clone()
        for _, d in egg:GetDescendants() do
            if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
                d:Destroy()
            end
        end
        egg.Size *= 4 / egg.Size.Y
        egg.Anchored = true
        egg.CFrame = CFrame.new()
        egg.Parent = vp
        cam.CFrame = CFrame.lookAt(Vector3.new(0, 0.25, 9.2), Vector3.zero)
        return vp, egg
    end
    -- no 3D template: a plain egg shape in the rarity colour
    local shape = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.5, 0.66),
        BackgroundColor3 = Config.RarityColor("Common"),
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = parent,
    })
    new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = shape })
    return shape, nil
end

-- ═══════════════════════════ cards ═══════════════════════════
local function buildCard(role, d)
    local isThief = role == "Thief"
    local rarityColor = Config.RarityColor(d.rarity)
    local H, W = UI.CardHeight, UI.CardWidth

    local slot = new("Frame", {
        Name = role .. "Slot",
        Size = UDim2.fromOffset(W, H),
        BackgroundTransparency = 1,
        LayoutOrder = isThief and 1 or 2,
        Parent = stack,
    })
    local frame = new("Frame", {
        Name = "Card",
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, -(H + 70)),
        BackgroundTransparency = 1,
        Parent = slot,
    })
    local panel = makePanel(frame, isThief and K.Alert or K.Victim)
    local flash = new("Frame", {
        Name = "Flash",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 8,
        Parent = panel,
    })

    -- egg icon (a real 3D egg of the stolen type, slowly turning)
    local ring = new("Frame", {
        Name = "Icon",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(46, H / 2),
        Size = UDim2.fromOffset(62, 62),
        BackgroundColor3 = K.Dark,
        BackgroundTransparency = 0.18,
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = panel,
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
    new("UIStroke", { Color = rarityColor, Thickness = 3, Parent = ring })
    local iconScale = new("UIScale", { Scale = 1, Parent = ring })
    local _, egg = makeEggViewport(ring, d.eggType)

    local textX, textW = 88, W - 88 - 62
    local title, titleStroke = makeText(panel, {
        Name = "Title",
        Text = isThief and "EGG STOLEN!" or "YOUR EGG IS BEING STOLEN!",
        Position = UDim2.fromOffset(textX, 6),
        Size = UDim2.fromOffset(textW, 30),
        TextScaled = true,
    })
    new("UITextSizeConstraint", { MaxTextSize = 29, MinTextSize = 10, Parent = title })
    local titleScale = new("UIScale", { Scale = 1, Parent = title })

    local subtitle = makeText(panel, {
        Name = "Subtitle",
        Text = isThief and "RETURN TO YOUR BASE" or ("THIEF: " .. string.upper(d.thiefName or "?")),
        Position = UDim2.fromOffset(textX, 37),
        Size = UDim2.fromOffset(textW, 16),
        TextScaled = true,
        TextColor3 = Color3.fromRGB(255, 244, 214),
    })
    new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 9, Parent = subtitle })

    -- badge shown in the run-back state
    local badge = new("Frame", {
        Name = "Badge",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(textX + 12, 21),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = K.Gold,
        Visible = false,
        ZIndex = 4,
        Parent = panel,
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
    new("UIStroke", { Color = K.Outline, Thickness = 2, Parent = badge })
    local badgeScale = new("UIScale", { Scale = 0, Parent = badge })
    local _, bangStroke = makeText(badge, {
        Text = "!",
        Size = UDim2.fromScale(1, 1),
        TextSize = 20,
        TextColor3 = K.Outline,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 5,
    })
    bangStroke:Destroy() -- dark "!" on gold needs no outline

    -- name • RARITY chip • value
    local row = new("Frame", {
        Name = "Row",
        Position = UDim2.fromOffset(textX, 55),
        Size = UDim2.fromOffset(textW, 20),
        BackgroundTransparency = 1,
        ZIndex = 4,
        Parent = panel,
    })
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = row,
    })
    local nameLabel = makeText(row, {
        Name = "EggName",
        Text = d.name,
        TextSize = 17,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 20),
        LayoutOrder = 1,
    })
    local chip = new("Frame", {
        Name = "Rarity",
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 18),
        BackgroundColor3 = rarityColor,
        ZIndex = 4,
        LayoutOrder = 2,
        Parent = row,
    })
    new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = chip })
    new("UIStroke", { Color = K.Outline, Thickness = 2, Parent = chip })
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = chip })
    local chipText = new("TextLabel", {
        Text = string.upper(d.rarity),
        Font = Enum.Font.Cartoon,
        TextSize = 13,
        TextColor3 = K.Outline,
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 18),
        ZIndex = 5,
        Parent = chip,
    })
    local valueLabel
    if isThief and UI.ShowValue and (d.price or 0) > 0 then
        valueLabel = makeText(row, {
            Name = "Value",
            Text = "$" .. commas(d.price),
            TextSize = 16,
            TextColor3 = K.Gold,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 20),
            LayoutOrder = 3,
        })
    end

    -- direction arrow + distance (points to the base, or to the thief)
    local compass = new("Frame", {
        Name = "Compass",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(W - 34, 31),
        Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = K.Dark,
        BackgroundTransparency = 0.25,
        ZIndex = 3,
        Parent = panel,
    })
    new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = compass })
    new("UIStroke", { Color = isThief and K.Base or K.Gold, Thickness = 2.5, Parent = compass })
    local arrow = new("TextLabel", {
        Name = "Arrow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(30, 30),
        BackgroundTransparency = 1,
        Text = "▲",
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        TextColor3 = isThief and K.Base or K.Gold,
        ZIndex = 5,
        Parent = compass,
    })
    local arrowScale = new("UIScale", { Scale = 1, Parent = arrow })
    local dist = makeText(panel, {
        Name = "Distance",
        Text = "",
        Position = UDim2.fromOffset(W - 62, 56),
        Size = UDim2.fromOffset(56, 16),
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    return {
        role = role,
        slot = slot,
        frame = frame,
        panel = panel,
        flash = flash,
        ring = ring,
        iconScale = iconScale,
        egg = egg,
        title = title,
        titleStroke = titleStroke,
        titleScale = titleScale,
        subtitle = subtitle,
        badge = badge,
        badgeScale = badgeScale,
        row = row,
        nameLabel = nameLabel,
        chip = chip,
        chipText = chipText,
        valueLabel = valueLabel,
        compass = compass,
        arrow = arrow,
        arrowScale = arrowScale,
        dist = dist,
        rarityColor = rarityColor,
        textX = textX,
        textW = textW,
        destroyed = false,
    }
end

local function destroyCard(card)
    if not card or card.destroyed then
        return
    end
    card.destroyed = true
    card.slot:Destroy()
end

local function slideOut(card, fast, then_)
    if not card or card.destroyed then
        return
    end
    local t = tw(
        card.frame,
        fast and 0.18 or 0.32,
        { Position = UDim2.fromOffset(0, -(UI.CardHeight + 80)) },
        fast and Enum.EasingStyle.Quad or Enum.EasingStyle.Back,
        EASE_IN
    )
    t.Completed:Once(function()
        destroyCard(card)
        if then_ then
            then_()
        end
    end)
end

-- spark particles around a card, spawned in the full-screen fx layer
local function sparks(card, color, count)
    if reduced() or card.destroyed then
        return
    end
    local pos, size = card.slot.AbsolutePosition, card.slot.AbsoluteSize
    if size.X < 1 then
        return
    end
    local center = pos + size / 2
    local scale = stackScale.Scale
    for i = 1, count do
        -- random point on the card's outline
        local perimeter = 2 * (size.X + size.Y)
        local d = math.random() * perimeter
        local p
        if d < size.X then
            p = pos + Vector2.new(d, 0)
        elseif d < size.X + size.Y then
            p = pos + Vector2.new(size.X, d - size.X)
        elseif d < 2 * size.X + size.Y then
            p = pos + Vector2.new(2 * size.X + size.Y - d, size.Y)
        else
            p = pos + Vector2.new(0, perimeter - d)
        end
        local dir = (p - center)
        dir = dir.Magnitude > 0 and dir.Unit or Vector2.new(0, -1)
        local spark = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(p.X, p.Y),
            Size = UDim2.fromOffset(9, 9),
            Rotation = 45,
            BackgroundColor3 = (i % 2 == 0) and color or K.Gold,
            BorderSizePixel = 0,
            Parent = fx,
        })
        new("UICorner", { CornerRadius = UDim.new(0, 2), Parent = spark })
        local to = p + dir * (math.random(18, 52) * scale) + Vector2.new(0, math.random(-8, 10))
        local time = 0.45 + math.random() * 0.25
        tw(spark, time, {
            Position = UDim2.fromOffset(to.X, to.Y),
            Size = UDim2.fromOffset(2, 2),
            BackgroundTransparency = 1,
            Rotation = 45 + math.random(-120, 120),
        })
        Debris:AddItem(spark, time + 0.1)
    end
end

local function popIcon(card, peak)
    card.iconScale.Scale = 0.6
    tw(card.iconScale, 0.2, { Scale = peak or 1.1 }).Completed:Once(function()
        if not card.destroyed then
            tw(card.iconScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Sine, EASE_IO)
        end
    end)
end

local function flashCard(card, alpha)
    card.flash.BackgroundTransparency = alpha or 0.45
    tw(card.flash, 0.35, { BackgroundTransparency = 1 })
end

local function fadeTitle(card, to, time)
    tw(card.title, time, { TextTransparency = to })
    tw(card.titleStroke, time, { Transparency = to })
end

local function entrance(card, flashColor)
    tw(card.frame, UI.DropTime, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back, EASE_OUT)
    task.delay(0.12, function()
        if not card.destroyed then
            popIcon(card, 1.1)
        end
    end)
    task.delay(0.2, function()
        if card.destroyed then
            return
        end
        flashCard(card, 0.4)
        -- "EGG STOLEN!" flashes once
        card.title.TextColor3 = Color3.fromRGB(255, 240, 130)
        tw(card.title, 0.4, { TextColor3 = Color3.new(1, 1, 1) })
        card.titleScale.Scale = 1.18
        tw(card.titleScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, EASE_OUT)
    end)
    task.delay(UI.DropTime - 0.1, function()
        sparks(card, flashColor or K.Alert, UI.Sparks)
    end)
    -- very subtle full-screen pulse
    tint.BackgroundColor3 = flashColor or K.Danger
    tint.BackgroundTransparency = 0.9
    tw(tint, 0.45, { BackgroundTransparency = 1 })
end

-- ═══════════════════════════ waypoint marker ═══════════════════════════
local MARKER_W, MARKER_H = 96, 46

local function buildMarker(label, color)
    local frame = new("Frame", {
        Name = "Marker",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(MARKER_W, MARKER_H),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = markerLayer,
    })
    local scale = new("UIScale", { Scale = 0, Parent = frame })
    local pill = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = K.Dark,
        BackgroundTransparency = 0.15,
        Parent = frame,
    })
    new("UICorner", { CornerRadius = UDim.new(0, 12), Parent = pill })
    new("UIStroke", { Color = color, Thickness = 2.5, Parent = pill })
    makeText(pill, {
        Text = label,
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, 0, 0, 16),
        TextSize = 14,
        TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local dist = makeText(pill, {
        Text = "",
        Position = UDim2.fromOffset(0, 19),
        Size = UDim2.new(1, 0, 0, 24),
        TextSize = 21,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local arrow = new("TextLabel", {
        Name = "Arrow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(26, 26),
        BackgroundTransparency = 1,
        Text = "▲",
        Font = Enum.Font.GothamBold,
        TextSize = 24,
        TextColor3 = color,
        ZIndex = 5,
        Parent = frame,
    })
    new("UIStroke", { Color = K.Outline, Thickness = 2, Parent = arrow })
    return { frame = frame, scale = scale, dist = dist, arrow = arrow }
end

local function markerIn(m)
    task.delay(0.3, function() -- after the card has landed
        if m.frame.Parent then
            tw(m.scale, 0.35, { Scale = stackScale.Scale }, Enum.EasingStyle.Back, EASE_OUT)
        end
    end)
end

local function markerOut(m)
    if not m or not m.frame.Parent then
        return
    end
    tw(m.scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, EASE_IN).Completed:Once(function()
        m.frame:Destroy()
    end)
end

local function victimTarget(g)
    local p = Players:GetPlayerByUserId(g.thiefUserId)
    local r = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    return r and r.Position or g.pos
end

local function wrapAngle(a)
    return (a + math.pi) % (2 * math.pi) - math.pi
end

local function updateGuide(g, cam, root, target)
    local pos = root.Position
    local meters = (target - pos).Magnitude * UI.MetersPerStud
    local text = string.format("%dm", math.floor(meters + 0.5))
    if text ~= g.lastText then
        g.lastText = text
        g.card.dist.Text = text
        g.marker.dist.Text = text
    end

    -- compass arrow in the card: bearing of the target relative to where the camera looks
    local look = cam.CFrame.LookVector
    local headL = math.atan2(look.X, look.Z)
    local headT = math.atan2(target.X - pos.X, target.Z - pos.Z)
    g.card.arrow.Rotation = -math.deg(wrapAngle(headT - headL))

    -- waypoint marker: pinned over the target, or clamped to the screen edge pointing at it (even when behind you)
    local m = g.marker
    local vp = cam.ViewportSize
    local sc = stackScale.Scale
    local l, r, t, b = 80 * sc, vp.X - 215 * sc, 130 * sc, vp.Y - 130 * sc -- keep clear of the card, SETTINGS button, hotbar, thumbs
    local aim = target + Vector3.new(0, 7, 0)
    local v3, onScreen = cam:WorldToViewportPoint(aim)
    local inside = onScreen and v3.X >= l and v3.X <= r and v3.Y >= t and v3.Y <= b
    if inside then
        m.frame.Position = UDim2.fromOffset(v3.X, v3.Y)
        m.arrow.Position = UDim2.new(0.5, 0, 1, 18)
        m.arrow.Rotation = 180
    else
        local rel = cam.CFrame:PointToObjectSpace(aim)
        local dir = Vector2.new(rel.X, -rel.Y)
        dir = dir.Magnitude > 1e-3 and dir.Unit or Vector2.new(0, 1)
        local rc, hw, hh = Vector2.new((l + r) / 2, (t + b) / 2), (r - l) / 2, (b - t) / 2
        local k = math.min(hw / math.max(math.abs(dir.X), 1e-4), hh / math.max(math.abs(dir.Y), 1e-4))
        local p = rc + dir * k
        m.frame.Position = UDim2.fromOffset(p.X, p.Y)
        m.arrow.Position = UDim2.new(0.5, dir.X * (MARKER_W / 2 + 16), 0.5, dir.Y * (MARKER_H / 2 + 16))
        m.arrow.Rotation = math.deg(math.atan2(dir.Y, dir.X)) + 90
    end
    m.frame.Visible = true
end

-- ═══════════════════════════ the one per-frame loop ═══════════════════════════
local function step(dt)
    local cam = workspace.CurrentCamera
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local now = os.clock()

    -- red danger pulse around the screen edges
    local d = danger
    d.level += math.clamp(d.target - d.level, -dt * 3.3, dt * 3.3)
    if d.level > 0.001 then
        local ramp = math.clamp((now - d.since) / UI.PulseRampSeconds, 0, 1)
        d.phase += dt * math.pi * 2 / lerp(UI.PulseSlow, UI.PulseFast, ramp) -- pulses get quicker the longer you run
        local pulse = reduced() and 0.5 or (0.5 + 0.5 * math.sin(d.phase))
        local opacity = lerp(UI.VignetteOpacityLow, UI.VignetteOpacityHigh, pulse)
        vignette.Visible = true
        vignette.GroupTransparency = 1 - opacity * d.level
    elseif vignette.Visible then
        vignette.Visible = false
    end

    for _, g in { run.thief, run.victim } do
        if g and not g.card.destroyed then
            if g.card.egg then
                g.card.egg.CFrame = CFrame.Angles(0, now * 1.6, 0)
            end
            if g.guide and root and cam then
                local target = g.role == "Thief" and g.base or victimTarget(g)
                updateGuide(g, cam, root, target)
                g.card.arrowScale.Scale = 1 + 0.1 * math.sin(now * 7) -- the arrow breathes: "go this way"
            end
        end
    end

    if not run.thief and not run.victim and d.level <= 0.001 and d.target == 0 then
        stepConn:Disconnect()
        stepConn = nil
    end
end

local function ensureStep()
    if not stepConn then
        stepConn = RunService.RenderStepped:Connect(step)
    end
end

-- ═══════════════════════════ camera shake / gold burst ═══════════════════════════
local function shake(duration, magnitude)
    if reduced() then
        return
    end
    local t0 = os.clock()
    pcall(RunService.UnbindFromRenderStep, RunService, "EggStealShake")
    RunService:BindToRenderStep("EggStealShake", Enum.RenderPriority.Camera.Value + 1, function()
        local a = (os.clock() - t0) / duration
        if a >= 1 then
            RunService:UnbindFromRenderStep("EggStealShake")
            return
        end
        local m = magnitude * (1 - a) ^ 2
        local cam = workspace.CurrentCamera
        cam.CFrame *= CFrame.new((math.random() - 0.5) * m * 4, (math.random() - 0.5) * m * 4, 0) * CFrame.Angles(
            (math.random() - 0.5) * m,
            (math.random() - 0.5) * m,
            (math.random() - 0.5) * m * 0.6
        )
    end)
end

local function goldBurst()
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local att = new("Attachment", { Position = Vector3.new(0, 0.5, 0), Parent = root })
    local function emitter(count, speed, size, life)
        local e = new("ParticleEmitter", {
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
            Enabled = false,
            Rate = 0,
            LightEmission = 1,
            LightInfluence = 0,
            Drag = 3,
            SpreadAngle = Vector2.new(180, 180),
            Speed = speed,
            Lifetime = life,
            Rotation = NumberRange.new(0, 360),
            RotSpeed = NumberRange.new(-120, 120),
            Color = ColorSequence.new(K.Gold, Color3.new(1, 1, 1)),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) }),
            Parent = att,
        })
        e:Emit(count)
    end
    emitter(34, NumberRange.new(14, 26), 1, NumberRange.new(0.6, 1.1))
    emitter(16, NumberRange.new(4, 9), 1.8, NumberRange.new(0.9, 1.4))
    Debris:AddItem(att, 2.2)
end

-- ═══════════════════════════ alarms ═══════════════════════════
local function startThiefAlarm(g)
    task.spawn(function()
        for _ = 1, A.InitialBeeps do -- BEEP — BEEP — BEEP
            if not g.alive then
                return
            end
            play("Beep", A.BeepVolume, A.BeepSpeed)
            task.wait(A.BeepGap)
        end
        while g.alive do
            local ramp = math.clamp((os.clock() - g.start) / UI.PulseRampSeconds, 0, 1)
            task.wait(lerp(A.PulseInterval, A.PulseMinInterval, ramp)) -- quiet reminder, slightly quicker over time
            if not g.alive then
                return
            end
            play("Beep", A.PulseVolume, A.BeepSpeed - 0.15)
        end
    end)
end

local function startVictimAlarm(g)
    task.spawn(function()
        twoTone(A.VictimVolume)
        while g.alive do
            task.wait(A.VictimRepeat)
            if not g.alive then
                return
            end
            twoTone(A.VictimVolume * 0.5)
        end
    end)
end

-- ═══════════════════════════ prompt filter ═══════════════════════════
-- The server enables the prompt for everyone; here it is hidden from the egg's owner and from anyone already carrying.
local function applyPrompt(prompt)
    local hide = prompt:GetAttribute("OwnerUserId") == player.UserId or run.thief ~= nil
    local want = prompt:GetAttribute("Stealable") == true and not hide
    if prompt.Enabled ~= want then
        prompt.Enabled = want
    end
end

local function watchPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then
        return
    end
    applyPrompt(prompt)
    prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
        applyPrompt(prompt)
    end)
    prompt:GetAttributeChangedSignal("Stealable"):Connect(function()
        applyPrompt(prompt)
    end)
    prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
        applyPrompt(prompt)
    end)
end

local function refreshPrompts()
    for _, p in CollectionService:GetTagged("EggStealPrompt") do
        applyPrompt(p)
    end
end

-- ═══════════════════════════ THIEF ═══════════════════════════
local function endThief(g, instant)
    if run.thief ~= g then
        return
    end
    run.thief = nil
    g.alive = false
    if instant then
        Banner.Hide()
    else
        Banner.Resolve("Cancelled")
    end
    refreshPrompts()
end

local function toCarryState(g)
    local c = g.card
    if not g.alive or c.destroyed then
        return
    end
    tw(c.panel, 0.35, { BackgroundColor3 = K.Carry })
    fadeTitle(c, 1, 0.1)
    task.delay(0.1, function()
        if c.destroyed or not g.alive then
            return
        end
        c.title.Text = "STOLEN EGG"
        c.title.Position = UDim2.fromOffset(c.textX + 28, 6)
        c.title.Size = UDim2.fromOffset(c.textW - 28, 30)
        fadeTitle(c, 0, 0.15)
        c.badge.Visible = true
        tw(c.badgeScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, EASE_OUT)
    end)
end

local function onThiefStart(d)
    if run.thief and run.thief.id == d.id then
        return
    end
    if run.thief then
        endThief(run.thief, true)
    end
    local g = {
        role = "Thief",
        id = d.id,
        alive = true,
        start = os.clock(),
        base = d.base,
        data = d,
        card = {
            destroyed = true,
        },
    }
    run.thief = g
    Banner.Show(d.base, d)
    refreshPrompts()
    task.delay(Config.ClientFailsafeSeconds, function()
        if run.thief == g then
            endThief(g, false)
        end
    end)
end

local function flyToBackpack(g, card)
    if card.destroyed then
        return
    end
    local ring = card.ring
    local vp = workspace.CurrentCamera.ViewportSize
    local from = ring.AbsolutePosition + ring.AbsoluteSize / 2
    local to = Vector2.new(vp.X / 2, vp.Y - 48 * stackScale.Scale)
    local ctrl = Vector2.new((from.X + to.X) / 2, math.min(from.Y, to.Y) - 140 * stackScale.Scale)
    local s0 = stackScale.Scale * card.iconScale.Scale
    ring.Parent = fx -- lift the egg out of the card
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromOffset(from.X, from.Y)
    card.iconScale.Scale = s0
    slideOut(card, false)

    local u = new("NumberValue", { Value = 0 })
    local conn
    conn = u.Changed:Connect(function(v)
        local p = (1 - v) ^ 2 * from + 2 * (1 - v) * v * ctrl + v * v * to
        ring.Position = UDim2.fromOffset(p.X, p.Y)
        ring.Rotation = v * 20
        card.iconScale.Scale = lerp(s0, s0 * 0.38, v)
    end)
    local flight = tw(u, 0.62, { Value = 1 }, Enum.EasingStyle.Sine, EASE_IO)
    flight.Completed:Once(function()
        conn:Disconnect()
        u:Destroy()
        ring:Destroy()
        -- ring pulse where the egg lands
        local pulse = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(to.X, to.Y),
            Size = UDim2.fromOffset(20, 20),
            BackgroundTransparency = 1,
            Parent = fx,
        })
        new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pulse })
        new("UIStroke", { Color = K.Gold, Thickness = 3, Parent = pulse })
        tw(pulse, 0.45, { Size = UDim2.fromOffset(110 * stackScale.Scale, 110 * stackScale.Scale) })
        tw(pulse.UIStroke, 0.45, { Transparency = 1 })
        Debris:AddItem(pulse, 0.5)
        play("Chime", 0.35, 2)
    end)
end

local function securedThief(g, info)
    if run.thief ~= g then
        return
    end
    g.alive = false
    run.thief = nil
    Banner.Resolve("Secured")
    refreshPrompts()
end

-- ═══════════════════════════ OWNER ═══════════════════════════
local function endVictim(g, payload)
    if run.victim ~= g then
        return
    end
    g.alive = false
    g.guide = false
    markerOut(g.marker)
    local c = g.card
    if c.destroyed then
        run.victim = nil
        return
    end
    c.badge.Visible = false
    c.compass.Visible = false
    c.dist.Visible = false
    if payload.result == "Failed" then
        play("Chime", 0.3, 1.4)
        tw(c.panel, 0.25, { BackgroundColor3 = K.Success })
        c.title.Text = "EGG RECOVERED!"
        c.subtitle.Text = "THE THIEF FAILED"
    else
        tw(c.panel, 0.25, { BackgroundColor3 = Color3.fromRGB(78, 80, 104) })
        c.title.Text = "EGG LOST"
        c.subtitle.Text = "STOLEN BY " .. string.upper(g.thiefName or "?")
    end
    flashCard(c, 0.3)
    task.delay(payload.result == "Failed" and 1.6 or 2.4, function()
        slideOut(c, false, function()
            if run.victim == g then
                run.victim = nil
            end
        end)
    end)
end

local function onVictimAlert(d)
    if run.victim then
        local old = run.victim
        old.alive = false
        destroyCard(old.card)
        markerOut(old.marker)
        run.victim = nil
    end
    local g = {
        role = "Victim",
        id = d.id,
        alive = true,
        start = os.clock(),
        pos = d.pos,
        thiefUserId = d.thiefUserId,
        thiefName = d.thiefName,
        lastText = "",
        guide = true,
    }
    run.victim = g
    g.card = buildCard("Victim", d)
    g.marker = buildMarker("STOLEN EGG", K.Victim)
    markerIn(g.marker)
    ensureStep()
    startVictimAlarm(g)
    entrance(g.card, K.Victim)
    task.delay(Config.ClientFailsafeSeconds, function()
        if run.victim == g then
            g.alive = false
            destroyCard(g.card)
            markerOut(g.marker)
            run.victim = nil
        end
    end)
end

-- ═══════════════════════════ server messages ═══════════════════════════
local function onEvent(action, a, b)
    if action == "Start" and typeof(a) == "table" then
        onThiefStart(a)
    elseif action == "Alert" and typeof(a) == "table" then
        onVictimAlert(a)
    elseif action == "Pos" then
        local g = run.victim
        if g and g.id == a and typeof(b) == "Vector3" then
            g.pos = b
        end
    elseif action == "End" and typeof(a) == "table" then
        local g = run.thief
        if g and g.id == a.id then
            if a.result == "Secured" then
                securedThief(g, a.info)
            else
                local cancelled = {
                    VictimGone = true,
                    HomeLost = true,
                    EggChanged = true,
                    Left = true,
                    Reset = true,
                    Cancelled = true,
                    Error = true,
                }
                run.thief = nil
                g.alive = false
                Banner.Resolve(cancelled[a.reason] and "Cancelled" or "Dropped")
                refreshPrompts()
            end
            return
        end
        g = run.victim
        if g and g.id == a.id then
            endVictim(g, a)
        end
    end
end

-- ═══════════════════════════ start ═══════════════════════════
function Client.Start()
    if started then
        return
    end
    started = true
    Banner.Start()

    gui = new("ScreenGui", {
        Name = "EggStealUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 40,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = player:WaitForChild("PlayerGui"),
    })

    vignette = new("CanvasGroup", {
        Name = "DangerPulse",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        Visible = false,
        Parent = gui,
    })
    local function edge(anchor, pos, size, rotation)
        local f = new("Frame", {
            AnchorPoint = anchor,
            Position = pos,
            Size = size,
            BackgroundColor3 = K.Danger,
            BorderSizePixel = 0,
            Parent = vignette,
        })
        new("UIGradient", {
            Rotation = rotation,
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
            Parent = f,
        })
    end
    edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.15), 90)
    edge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.15), -90)
    edge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.09, 1), 0)
    edge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.09, 1), 180)

    tint = new("Frame", {
        Name = "PulseTint",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = K.Danger,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = gui,
    })
    markerLayer =
        new("Frame", { Name = "Markers", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
    stack = new("Frame", {
        Name = "Stack",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, UI.TopOffset),
        Size = UDim2.fromOffset(UI.CardWidth, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = gui,
    })
    new("UIListLayout", {
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = stack,
    })
    stackScale = new("UIScale", { Parent = stack })
    fx = new(
        "Frame",
        { Name = "FX", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = gui }
    )

    -- scale with the screen: phones get a smaller card, big monitors a slightly larger one
    local function rescale()
        local cam = workspace.CurrentCamera
        if cam then
            stackScale.Scale = math.clamp(cam.ViewportSize.Y / 900, 0.72, 1.1)
        end
    end
    rescale()
    local camConn
    local function hookCamera()
        if camConn then
            camConn:Disconnect()
        end
        local cam = workspace.CurrentCamera
        if cam then
            camConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
        end
        rescale()
    end
    hookCamera()
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)

    local toLoad = {}
    for name, id in S do
        if id ~= "" then
            local s = new("Sound", { Name = "EggSteal_" .. name, SoundId = id, Parent = gui })
            sounds[name] = s
            table.insert(toLoad, s)
        end
    end
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync(toLoad)
        end)
    end)

    CollectionService:GetInstanceAddedSignal("EggStealPrompt"):Connect(watchPrompt)
    for _, p in CollectionService:GetTagged("EggStealPrompt") do
        watchPrompt(p)
    end

    local event = script.Parent:WaitForChild("Event")
    event.OnClientEvent:Connect(onEvent)
    local function recoverCarry()
        local id = player:GetAttribute("CarryingStolenEggId")
        local base = player:GetAttribute("CarryingStolenEggBase")
        if id and typeof(base) == "Vector3" then
            onThiefStart({ id = id, base = base })
        elseif run.thief then
            local expected = run.thief
            task.delay(0.4, function()
                if run.thief == expected and not player:GetAttribute("CarryingStolenEggId") then
                    endThief(expected, false)
                end
            end)
        end
    end
    player:GetAttributeChangedSignal("CarryingStolenEggId"):Connect(recoverCarry)
    player:GetAttributeChangedSignal("CarryingStolenEggBase"):Connect(recoverCarry)
    recoverCarry()
end

return Client
