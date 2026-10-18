--[[ ReplicatedStorage.EggSteal.EggStealClient  (ModuleScript, CLIENT ONLY)
Pure presentation. The client never tells the server anything; it only reacts to the server's
"Start" / "Alert" / "Pos" / "End" messages. If this script is deleted the steal system still works.
Started by StarterPlayerScripts.EggStealClientStart via Client.Start().

Remote (ReplicatedStorage.EggSteal.Event, server -> client only; contract owned by EggStealService):
  "Start" {id,name,eggType,rarity,price,base}                     -> thief
  "Alert" {id,name,eggType,rarity,thiefName,thiefUserId,pos}      -> victim (egg owner)
  "Pos"   (id, position: Vector3)                                 -> victim, live thief position
  "End"   {id,result,reason,info}                                 -> both
Player attributes CarryingStolenEggId / CarryingStolenEggBase let a late or respawned client rebuild the thief state.

Thief:   the shared StolenEggBanner (Banner.Show / Banner.Resolve) shows the steal and the way home.
         The thief's steal record keeps a dummy card ({ destroyed = true }) so the per-frame loop skips it.
         The older thief card / alarm / backpack-flight helpers below are no longer called (prefixed `_`).
Owner:   top-centre card (YOUR EGG IS BEING STOLEN!), warning tones, waypoint to the egg.

Performance: one RenderStepped connection exists only while a steal is on screen. It moves the marker,
rotates the arrows, spins the egg icon and sets one CanvasGroup transparency. Texts update only when the
rounded distance changes. Sounds are pre-loaded instances. Particles are short tweens that clean up.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ContentProvider = game:GetService("ContentProvider")
local Debris = game:GetService("Debris")

local Config = require(script.Parent:WaitForChild("EggStealConfig"))
local COLORS, UI, ALARM, SOUND_IDS = Config.Colors, Config.UI, Config.Alarm, Config.Sounds
local player = Players.LocalPlayer

local Client = {}
local Banner = require(ReplicatedStorage:WaitForChild("StolenEggBanner"))

-- ═══════════════════════════ state ═══════════════════════════
local activeSteals = { thief = nil, victim = nil } -- at most one steal per role is shown at a time
local danger = { level = 0, target = 0, phase = 0, since = 0 } -- red edge pulse (level eases towards target)
local sounds = {} -- [Config.Sounds key] = Sound
local gui, stack, stackScale, vignette, tint, markerLayer, fxLayer -- created in Client.Start
local stepConn -- RenderStepped connection, alive only while something is on screen
local started = false

-- ═══════════════════════════ small helpers ═══════════════════════════
local EASE_OUT, EASE_IN, EASE_IO = Enum.EasingDirection.Out, Enum.EasingDirection.In, Enum.EasingDirection.InOut

-- Instance.new + props; Parent is assigned last so the instance is fully configured before it replicates/renders.
local function create(className, props)
    local instance = Instance.new(className)
    local parent
    for key, value in props do
        if key == "Parent" then
            parent = value
        else
            instance[key] = value
        end
    end
    instance.Parent = parent
    return instance
end

local function tween(instance, duration, goal, style, direction)
    local tweenObject = TweenService:Create(
        instance,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or EASE_OUT),
        goal
    )
    tweenObject:Play()
    return tweenObject
end

local function isReducedMotion()
    return player:GetAttribute("ReducedMotion") == true
end
local function lerp(from, to, alpha)
    return from + (to - from) * alpha
end

local function formatWithCommas(number)
    local digits = tostring(math.floor((tonumber(number) or 0) + 0.5))
    local grouped = digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (grouped:gsub("^,", ""))
end

-- ═══════════════════════════ sound ═══════════════════════════
local function playSound(name, volume, speed)
    local sound = sounds[name]
    if not sound then
        return
    end
    sound.Volume = volume * ALARM.Volume
    sound.PlaybackSpeed = speed or 1
    sound.TimePosition = 0
    sound:Play()
end

-- low-high warning tone, played twice (non-blocking)
local function playTwoTone(volume)
    task.spawn(function()
        for _ = 1, 2 do
            playSound("Beep", volume, 1.0)
            task.wait(0.22)
            playSound("Beep", volume, 1.5)
            task.wait(0.3)
        end
    end)
end

-- ═══════════════════════════ UI building blocks (same look as EggUIStyle) ═══════════════════════════
local function makePanel(parent, color)
    local frame = create("Frame", {
        Name = "Panel",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = parent,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 16), Parent = frame })
    create("UIStroke", { Thickness = 3, Color = COLORS.Outline, Parent = frame })
    create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 212)),
        Parent = frame,
    })
    -- low-contrast egg silhouettes, the same motif as the other panels
    for row = 0, 2 do
        for col = 0, 10 do
            local dot = create("Frame", {
                Name = "EggPattern",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(col * 0.1 + (row % 2) * 0.05, row * 0.4 + 0.1),
                Size = UDim2.fromScale(0.045, 0.3),
                BackgroundColor3 = Color3.new(1, 1, 1),
                BackgroundTransparency = 0.9,
                BorderSizePixel = 0,
                Parent = frame,
            })
            create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = dot })
        end
    end
    return frame
end

-- Outlined cartoon label. Mutates `props` (fills defaults) before creating the TextLabel.
local function makeText(parent, props)
    props.BackgroundTransparency = 1
    props.Font = props.Font or Enum.Font.Cartoon
    props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    props.ZIndex = props.ZIndex or 4
    props.Parent = parent
    local label = create("TextLabel", props)
    local stroke = create("UIStroke", { Color = COLORS.Outline, Thickness = 2, Parent = label })
    return label, stroke
end

-- Returns (viewport, eggPart) for a 3D EggVisuals template, or (fallbackFrame, nil) when there is none.
local function makeEggViewport(parent, eggType)
    local visuals = ReplicatedStorage:FindFirstChild("EggVisuals")
    local template = visuals and visuals:FindFirstChild(eggType)
    if template and template:IsA("BasePart") then
        local viewport = create("ViewportFrame", {
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
        local viewportCamera = create("Camera", { FieldOfView = 30, Parent = viewport })
        viewport.CurrentCamera = viewportCamera
        local egg = template:Clone()
        -- strip behaviour/UI from the copy; only the mesh is wanted
        for _, descendant in egg:GetDescendants() do
            if
                descendant:IsA("LuaSourceContainer")
                or descendant:IsA("ProximityPrompt")
                or descendant:IsA("BillboardGui")
            then
                descendant:Destroy()
            end
        end
        egg.Size *= 4 / egg.Size.Y -- normalise to 4 studs tall so every egg type frames the same
        egg.Anchored = true
        egg.CFrame = CFrame.new()
        egg.Parent = viewport
        viewportCamera.CFrame = CFrame.lookAt(Vector3.new(0, 0.25, 9.2), Vector3.zero)
        return viewport, egg
    end
    -- no 3D template: a plain egg shape in the rarity colour
    local shape = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.5, 0.66),
        BackgroundColor3 = Config.RarityColor("Common"),
        BorderSizePixel = 0,
        ZIndex = 4,
        Parent = parent,
    })
    create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = shape })
    return shape, nil
end

-- ═══════════════════════════ cards ═══════════════════════════
-- Builds a role card ("Thief" | "Victim") inside `stack`, starting above the screen (entrance() drops it in).
-- `stealData` is the "Start"/"Alert" payload.
local function buildCard(role, stealData)
    local isThief = role == "Thief"
    local rarityColor = Config.RarityColor(stealData.rarity)
    local cardHeight, cardWidth = UI.CardHeight, UI.CardWidth

    local slot = create("Frame", {
        Name = role .. "Slot",
        Size = UDim2.fromOffset(cardWidth, cardHeight),
        BackgroundTransparency = 1,
        LayoutOrder = isThief and 1 or 2,
        Parent = stack,
    })
    local frame = create("Frame", {
        Name = "Card",
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, -(cardHeight + 70)),
        BackgroundTransparency = 1,
        Parent = slot,
    })
    local panel = makePanel(frame, isThief and COLORS.Alert or COLORS.Victim)
    local flash = create("Frame", {
        Name = "Flash",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 8,
        Parent = panel,
    })

    -- egg icon (a real 3D egg of the stolen type, slowly turning)
    local ring = create("Frame", {
        Name = "Icon",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(46, cardHeight / 2),
        Size = UDim2.fromOffset(62, 62),
        BackgroundColor3 = COLORS.Dark,
        BackgroundTransparency = 0.18,
        ClipsDescendants = true,
        ZIndex = 3,
        Parent = panel,
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ring })
    create("UIStroke", { Color = rarityColor, Thickness = 3, Parent = ring })
    local iconScale = create("UIScale", { Scale = 1, Parent = ring })
    local _, egg = makeEggViewport(ring, stealData.eggType)

    local textX, textW = 88, cardWidth - 88 - 62 -- text column between the icon and the compass
    local title, titleStroke = makeText(panel, {
        Name = "Title",
        Text = isThief and "EGG STOLEN!" or "YOUR EGG IS BEING STOLEN!",
        Position = UDim2.fromOffset(textX, 6),
        Size = UDim2.fromOffset(textW, 30),
        TextScaled = true,
    })
    create("UITextSizeConstraint", { MaxTextSize = 29, MinTextSize = 10, Parent = title })
    local titleScale = create("UIScale", { Scale = 1, Parent = title })

    local subtitle = makeText(panel, {
        Name = "Subtitle",
        Text = isThief and "RETURN TO YOUR BASE" or ("THIEF: " .. string.upper(stealData.thiefName or "?")),
        Position = UDim2.fromOffset(textX, 37),
        Size = UDim2.fromOffset(textW, 16),
        TextScaled = true,
        TextColor3 = Color3.fromRGB(255, 244, 214),
    })
    create("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 9, Parent = subtitle })

    -- badge shown in the run-back state
    local badge = create("Frame", {
        Name = "Badge",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(textX + 12, 21),
        Size = UDim2.fromOffset(24, 24),
        BackgroundColor3 = COLORS.Gold,
        Visible = false,
        ZIndex = 4,
        Parent = panel,
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = badge })
    create("UIStroke", { Color = COLORS.Outline, Thickness = 2, Parent = badge })
    local badgeScale = create("UIScale", { Scale = 0, Parent = badge })
    local _, bangStroke = makeText(badge, {
        Text = "!",
        Size = UDim2.fromScale(1, 1),
        TextSize = 20,
        TextColor3 = COLORS.Outline,
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 5,
    })
    bangStroke:Destroy() -- dark "!" on gold needs no outline

    -- name • RARITY chip • value
    local row = create("Frame", {
        Name = "Row",
        Position = UDim2.fromOffset(textX, 55),
        Size = UDim2.fromOffset(textW, 20),
        BackgroundTransparency = 1,
        ZIndex = 4,
        Parent = panel,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = row,
    })
    local nameLabel = makeText(row, {
        Name = "EggName",
        Text = stealData.name,
        TextSize = 17,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 20),
        LayoutOrder = 1,
    })
    local chip = create("Frame", {
        Name = "Rarity",
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 18),
        BackgroundColor3 = rarityColor,
        ZIndex = 4,
        LayoutOrder = 2,
        Parent = row,
    })
    create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = chip })
    create("UIStroke", { Color = COLORS.Outline, Thickness = 2, Parent = chip })
    create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = chip })
    local chipText = create("TextLabel", {
        Text = string.upper(stealData.rarity),
        Font = Enum.Font.Cartoon,
        TextSize = 13,
        TextColor3 = COLORS.Outline,
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 18),
        ZIndex = 5,
        Parent = chip,
    })
    local valueLabel
    if isThief and UI.ShowValue and (stealData.price or 0) > 0 then
        valueLabel = makeText(row, {
            Name = "Value",
            Text = "$" .. formatWithCommas(stealData.price),
            TextSize = 16,
            TextColor3 = COLORS.Gold,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.fromOffset(0, 20),
            LayoutOrder = 3,
        })
    end

    -- direction arrow + distance (points to the base, or to the thief)
    local compass = create("Frame", {
        Name = "Compass",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromOffset(cardWidth - 34, 31),
        Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = COLORS.Dark,
        BackgroundTransparency = 0.25,
        ZIndex = 3,
        Parent = panel,
    })
    create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = compass })
    create("UIStroke", { Color = isThief and COLORS.Base or COLORS.Gold, Thickness = 2.5, Parent = compass })
    local arrow = create("TextLabel", {
        Name = "Arrow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(30, 30),
        BackgroundTransparency = 1,
        Text = "▲",
        Font = Enum.Font.GothamBold,
        TextSize = 26,
        TextColor3 = isThief and COLORS.Base or COLORS.Gold,
        ZIndex = 5,
        Parent = compass,
    })
    local arrowScale = create("UIScale", { Scale = 1, Parent = arrow })
    local distanceLabel = makeText(panel, {
        Name = "Distance",
        Text = "",
        Position = UDim2.fromOffset(cardWidth - 62, 56),
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
        dist = distanceLabel,
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

-- Slides the card up off-screen, destroys it, then calls onDone (optional).
local function slideOut(card, fast, onDone)
    if not card or card.destroyed then
        return
    end
    local slideTween = tween(
        card.frame,
        fast and 0.18 or 0.32,
        { Position = UDim2.fromOffset(0, -(UI.CardHeight + 80)) },
        fast and Enum.EasingStyle.Quad or Enum.EasingStyle.Back,
        EASE_IN
    )
    slideTween.Completed:Once(function()
        destroyCard(card)
        if onDone then
            onDone()
        end
    end)
end

-- spark particles around a card, spawned in the full-screen fx layer
local function sparks(card, color, count)
    if isReducedMotion() or card.destroyed then
        return
    end
    local cardPos, cardSize = card.slot.AbsolutePosition, card.slot.AbsoluteSize
    if cardSize.X < 1 then
        return -- not laid out yet
    end
    local center = cardPos + cardSize / 2
    local uiScale = stackScale.Scale
    for i = 1, count do
        -- random point on the card's outline: walk `along` pixels clockwise from the top-left corner
        local perimeter = 2 * (cardSize.X + cardSize.Y)
        local along = math.random() * perimeter
        local edgePoint
        if along < cardSize.X then
            edgePoint = cardPos + Vector2.new(along, 0)
        elseif along < cardSize.X + cardSize.Y then
            edgePoint = cardPos + Vector2.new(cardSize.X, along - cardSize.X)
        elseif along < 2 * cardSize.X + cardSize.Y then
            edgePoint = cardPos + Vector2.new(2 * cardSize.X + cardSize.Y - along, cardSize.Y)
        else
            edgePoint = cardPos + Vector2.new(0, perimeter - along)
        end
        local outward = (edgePoint - center)
        outward = outward.Magnitude > 0 and outward.Unit or Vector2.new(0, -1)
        local spark = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(edgePoint.X, edgePoint.Y),
            Size = UDim2.fromOffset(9, 9),
            Rotation = 45,
            BackgroundColor3 = (i % 2 == 0) and color or COLORS.Gold,
            BorderSizePixel = 0,
            Parent = fxLayer,
        })
        create("UICorner", { CornerRadius = UDim.new(0, 2), Parent = spark })
        local endPoint = edgePoint + outward * (math.random(18, 52) * uiScale) + Vector2.new(0, math.random(-8, 10))
        local duration = 0.45 + math.random() * 0.25
        tween(spark, duration, {
            Position = UDim2.fromOffset(endPoint.X, endPoint.Y),
            Size = UDim2.fromOffset(2, 2),
            BackgroundTransparency = 1,
            Rotation = 45 + math.random(-120, 120),
        })
        Debris:AddItem(spark, duration + 0.1)
    end
end

local function popIcon(card, peak)
    card.iconScale.Scale = 0.6
    tween(card.iconScale, 0.2, { Scale = peak or 1.1 }).Completed:Once(function()
        if not card.destroyed then
            tween(card.iconScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Sine, EASE_IO)
        end
    end)
end

local function flashCard(card, alpha)
    card.flash.BackgroundTransparency = alpha or 0.45
    tween(card.flash, 0.35, { BackgroundTransparency = 1 })
end

local function fadeTitle(card, transparency, duration)
    tween(card.title, duration, { TextTransparency = transparency })
    tween(card.titleStroke, duration, { Transparency = transparency })
end

-- Drop-in animation: slide down, pop the icon, flash the title, sparks, and a faint full-screen tint.
local function entrance(card, flashColor)
    tween(card.frame, UI.DropTime, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back, EASE_OUT)
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
        tween(card.title, 0.4, { TextColor3 = Color3.new(1, 1, 1) })
        card.titleScale.Scale = 1.18
        tween(card.titleScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, EASE_OUT)
    end)
    task.delay(UI.DropTime - 0.1, function()
        sparks(card, flashColor or COLORS.Alert, UI.Sparks)
    end)
    -- very subtle full-screen pulse
    tint.BackgroundColor3 = flashColor or COLORS.Danger
    tint.BackgroundTransparency = 0.9
    tween(tint, 0.45, { BackgroundTransparency = 1 })
end

-- ═══════════════════════════ waypoint marker ═══════════════════════════
local MARKER_W, MARKER_H = 96, 46

local function buildMarker(label, color)
    local frame = create("Frame", {
        Name = "Marker",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(MARKER_W, MARKER_H),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = markerLayer,
    })
    local scale = create("UIScale", { Scale = 0, Parent = frame })
    local pill = create("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = COLORS.Dark,
        BackgroundTransparency = 0.15,
        Parent = frame,
    })
    create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = pill })
    create("UIStroke", { Color = color, Thickness = 2.5, Parent = pill })
    makeText(pill, {
        Text = label,
        Position = UDim2.fromOffset(0, 4),
        Size = UDim2.new(1, 0, 0, 16),
        TextSize = 14,
        TextColor3 = color,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local distanceLabel = makeText(pill, {
        Text = "",
        Position = UDim2.fromOffset(0, 19),
        Size = UDim2.new(1, 0, 0, 24),
        TextSize = 21,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    local arrow = create("TextLabel", {
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
    create("UIStroke", { Color = COLORS.Outline, Thickness = 2, Parent = arrow })
    return { frame = frame, scale = scale, dist = distanceLabel, arrow = arrow }
end

local function markerIn(marker)
    task.delay(0.3, function() -- after the card has landed
        if marker.frame.Parent then
            tween(marker.scale, 0.35, { Scale = stackScale.Scale }, Enum.EasingStyle.Back, EASE_OUT)
        end
    end)
end

local function markerOut(marker)
    if not marker or not marker.frame.Parent then
        return
    end
    tween(marker.scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, EASE_IN).Completed:Once(function()
        marker.frame:Destroy()
    end)
end

-- The victim's waypoint follows the thief's character when it is streamed in, else the last "Pos" from the server.
local function victimTarget(steal)
    local thief = Players:GetPlayerByUserId(steal.thiefUserId)
    local thiefRoot = thief and thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
    return thiefRoot and thiefRoot.Position or steal.pos
end

-- wraps an angle in radians into [-pi, pi)
local function wrapAngle(angle)
    return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- Updates the card's distance text + compass arrow and the on-screen waypoint marker for one steal.
local function updateGuide(steal, camera, root, target)
    local rootPos = root.Position
    local meters = (target - rootPos).Magnitude * UI.MetersPerStud
    local text = string.format("%dm", math.floor(meters + 0.5))
    if text ~= steal.lastText then
        steal.lastText = text
        steal.card.dist.Text = text
        steal.marker.dist.Text = text
    end

    -- compass arrow in the card: bearing of the target relative to where the camera looks
    local look = camera.CFrame.LookVector
    local cameraHeading = math.atan2(look.X, look.Z)
    local targetHeading = math.atan2(target.X - rootPos.X, target.Z - rootPos.Z)
    steal.card.arrow.Rotation = -math.deg(wrapAngle(targetHeading - cameraHeading))

    -- waypoint marker: pinned over the target, or clamped to the screen edge pointing at it (even when behind you)
    local marker = steal.marker
    local viewport = camera.ViewportSize
    local uiScale = stackScale.Scale
    -- keep clear of the card, SETTINGS button, hotbar, thumbs
    local left, right, top, bottom = 80 * uiScale, viewport.X - 215 * uiScale, 130 * uiScale, viewport.Y - 130 * uiScale
    local aim = target + Vector3.new(0, 7, 0)
    local screenPoint, onScreen = camera:WorldToViewportPoint(aim)
    local inside = onScreen
        and screenPoint.X >= left
        and screenPoint.X <= right
        and screenPoint.Y >= top
        and screenPoint.Y <= bottom
    if inside then
        marker.frame.Position = UDim2.fromOffset(screenPoint.X, screenPoint.Y)
        marker.arrow.Position = UDim2.new(0.5, 0, 1, 18)
        marker.arrow.Rotation = 180
    else
        -- direction in camera space works for targets behind the camera too (WorldToViewportPoint flips those)
        local relative = camera.CFrame:PointToObjectSpace(aim)
        local direction = Vector2.new(relative.X, -relative.Y)
        direction = direction.Magnitude > 1e-3 and direction.Unit or Vector2.new(0, 1)
        local safeCenter, halfWidth, halfHeight =
            Vector2.new((left + right) / 2, (top + bottom) / 2), (right - left) / 2, (bottom - top) / 2
        -- scale the direction until it hits the safe rectangle's border
        local edgeDistance = math.min(
            halfWidth / math.max(math.abs(direction.X), 1e-4),
            halfHeight / math.max(math.abs(direction.Y), 1e-4)
        )
        local edgePoint = safeCenter + direction * edgeDistance
        marker.frame.Position = UDim2.fromOffset(edgePoint.X, edgePoint.Y)
        marker.arrow.Position =
            UDim2.new(0.5, direction.X * (MARKER_W / 2 + 16), 0.5, direction.Y * (MARKER_H / 2 + 16))
        marker.arrow.Rotation = math.deg(math.atan2(direction.Y, direction.X)) + 90
    end
    marker.frame.Visible = true
end

-- ═══════════════════════════ the one per-frame loop ═══════════════════════════
local function step(dt)
    local camera = workspace.CurrentCamera
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local now = os.clock()

    -- red danger pulse around the screen edges
    local pulseState = danger
    pulseState.level += math.clamp(pulseState.target - pulseState.level, -dt * 3.3, dt * 3.3)
    if pulseState.level > 0.001 then
        local ramp = math.clamp((now - pulseState.since) / UI.PulseRampSeconds, 0, 1)
        pulseState.phase += dt * math.pi * 2 / lerp(UI.PulseSlow, UI.PulseFast, ramp) -- pulses get quicker the longer you run
        local pulse = isReducedMotion() and 0.5 or (0.5 + 0.5 * math.sin(pulseState.phase))
        local opacity = lerp(UI.VignetteOpacityLow, UI.VignetteOpacityHigh, pulse)
        vignette.Visible = true
        vignette.GroupTransparency = 1 - opacity * pulseState.level
    elseif vignette.Visible then
        vignette.Visible = false
    end

    for _, steal in { activeSteals.thief, activeSteals.victim } do
        if steal and not steal.card.destroyed then
            if steal.card.egg then
                steal.card.egg.CFrame = CFrame.Angles(0, now * 1.6, 0)
            end
            if steal.guide and root and camera then
                local target = steal.role == "Thief" and steal.base or victimTarget(steal)
                updateGuide(steal, camera, root, target)
                steal.card.arrowScale.Scale = 1 + 0.1 * math.sin(now * 7) -- the arrow breathes: "go this way"
            end
        end
    end

    -- nothing left to animate: drop the connection until the next steal
    if not activeSteals.thief and not activeSteals.victim and pulseState.level <= 0.001 and pulseState.target == 0 then
        stepConn:Disconnect()
        stepConn = nil
    end
end

local function ensureStep()
    if not stepConn then
        stepConn = RunService.RenderStepped:Connect(step)
    end
end

-- ═══════════════════════════ camera shake / gold burst (unused) ═══════════════════════════
local function _shake(duration, magnitude)
    if isReducedMotion() then
        return
    end
    local startTime = os.clock()
    pcall(RunService.UnbindFromRenderStep, RunService, "EggStealShake")
    RunService:BindToRenderStep("EggStealShake", Enum.RenderPriority.Camera.Value + 1, function()
        local progress = (os.clock() - startTime) / duration
        if progress >= 1 then
            RunService:UnbindFromRenderStep("EggStealShake")
            return
        end
        local strength = magnitude * (1 - progress) ^ 2
        local camera = workspace.CurrentCamera
        camera.CFrame *= CFrame.new((math.random() - 0.5) * strength * 4, (math.random() - 0.5) * strength * 4, 0) * CFrame.Angles(
            (math.random() - 0.5) * strength,
            (math.random() - 0.5) * strength,
            (math.random() - 0.5) * strength * 0.6
        )
    end)
end

local function _goldBurst()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if not root then
        return
    end
    local attachment = create("Attachment", { Position = Vector3.new(0, 0.5, 0), Parent = root })
    local function emitBurst(count, speed, size, lifetime)
        local emitter = create("ParticleEmitter", {
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
            Enabled = false,
            Rate = 0,
            LightEmission = 1,
            LightInfluence = 0,
            Drag = 3,
            SpreadAngle = Vector2.new(180, 180),
            Speed = speed,
            Lifetime = lifetime,
            Rotation = NumberRange.new(0, 360),
            RotSpeed = NumberRange.new(-120, 120),
            Color = ColorSequence.new(COLORS.Gold, Color3.new(1, 1, 1)),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) }),
            Parent = attachment,
        })
        emitter:Emit(count)
    end
    emitBurst(34, NumberRange.new(14, 26), 1, NumberRange.new(0.6, 1.1))
    emitBurst(16, NumberRange.new(4, 9), 1.8, NumberRange.new(0.9, 1.4))
    Debris:AddItem(attachment, 2.2)
end

-- ═══════════════════════════ alarms ═══════════════════════════
-- unused since the thief side moved to StolenEggBanner
local function _startThiefAlarm(steal)
    task.spawn(function()
        for _ = 1, ALARM.InitialBeeps do -- BEEP — BEEP — BEEP
            if not steal.alive then
                return
            end
            playSound("Beep", ALARM.BeepVolume, ALARM.BeepSpeed)
            task.wait(ALARM.BeepGap)
        end
        while steal.alive do
            local ramp = math.clamp((os.clock() - steal.start) / UI.PulseRampSeconds, 0, 1)
            task.wait(lerp(ALARM.PulseInterval, ALARM.PulseMinInterval, ramp)) -- quiet reminder, slightly quicker over time
            if not steal.alive then
                return
            end
            playSound("Beep", ALARM.PulseVolume, ALARM.BeepSpeed - 0.15)
        end
    end)
end

-- repeats the two-tone warning until the steal ends (steal.alive = false)
local function startVictimAlarm(steal)
    task.spawn(function()
        playTwoTone(ALARM.VictimVolume)
        while steal.alive do
            task.wait(ALARM.VictimRepeat)
            if not steal.alive then
                return
            end
            playTwoTone(ALARM.VictimVolume * 0.5)
        end
    end)
end

-- ═══════════════════════════ prompt filter ═══════════════════════════
-- The server enables the prompt for everyone; here it is hidden from the egg's owner and from anyone already carrying.
-- Client-side only: hiding is cosmetic, the server re-validates every trigger.
local function applyPrompt(prompt)
    local hiddenForMe = prompt:GetAttribute("OwnerUserId") == player.UserId or activeSteals.thief ~= nil
    local shouldEnable = prompt:GetAttribute("Stealable") == true and not hiddenForMe
    if prompt.Enabled ~= shouldEnable then
        prompt.Enabled = shouldEnable
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
    for _, prompt in CollectionService:GetTagged("EggStealPrompt") do
        applyPrompt(prompt)
    end
end

-- ═══════════════════════════ THIEF ═══════════════════════════
-- instant = true hides the banner at once (replaced by a new steal); otherwise it plays the "Cancelled" outro.
local function endThief(steal, instant)
    if activeSteals.thief ~= steal then
        return
    end
    activeSteals.thief = nil
    steal.alive = false
    if instant then
        Banner.Hide()
    else
        Banner.Resolve("Cancelled")
    end
    refreshPrompts()
end

-- unused: switched the old thief card into its "STOLEN EGG" run-back look
local function _toCarryState(steal)
    local card = steal.card
    if not steal.alive or card.destroyed then
        return
    end
    tween(card.panel, 0.35, { BackgroundColor3 = COLORS.Carry })
    fadeTitle(card, 1, 0.1)
    task.delay(0.1, function()
        if card.destroyed or not steal.alive then
            return
        end
        card.title.Text = "STOLEN EGG"
        card.title.Position = UDim2.fromOffset(card.textX + 28, 6)
        card.title.Size = UDim2.fromOffset(card.textW - 28, 30)
        fadeTitle(card, 0, 0.15)
        card.badge.Visible = true
        tween(card.badgeScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back, EASE_OUT)
    end)
end

-- "Start" payload, or { id, base } rebuilt from player attributes by recoverCarry.
local function onThiefStart(stealData)
    if activeSteals.thief and activeSteals.thief.id == stealData.id then
        return -- same steal announced twice (remote + attribute recovery)
    end
    if activeSteals.thief then
        endThief(activeSteals.thief, true)
    end
    local steal = {
        role = "Thief",
        id = stealData.id,
        alive = true,
        start = os.clock(),
        base = stealData.base,
        data = stealData,
        card = {
            destroyed = true, -- no card for the thief any more; the banner shows the steal
        },
    }
    activeSteals.thief = steal
    Banner.Show(stealData.base, stealData)
    refreshPrompts()
    -- never leave the banner stuck if the "End" message is lost
    task.delay(Config.ClientFailsafeSeconds, function()
        if activeSteals.thief == steal then
            endThief(steal, false)
        end
    end)
end

-- unused: lifted the egg icon out of the card and flew it along a Bezier curve into the backpack bar
local function _flyToBackpack(_steal, card)
    if card.destroyed then
        return
    end
    local ring = card.ring
    local viewport = workspace.CurrentCamera.ViewportSize
    local fromPoint = ring.AbsolutePosition + ring.AbsoluteSize / 2
    local toPoint = Vector2.new(viewport.X / 2, viewport.Y - 48 * stackScale.Scale)
    local controlPoint =
        Vector2.new((fromPoint.X + toPoint.X) / 2, math.min(fromPoint.Y, toPoint.Y) - 140 * stackScale.Scale)
    local startScale = stackScale.Scale * card.iconScale.Scale
    ring.Parent = fxLayer -- lift the egg out of the card
    ring.AnchorPoint = Vector2.new(0.5, 0.5)
    ring.Position = UDim2.fromOffset(fromPoint.X, fromPoint.Y)
    card.iconScale.Scale = startScale
    slideOut(card, false)

    local progressValue = create("NumberValue", { Value = 0 })
    local flightConn
    flightConn = progressValue.Changed:Connect(function(alpha)
        local point = (1 - alpha) ^ 2 * fromPoint + 2 * (1 - alpha) * alpha * controlPoint + alpha * alpha * toPoint
        ring.Position = UDim2.fromOffset(point.X, point.Y)
        ring.Rotation = alpha * 20
        card.iconScale.Scale = lerp(startScale, startScale * 0.38, alpha)
    end)
    local flight = tween(progressValue, 0.62, { Value = 1 }, Enum.EasingStyle.Sine, EASE_IO)
    flight.Completed:Once(function()
        flightConn:Disconnect()
        progressValue:Destroy()
        ring:Destroy()
        -- ring pulse where the egg lands
        local pulse = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset(toPoint.X, toPoint.Y),
            Size = UDim2.fromOffset(20, 20),
            BackgroundTransparency = 1,
            Parent = fxLayer,
        })
        create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pulse })
        create("UIStroke", { Color = COLORS.Gold, Thickness = 3, Parent = pulse })
        tween(pulse, 0.45, { Size = UDim2.fromOffset(110 * stackScale.Scale, 110 * stackScale.Scale) })
        tween(pulse.UIStroke, 0.45, { Transparency = 1 })
        Debris:AddItem(pulse, 0.5)
        playSound("Chime", 0.35, 2)
    end)
end

local function securedThief(steal, _info)
    if activeSteals.thief ~= steal then
        return
    end
    steal.alive = false
    activeSteals.thief = nil
    Banner.Resolve("Secured")
    refreshPrompts()
end

-- ═══════════════════════════ OWNER ═══════════════════════════
-- "End" for the victim: result "Failed" means the thief failed (egg recovered), anything else means the egg is lost.
local function endVictim(steal, payload)
    if activeSteals.victim ~= steal then
        return
    end
    steal.alive = false
    steal.guide = false
    markerOut(steal.marker)
    local card = steal.card
    if card.destroyed then
        activeSteals.victim = nil
        return
    end
    card.badge.Visible = false
    card.compass.Visible = false
    card.dist.Visible = false
    if payload.result == "Failed" then
        playSound("Chime", 0.3, 1.4)
        tween(card.panel, 0.25, { BackgroundColor3 = COLORS.Success })
        card.title.Text = "EGG RECOVERED!"
        card.subtitle.Text = "THE THIEF FAILED"
    else
        tween(card.panel, 0.25, { BackgroundColor3 = Color3.fromRGB(78, 80, 104) })
        card.title.Text = "EGG LOST"
        card.subtitle.Text = "STOLEN BY " .. string.upper(steal.thiefName or "?")
    end
    flashCard(card, 0.3)
    task.delay(payload.result == "Failed" and 1.6 or 2.4, function()
        slideOut(card, false, function()
            if activeSteals.victim == steal then
                activeSteals.victim = nil
            end
        end)
    end)
end

local function onVictimAlert(stealData)
    if activeSteals.victim then
        local previous = activeSteals.victim
        previous.alive = false
        destroyCard(previous.card)
        markerOut(previous.marker)
        activeSteals.victim = nil
    end
    local steal = {
        role = "Victim",
        id = stealData.id,
        alive = true,
        start = os.clock(),
        pos = stealData.pos,
        thiefUserId = stealData.thiefUserId,
        thiefName = stealData.thiefName,
        lastText = "",
        guide = true,
    }
    activeSteals.victim = steal
    steal.card = buildCard("Victim", stealData)
    steal.marker = buildMarker("STOLEN EGG", COLORS.Victim)
    markerIn(steal.marker)
    ensureStep()
    startVictimAlarm(steal)
    entrance(steal.card, COLORS.Victim)
    -- never leave the card stuck if the "End" message is lost
    task.delay(Config.ClientFailsafeSeconds, function()
        if activeSteals.victim == steal then
            steal.alive = false
            destroyCard(steal.card)
            markerOut(steal.marker)
            activeSteals.victim = nil
        end
    end)
end

-- ═══════════════════════════ server messages ═══════════════════════════
-- Payloads are type-checked here because they come over the network (see the header for shapes).
local function onEvent(action, payload, position)
    if action == "Start" and typeof(payload) == "table" then
        onThiefStart(payload)
    elseif action == "Alert" and typeof(payload) == "table" then
        onVictimAlert(payload)
    elseif action == "Pos" then
        -- ("Pos", stealId, Vector3)
        local steal = activeSteals.victim
        if steal and steal.id == payload and typeof(position) == "Vector3" then
            steal.pos = position
        end
    elseif action == "End" and typeof(payload) == "table" then
        local steal = activeSteals.thief
        if steal and steal.id == payload.id then
            if payload.result == "Secured" then
                securedThief(steal, payload.info)
            else
                -- server reasons that read as "called off" rather than "you dropped it"
                local cancelledReasons = {
                    VictimGone = true,
                    HomeLost = true,
                    EggChanged = true,
                    Left = true,
                    Reset = true,
                    Cancelled = true,
                    Error = true,
                }
                activeSteals.thief = nil
                steal.alive = false
                Banner.Resolve(cancelledReasons[payload.reason] and "Cancelled" or "Dropped")
                refreshPrompts()
            end
            return
        end
        steal = activeSteals.victim
        if steal and steal.id == payload.id then
            endVictim(steal, payload)
        end
    end
end

-- ═══════════════════════════ start ═══════════════════════════
-- Idempotent. Builds the ScreenGui, preloads sounds, hooks prompts, the remote and the carry attributes.
function Client.Start()
    if started then
        return
    end
    started = true
    Banner.Start()

    gui = create("ScreenGui", {
        Name = "EggStealUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 40,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = player:WaitForChild("PlayerGui"),
    })

    vignette = create("CanvasGroup", {
        Name = "DangerPulse",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
        Visible = false,
        Parent = gui,
    })
    -- one gradient strip per screen edge, fading towards the centre
    local function makeEdge(anchor, position, size, rotation)
        local edgeFrame = create("Frame", {
            AnchorPoint = anchor,
            Position = position,
            Size = size,
            BackgroundColor3 = COLORS.Danger,
            BorderSizePixel = 0,
            Parent = vignette,
        })
        create("UIGradient", {
            Rotation = rotation,
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
            Parent = edgeFrame,
        })
    end
    makeEdge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.15), 90)
    makeEdge(Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.15), -90)
    makeEdge(Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.09, 1), 0)
    makeEdge(Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.09, 1), 180)

    tint = create("Frame", {
        Name = "PulseTint",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = COLORS.Danger,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Parent = gui,
    })
    markerLayer =
        create("Frame", { Name = "Markers", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
    stack = create("Frame", {
        Name = "Stack",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, UI.TopOffset),
        Size = UDim2.fromOffset(UI.CardWidth, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Parent = gui,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = stack,
    })
    stackScale = create("UIScale", { Parent = stack })
    fxLayer = create(
        "Frame",
        { Name = "FX", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = gui }
    )

    -- scale with the screen: phones get a smaller card, big monitors a slightly larger one
    local function rescale()
        local camera = workspace.CurrentCamera
        if camera then
            stackScale.Scale = math.clamp(camera.ViewportSize.Y / 900, 0.72, 1.1)
        end
    end
    rescale()
    local viewportConn
    local function hookCamera()
        if viewportConn then
            viewportConn:Disconnect()
        end
        local camera = workspace.CurrentCamera
        if camera then
            viewportConn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
        end
        rescale()
    end
    hookCamera()
    workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)

    local soundsToPreload = {}
    for name, soundId in SOUND_IDS do
        if soundId ~= "" then
            local sound = create("Sound", { Name = "EggSteal_" .. name, SoundId = soundId, Parent = gui })
            sounds[name] = sound
            table.insert(soundsToPreload, sound)
        end
    end
    task.spawn(function()
        pcall(function()
            ContentProvider:PreloadAsync(soundsToPreload)
        end)
    end)

    CollectionService:GetInstanceAddedSignal("EggStealPrompt"):Connect(watchPrompt)
    for _, prompt in CollectionService:GetTagged("EggStealPrompt") do
        watchPrompt(prompt)
    end

    local event = script.Parent:WaitForChild("Event")
    event.OnClientEvent:Connect(onEvent)
    -- Attribute mirror of the thief state: restores the banner for late joiners / script restarts, and ends a
    -- stale steal if the attribute is cleared (0.4 s grace so an "End" message arriving meanwhile wins).
    local function recoverCarry()
        local stealId = player:GetAttribute("CarryingStolenEggId")
        local base = player:GetAttribute("CarryingStolenEggBase")
        if stealId and typeof(base) == "Vector3" then
            onThiefStart({ id = stealId, base = base })
        elseif activeSteals.thief then
            local expected = activeSteals.thief
            task.delay(0.4, function()
                if activeSteals.thief == expected and not player:GetAttribute("CarryingStolenEggId") then
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
