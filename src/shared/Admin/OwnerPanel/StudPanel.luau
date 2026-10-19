--[[
    StudPanel (ModuleScript, ReplicatedStorage.OwnerPanel.StudPanel)
    The brick/stud style Owner + Admin panel UI. Required and built by OwnerPanelClient
    (src/client/Admin/OwnerPanelClient.client.luau), which rebuilds it when the PanelRole attribute changes.
    Purely visual: every button calls the server (OwnerPanelServer), which checks the role again. Hiding a
    button here is cosmetic only; the server is the authority for every action.

    Public API (contract):
        StudPanel.Colors                     the palette table (PALETTE below)
        StudPanel.Button(parent, text, color, onClick, options) -> buttonApi
            buttonApi = { face, holder, label, stroke, set(isOn, newText?), select(isOn) }
            options   = { depth, h, w, size, order, textSize, studs, nav }
        StudPanel.Build(gui, context) -> panelApi
            context  = { role = "Owner" | "Admin", userId, userName, invoke(action, args) -> (success, message|data) }
            panelApi = { open(), close(), toggle(), refresh(), show(pageId) }

    Pages (sidebar tabs): Owner gets home, players, eggs, money, temple, events, admins, saves (Restore), punish, log
    (Activity). Admin gets home, players, eggs (River Eggs), events, log. Scope buttons in the top bar pick the
    target: "me", "selected" (the player picked on the Players page) and, Owner only, "lobby" (everyone).

    Server calls (context.invoke -> OwnerPanel.Action). Every action goes through sendAction, which also fills in
    args.scope (current scope), args.userId (selected player) and args.confirmed when the caller did not set them:
        Home     GiveCash {amount = "1000000", scope = "me"}, ReturnToPublic {}, JoinStaffServer {},
                 EggShower {amount = 8}, AnnounceUpdate {}*, StartEvent {eventId = "rush", seconds = 300},
                 StopEvent {}, StartNight {seconds = 60}
        Players  Bring {}, GoTo {}, SendHome {}, Respawn {}*, Kick {userId}*, Ban {userId}*,
                 SetAdmin {userId, on}, Unban {userId = typed id}*
        Eggs     GiveEgg {itemId} / GiveCharacter {itemId} (* when scope is lobby), SpawnEgg {itemId, mutation?}
        Money    GiveCash {amount} (* when lobby), SetCash {amount}*, GiveCash {amount, scope = "lobby"}*
        Temples  UpgradeTemple {}, UnlockSlot {}, AddIncubator {}, UpgradeIncubator {index},
                 ClearInventory {}*, ClearPlaced {}*, ResetSlots {}*
        Events   StartEvent {eventId = "rush" | "cash" | "gold", seconds}, EggShower {amount = 8}, StopEvent {},
                 StartNight {seconds}, StopNight {}, Announce {text, color = "pink" | "purple", allServers},
                 AnnounceUpdate {text?}*, SetSpawnInterval {seconds = typed text}
        Admins   SetAdmin {userId, on}
        Punish   TakeCash {who, amount = number text | "all"}*, WipePlayer {who}*
        Restore  SaveRestore {who = tostring(userId), version}*
    (* = behind a confirm dialog.) Direct invokes that skip sendAction (no log row, no toast on success):
        Snapshot {} -> (success, {players, catalog, admins, event, isStaffServer}), SaveList {who} -> (success, data)

    Confirmation flow: showConfirm opens a modal over the panel. Cancel just closes it. Confirm closes it, sets the
    shared "confirmed" flag, runs onYes inside pcall (sendAction copies the flag into args.confirmed), then clears
    the flag. The server can require args.confirmed for destructive actions.
    Only one action runs at a time ("busy"); clicks during a pending call are dropped.
]]
-- ===== 1. Services, palette and fonts =====
local TweenService = game:GetService("TweenService")
local StudPanel = {}
local function rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end
-- Near-black used for text outlines and the panel's drop plate.
local INK = rgb(8, 8, 10)
-- v2 palette (Figma "Owner Panel v2"): night-purple plates, white borders, gradient + stud buttons
local PALETTE = {
    Plate = rgb(47, 35, 87),
    Plate2 = rgb(36, 27, 72),
    Card = rgb(58, 43, 110),
    Inset = rgb(13, 10, 20),
    White = rgb(255, 255, 255),
    Muted = rgb(195, 180, 230),
    Red = rgb(255, 74, 74),
    Blue = rgb(59, 120, 255),
    Green = rgb(67, 220, 78),
    Yellow = rgb(255, 201, 63),
    Purple = rgb(168, 102, 255),
    Orange = rgb(255, 160, 50),
    Teal = rgb(42, 212, 240),
    Pink = rgb(255, 99, 177),
    Grey = rgb(122, 129, 145),
}
-- Tiled stud texture laid over every brick surface.
local STUD_TEXTURE = "rbxassetid://132561191216691"
StudPanel.Colors = PALETTE
-- Rarity -> strip colour on catalog cells.
local RARITY_COLORS = {
    Common = rgb(160, 168, 184),
    Uncommon = PALETTE.Green,
    Rare = PALETTE.Blue,
    Epic = PALETTE.Purple,
    Legendary = PALETTE.Yellow,
    Mythic = PALETTE.Pink,
    Secret = PALETTE.Red,
}
-- Both fonts are FredokaOne; kept as two Font objects (title vs body text).
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local FONT_BODY = Font.new("rbxasset://fonts/families/FredokaOne.json")

-- ===== 2. Instance helpers =====
local function darken(color, amount)
    return color:Lerp(Color3.new(0, 0, 0), amount or 0.3)
end
local function lighten(color, amount)
    return color:Lerp(Color3.new(1, 1, 1), amount or 0.3)
end
-- Instance.new + assign props + optional parent (Parent set last).
local function make(className, props, parent)
    local instance = Instance.new(className)
    for key, value in pairs(props) do
        instance[key] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end
-- Corner radius is capped at 6 px for the flat brick look, whatever the caller asks.
local function addCorner(guiObject, radius)
    make("UICorner", { CornerRadius = UDim.new(0, math.min(radius or 6, 6)) }, guiObject)
end
local function addStudTexture(guiObject, transparency)
    local texture = make("ImageLabel", {
        Name = "StudTex",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUD_TEXTURE,
        ImageTransparency = transparency or 0.6,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(22, 22),
        ZIndex = guiObject.ZIndex,
    }, guiObject)
    addCorner(texture)
    return texture
end
local function addStroke(guiObject, thickness, color)
    return make(
        "UIStroke",
        { Color = color or PALETTE.White, Thickness = thickness or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
        guiObject
    )
end
-- top-to-bottom gradient like the Figma fills (object BackgroundColor3 must stay white)
local function applyGradient(guiObject, color, darkAmount)
    guiObject.BackgroundColor3 = PALETTE.White
    local gradient = guiObject:FindFirstChild("Grad") or make("UIGradient", { Name = "Grad", Rotation = 90 }, guiObject)
    gradient.Color = ColorSequence.new(color, darken(color, darkAmount or 0.5))
    return gradient
end
-- Unused: drop-shadow helper kept from an older layout.
local function _addHardShadow(parent, source, offsetY)
    local shadowFrame = make("Frame", {
        Name = "HardShadow",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Position = source.Position + UDim2.fromOffset(0, offsetY or 5),
        Size = source.Size,
        ZIndex = math.max(source.ZIndex - 1, 0),
    }, parent)
    addCorner(shadowFrame, 6)
    return shadowFrame
end
local function addPadding(guiObject, vertical, horizontal)
    make("UIPadding", {
        PaddingTop = UDim.new(0, vertical),
        PaddingBottom = UDim.new(0, vertical),
        PaddingLeft = UDim.new(0, horizontal or vertical),
        PaddingRight = UDim.new(0, horizontal or vertical),
    }, guiObject)
end
local function addVerticalList(guiObject, gap)
    return make("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }, guiObject)
end
-- Shared LayoutOrder counter; render() resets it to 0 before each page build.
local layoutOrder = 0
local function nextLayoutOrder()
    layoutOrder += 1
    return layoutOrder
end

-- ===== 3. Widgets =====
local function makeLabel(parent, text, textSize, color, font, props)
    local textLabel = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        TextSize = textSize or 16,
        TextColor3 = color or PALETTE.White,
        FontFace = font or FONT,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.XY,
    }, parent)
    if props then
        for key, value in pairs(props) do
            textLabel[key] = value
        end
    end
    return textLabel
end
local function makeTitle(parent, text, textSize, props)
    local textLabel = makeLabel(parent, text, textSize, PALETTE.White, FONT, props)
    make("UIStroke", { Color = INK, Thickness = textSize >= 24 and 3 or 2 }, textLabel)
    return textLabel
end
-- One brick stud (same look as the StudHUD buttons). Only reached via addStudRow, which is disabled.
local function makeStud(parent, color, xScale, width, height, zIndex)
    local base = make("Frame", {
        Name = "Stud",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(xScale, 0, 0, 2),
        Size = UDim2.fromOffset(width, height),
        BackgroundColor3 = darken(color, 0.18),
        BorderSizePixel = 0,
        ZIndex = zIndex,
    }, parent)
    addCorner(base, math.floor(height * 0.45))
    addStroke(base, 2.5)
    local top = make("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = lighten(color, 0.28),
        Size = UDim2.new(1, -4, 0.55, 0),
        Position = UDim2.fromOffset(2, 2),
        ZIndex = zIndex + 1,
    }, base)
    addCorner(top, math.floor(height * 0.35))
    local highlight = make("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = PALETTE.White,
        BackgroundTransparency = 0.35,
        Size = UDim2.new(0.28, 0, 0.35, 0),
        Position = UDim2.new(0.14, 0, 0.18, 0),
        ZIndex = zIndex + 2,
    }, top)
    addCorner(highlight, 99)
end
-- Disabled: returns nil straight away (the code after the early return is dead). Studs now come
-- from addStudTexture; call sites are kept so the layout stays the same.
local function addStudRow(parent, color, count, inset, studWidth, studHeight)
    do
        return nil
    end -- studs live on the surface now (studTex)
    local row = make("Frame", {
        Name = "Studs",
        BackgroundTransparency = 1,
        Size = UDim2.new(1 - inset * 2, 0, 0, 0),
        Position = UDim2.new(inset, 0, 0, 0),
        ZIndex = parent.ZIndex + 1,
    }, parent)
    for i = 1, count do
        makeStud(row, color, (i - 0.5) / count, studWidth, studHeight, parent.ZIndex + 1)
    end
    return row
end
-- 3D brick: darker side under a coloured face. Returns holder, face
local function makeBrick(parent, color, size, depth, props)
    depth = depth or 6
    local holder = make("Frame", { BackgroundTransparency = 1, Size = size }, parent)
    if props then
        for k, v in pairs(props) do
            holder[k] = v
        end
    end
    local side = make("Frame", {
        Name = "Side",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, depth),
        Size = UDim2.new(1, 0, 1, -depth),
    }, holder)
    addCorner(side, 6)
    local face = make("Frame", { Name = "Face", Size = UDim2.new(1, 0, 1, -depth) }, holder)
    addCorner(face, 6)
    addStroke(
        face,
        color == PALETTE.Inset and 2 or 3,
        color == PALETTE.Inset and darken(PALETTE.Muted, 0.4) or PALETTE.White
    )
    applyGradient(face, color)
    addStudTexture(face, color == PALETTE.Inset and 0.9 or 0.6)
    make("Frame", {
        Name = "Shine",
        BackgroundColor3 = PALETTE.White,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(4, 3),
        Size = UDim2.new(1, -8, 0, 3),
    }, face).ZIndex =
        face.ZIndex
    return holder, face
end
-- pressable 3D brick button
local function makeButton(parent, text, color, onClick, options)
    options = options or {}
    local depth = options.depth or 5
    local height = options.h or 50
    local holder = make("Frame", {
        BackgroundTransparency = 1,
        Size = options.size or UDim2.new(options.w and 0 or 1, options.w or 0, 0, height + depth),
        LayoutOrder = options.order or nextLayoutOrder(),
    }, parent)
    local side = make("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, depth),
        Size = UDim2.new(1, 0, 1, -depth),
    }, holder)
    addCorner(side, 6)
    local face = make("TextButton", { Size = UDim2.new(1, 0, 1, -depth), Text = "", AutoButtonColor = false }, holder)
    addCorner(face, 6)
    local faceStroke = addStroke(face, 3)
    local _faceGradient = applyGradient(face, color)
    addStudTexture(face)
    make("Frame", {
        BackgroundColor3 = PALETTE.White,
        BackgroundTransparency = 0.7,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(4, 3),
        Size = UDim2.new(1, -8, 0, 3),
    }, face)
    local textLabel = makeTitle(face, text, options.textSize or 18, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.55),
        TextXAlignment = Enum.TextXAlignment.Center,
        AutomaticSize = Enum.AutomaticSize.None,
        Size = UDim2.new(1, -16, 1, 0),
        TextScaled = false,
        TextWrapped = true,
    })
    if options.studs ~= false then
        addStudRow(face, color, options.studs or 2, 0.22, 22, 10)
    end
    local enabled = true
    local pressed = false
    local function setDown(isDown)
        TweenService:Create(face, TweenInfo.new(0.07), { Position = UDim2.fromOffset(0, isDown and depth - 1 or 0) })
            :Play()
    end
    face.MouseButton1Down:Connect(function()
        if enabled then
            pressed = true
            setDown(true)
        end
    end)
    face.MouseButton1Up:Connect(function()
        pressed = false
        setDown(false)
    end)
    local currentColor = color
    face.MouseLeave:Connect(function()
        if pressed then
            pressed = false
            setDown(false)
        end
        if enabled then
            applyGradient(face, currentColor)
        end
    end)
    face.MouseEnter:Connect(function()
        if enabled then
            applyGradient(face, lighten(currentColor, 0.15))
        end
    end)
    local buttonApi = { face = face, holder = holder, label = textLabel, stroke = faceStroke }
    face.Activated:Connect(function()
        if enabled and onClick then
            onClick(buttonApi)
        end
    end)
    function buttonApi.set(isOn, newText)
        enabled = isOn
        applyGradient(face, isOn and currentColor or PALETTE.Grey)
        textLabel.TextTransparency = isOn and 0 or 0.4
        if newText then
            textLabel.Text = newText
        end
    end
    -- nav / scope style: unselected = dark night plate, selected = its own colour
    function buttonApi.select(isOn)
        if options.nav then
            currentColor = isOn and color or PALETTE.Card
            applyGradient(face, currentColor, isOn and 0.5 or 0.4)
            faceStroke.Thickness = isOn and 3 or 2
            faceStroke.Transparency = isOn and 0 or 0.3
        else
            faceStroke.Thickness = isOn and 4 or 3
            faceStroke.Color = isOn and PALETTE.Yellow or PALETTE.White
        end
    end
    return buttonApi
end
StudPanel.Button = makeButton
-- Auto-height UIGridLayout container with fixed cell size.
local function makeGrid(parent, cellW, cellH)
    local gridFrame = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = nextLayoutOrder(),
    }, parent)
    make("UIGridLayout", {
        CellSize = UDim2.fromOffset(cellW, cellH),
        CellPadding = UDim2.fromOffset(12, 14),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, gridFrame)
    return gridFrame
end
-- brick card with a coloured title strip + studs
local function makeCard(parent, text, color, subtitle)
    color = color or PALETTE.Blue
    local holder = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = nextLayoutOrder(),
    }, parent)
    local body = make("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }, holder)
    addCorner(body, 6)
    addStroke(body, 4)
    applyGradient(body, PALETTE.Card, 0.45)
    local head = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 0 }, body)
    local dot = make("Frame", { Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(14, 14) }, head)
    addCorner(dot, 3)
    applyGradient(dot, color)
    addStroke(dot, 2, INK)
    makeTitle(head, string.upper(text), 18, { Position = UDim2.fromOffset(40, 10) })
    if subtitle then
        makeLabel(
            head,
            subtitle,
            14,
            PALETTE.Muted,
            FONT_BODY,
            { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 13) }
        )
    end
    addVerticalList(body, 0)
    local inner = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
    }, body)
    addPadding(inner, 16)
    addVerticalList(inner, 12)
    return inner
end
-- Text box; numeric = strip every non-digit character as the user types.
local function makeInput(parent, placeholder, numeric)
    local textBox = make("TextBox", {
        BackgroundColor3 = PALETTE.Inset,
        BackgroundTransparency = 0.35,
        PlaceholderText = placeholder,
        Text = "",
        FontFace = FONT,
        TextSize = 20,
        TextColor3 = PALETTE.White,
        PlaceholderColor3 = PALETTE.Grey,
        ClearTextOnFocus = false,
        Size = UDim2.new(1, 0, 0, 50),
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = nextLayoutOrder(),
    }, parent)
    addCorner(textBox, 6)
    addStroke(textBox, 2, darken(PALETTE.Muted, 0.4))
    make("UIPadding", { PaddingLeft = UDim.new(0, 16) }, textBox)
    if numeric then
        textBox:GetPropertyChangedSignal("Text"):Connect(function()
            local digitsOnly = textBox.Text:gsub("[^%d]", "")
            if digitsOnly ~= textBox.Text then
                textBox.Text = digitsOnly
            end
        end)
    end
    return textBox
end

-- Quick amount presets (1K .. 1T) that fill amountBox; used by the Money and Punish pages.
local function addAmountPresets(parent, amountBox)
    local presetGrid = makeGrid(parent, 130, 58)
    for _, preset in ipairs({ { "1K", 1e3 }, { "100K", 1e5 }, { "1M", 1e6 }, { "1B", 1e9 }, { "1T", 1e12 } }) do
        makeButton(presetGrid, preset[1], PALETTE.Yellow, function()
            amountBox.Text = tostring(preset[2])
        end, { h = 46, studs = 1 })
    end
end

-- ===== 4. Formatting =====
-- 1234567 -> "1.23M" (2 decimals, trailing zeros removed); below 1000 -> floored integer.
local function formatNumber(value)
    value = tonumber(value) or 0
    for _, unit in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
        if value >= unit[1] then
            return (string.format("%.2f", value / unit[1]):gsub("0+$", ""):gsub("%.$", "")) .. unit[2]
        end
    end
    return tostring(math.floor(value))
end

-- ===== 5. Panel builder =====
function StudPanel.Build(gui, context)
    -- ----- 5.1 State -----
    -- snapshot: last Snapshot reply. logRows: newest-first activity log (max 50). scope: "me" | "selected" | "lobby".
    local isOwner = context.role == "Owner"
    local accent = isOwner and PALETTE.Red or PALETTE.Blue
    local snapshot = { players = {}, catalog = {}, admins = {} }
    local logRows = {}
    local scope, selectedId = "me", context.userId
    local currentPage = "home"
    make("Frame", {
        Name = "Dim",
        BackgroundColor3 = rgb(10, 12, 20),
        BackgroundTransparency = 0.35,
        Size = UDim2.fromScale(1, 1),
    }, gui)
    -- ----- 5.2 Frame: dim backdrop, panel root, viewport fit, plate -----
    local PANEL_WIDTH, PANEL_HEIGHT = 1180, 730
    local panelRoot = make("Frame", {
        Name = "Panel",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
        BackgroundTransparency = 1,
    }, gui)
    local uiScale = make("UIScale", {}, panelRoot)
    -- Scale the fixed 1180x730 design down to the viewport (never above 1, never below 0.3).
    local function refitToViewport()
        local viewport = workspace.CurrentCamera.ViewportSize
        uiScale.Scale =
            math.clamp(math.min((viewport.X - 20) / PANEL_WIDTH, (viewport.Y - 30) / (PANEL_HEIGHT + 12)), 0.3, 1)
    end
    -- Never disconnected: a rebuilt panel leaves this connection behind (see findings).
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refitToViewport)
    refitToViewport()
    make(
        "Frame",
        { BackgroundColor3 = INK, Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 1, 0) },
        panelRoot
    ).ZIndex =
        0
    local plate = make("Frame", { Size = UDim2.fromScale(1, 1), ClipsDescendants = true }, panelRoot)
    addCorner(plate, 8)
    addStroke(plate, 6)
    applyGradient(plate, PALETTE.Plate, 0.55)
    addStudTexture(plate, 0.75)
    for _, child in ipairs(panelRoot:GetChildren()) do
        if child:IsA("Frame") and child.BackgroundColor3 == INK then
            addCorner(child, 8)
        end
    end
    -- ----- 5.3 Top bar: crown, title, role badge, target pill, scope + close buttons -----
    -- top bar (dark header, crown, role badge)
    local topBar = make("Frame", { Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 96) }, plate)
    applyGradient(topBar, rgb(43, 43, 51), 0.65)
    addStudTexture(topBar, 0.7)
    make("Frame", {
        BackgroundColor3 = PALETTE.White,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -6),
        Size = UDim2.new(1, 0, 0, 6),
    }, topBar)
    makeLabel(topBar, "👑", 40, PALETTE.Yellow, FONT, { Position = UDim2.fromOffset(22, 18) })
    local _titleLabel =
        makeTitle(topBar, isOwner and "OWNER PANEL" or "ADMIN PANEL", 40, { Position = UDim2.fromOffset(80, 14) })
    local badge = make("Frame", {
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 38),
        Position = UDim2.fromOffset(isOwner and 380 or 370, 26),
    }, topBar)
    addCorner(badge, 6)
    addStroke(badge, 3)
    applyGradient(badge, isOwner and PALETTE.Yellow or PALETTE.Blue)
    addStudTexture(badge)
    addPadding(badge, 0, 16)
    makeTitle(
        badge,
        isOwner and "OWNER" or "ADMIN",
        20,
        { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) }
    )
    makeLabel(
        topBar,
        "Hatch an Anime  ·  server control",
        16,
        PALETTE.Muted,
        FONT_BODY,
        { Position = UDim2.fromOffset(24, 70), Visible = false }
    )
    local topRight = make("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, -1),
        Size = UDim2.fromOffset(640, 56),
    }, topBar)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, topRight)
    local targetPill = make("Frame", {
        BackgroundColor3 = PALETTE.Inset,
        BackgroundTransparency = 0.4,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.fromOffset(0, 40),
        LayoutOrder = 1,
    }, topRight)
    addCorner(targetPill, 6)
    addStroke(targetPill, 2, darken(PALETTE.Muted, 0.4))
    addPadding(targetPill, 0, 14)
    local targetText = makeTitle(
        targetPill,
        "",
        16,
        { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), AutomaticSize = Enum.AutomaticSize.XY }
    )
    local scopeBtns = {}
    local content -- forward
    local render
    local _closeButton
    -- ----- 5.4 Sidebar and scrolling content area -----
    -- sidebar + content plates
    local _sideBackground = make("Frame", {
        BackgroundColor3 = PALETTE.Inset,
        BackgroundTransparency = 0.65,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 96),
        Size = UDim2.new(0, 262, 1, -96),
    }, plate)
    local sidebar = make(
        "Frame",
        { BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 112), Size = UDim2.new(0, 230, 1, -126) },
        plate
    )
    addVerticalList(sidebar, 8)
    local contentArea = make(
        "Frame",
        { BackgroundTransparency = 1, Position = UDim2.fromOffset(270, 100), Size = UDim2.new(1, -280, 1, -108) },
        plate
    )
    content = make("ScrollingFrame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 8,
        ScrollBarImageColor3 = accent,
        BorderSizePixel = 0,
    }, contentArea)
    addPadding(content, 22, 20)
    addVerticalList(content, 22)
    -- ----- 5.5 Toast, server actions, confirm dialog -----
    -- toast
    local toastHolder = make("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -18),
        Size = UDim2.fromOffset(560, 64),
        Visible = false,
        ZIndex = 40,
    }, panelRoot)
    local toastFace = make("Frame", { Size = UDim2.new(1, 0, 0, 58), ZIndex = 41 }, toastHolder)
    addCorner(toastFace, 6)
    addStroke(toastFace, 3)
    applyGradient(toastFace, PALETTE.Green)
    local toastText = makeTitle(toastFace, "", 17, {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 42,
        AutomaticSize = Enum.AutomaticSize.None,
        Size = UDim2.new(1, -24, 1, 0),
        TextWrapped = true,
    })
    local toastId = 0
    -- Slide-in result banner; the id check makes only the newest toast hide itself after 2.8 s.
    local function showToast(success, message)
        toastId += 1
        local thisToastId = toastId
        applyGradient(toastFace, success and PALETTE.Green or PALETTE.Red)
        toastText.Text = (success and "✓  " or "✕  ") .. message
        toastHolder.Visible = true
        toastHolder.Position = UDim2.new(0.5, 0, 1, 10)
        TweenService
            :Create(toastHolder, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 1, -18) })
            :Play()
        task.delay(2.8, function()
            if thisToastId == toastId then
                toastHolder.Visible = false
            end
        end)
    end
    -- busy: an action is in flight. confirmed: true only while a confirmed onYes runs (see header).
    local busy = false
    local confirmed = false
    -- Single entry point for panel actions: disables the source button, fills scope/userId/confirmed,
    -- invokes the server, logs the result and shows a toast. Returns (success, message).
    local function sendAction(action, args, logLabel, sourceButton)
        if busy then
            return
        end
        busy = true
        local previousText = sourceButton and sourceButton.label.Text
        if sourceButton then
            sourceButton.set(false, "...")
        end
        args = args or {}
        args.confirmed = confirmed or args.confirmed
        args.scope = args.scope or scope
        args.userId = args.userId or selectedId
        local callOk, success, message = pcall(context.invoke, action, args)
        busy = false
        if sourceButton then
            sourceButton.set(true, previousText)
        end
        if not callOk then
            success, message = false, "Server didn't respond"
        end
        message = type(message) == "string" and message or (success and "Done" or "Failed")
        table.insert(logRows, 1, { time = os.date("%H:%M"), action = logLabel or action, ok = success, msg = message })
        if #logRows > 50 then
            table.remove(logRows)
        end
        showToast(success, message)
        return success, message
    end
    -- Re-fetch players/catalog/admins/event state; keeps the old snapshot when the call fails.
    local function refreshSnapshot()
        local callOk, success, data = pcall(context.invoke, "Snapshot", {})
        if callOk and success and type(data) == "table" then
            snapshot = data
        end
    end
    local function getSelectedPlayer()
        for _, playerInfo in ipairs(snapshot.players) do
            if playerInfo.userId == selectedId then
                return playerInfo
            end
        end
    end
    -- Modal confirm dialog. Its descendants get +51 ZIndex so it draws above the panel.
    local function showConfirm(heading, text, onYes)
        local overlay = make("TextButton", {
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = rgb(10, 12, 20),
            BackgroundTransparency = 0.35,
            Size = UDim2.fromScale(1, 1),
            ZIndex = 50,
        }, panelRoot)
        addCorner(overlay, 18)
        local dialog = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(460, 0),
            AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            ZIndex = 51,
        }, overlay)
        local dialogBody = makeCard(dialog, heading, PALETTE.Red)
        makeLabel(
            dialogBody,
            text,
            17,
            PALETTE.Muted,
            FONT_BODY,
            { TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) }
        )
        local buttonRow = makeGrid(dialogBody, 200, 62)
        makeButton(buttonRow, "Cancel", PALETTE.Grey, function()
            overlay:Destroy()
        end)
        makeButton(buttonRow, "Confirm", PALETTE.Red, function()
            overlay:Destroy()
            confirmed = true
            local callOk, err = pcall(onYes)
            confirmed = false
            if not callOk then
                showToast(false, tostring(err))
            end
        end)
        for _, descendant in ipairs(overlay:GetDescendants()) do
            if descendant:IsA("GuiObject") then
                descendant.ZIndex = descendant.ZIndex + 51
            end
        end
    end
    -- Page title + subtitle. The subtitle is moved next to the title one frame later, once the
    -- title's AbsoluteSize is known (divided by the UIScale to get unscaled offsets).
    local function addPageHeader(text, subtitle)
        local headerFrame = make(
            "Frame",
            { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), LayoutOrder = nextLayoutOrder() },
            content
        )
        local titleLabel = makeTitle(headerFrame, text, 34)
        local subtitleLabel =
            makeLabel(headerFrame, subtitle, 16, PALETTE.Muted, FONT_BODY, { Position = UDim2.fromOffset(0, 12) })
        task.defer(function()
            subtitleLabel.Position =
                UDim2.fromOffset(titleLabel.AbsoluteSize.X / math.max(uiScale.Scale, 0.01) + 18, 14)
        end)
    end
    local function roleColor(role)
        return role == "Owner" and PALETTE.Red or role == "Admin" and PALETTE.Blue or PALETTE.Grey
    end
    -- One clickable row on the Players page; clicking selects that player (scope "me" for yourself).
    local function addPlayerRow(pickCard, playerInfo)
        local isSelected = playerInfo.userId == selectedId
        local _row, face = makeBrick(
            pickCard,
            isSelected and PALETTE.Purple or PALETTE.Inset,
            UDim2.new(1, 0, 0, 72),
            5,
            { LayoutOrder = nextLayoutOrder() }
        )
        local hitbox = make("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, face)
        local avatar = make("ImageLabel", {
            Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60"):format(playerInfo.userId),
            BackgroundColor3 = PALETTE.Plate,
            Position = UDim2.fromOffset(10, 8),
            Size = UDim2.fromOffset(50, 50),
        }, face)
        addCorner(avatar, 10)
        addStroke(avatar, 2.5)
        makeTitle(face, playerInfo.name, 19, { Position = UDim2.fromOffset(72, 10) })
        makeLabel(
            face,
            "@" .. playerInfo.user .. "  •  " .. playerInfo.userId,
            14,
            PALETTE.Muted,
            FONT_BODY,
            { Position = UDim2.fromOffset(72, 38) }
        )
        if playerInfo.role then
            local roleTag = make("Frame", {
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -14, 0.5, 0),
                Size = UDim2.fromOffset(0, 32),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = roleColor(playerInfo.role),
            }, face)
            addCorner(roleTag, 8)
            addStroke(roleTag, 2.5)
            addPadding(roleTag, 0, 12)
            makeTitle(
                roleTag,
                playerInfo.role:upper(),
                15,
                { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0) }
            )
        end
        hitbox.Activated:Connect(function()
            selectedId = playerInfo.userId
            scope = (playerInfo.userId == context.userId) and "me" or "selected"
            render()
        end)
    end
    local pages = {}

    -- ----- 5.6 Pages (pages[pageId] builds the content area) -----
    pages.home = function()
        addPageHeader(
            "Home",
            snapshot.isStaffServer and "🔒 Staff Private Server (Restricted)" or "Live view of this server"
        )
        local statGrid = makeGrid(content, 205, 96)
        local selectedPlayer = getSelectedPlayer()
        local stats = {
            { "PLAYERS", tostring(#snapshot.players), PALETTE.Blue },
            { "SELECTED", selectedPlayer and selectedPlayer.name or "-", PALETTE.Purple },
            { "EVENT", (snapshot.event and snapshot.event ~= "None") and snapshot.event or "None", PALETTE.Orange },
            { "YOUR ROLE", context.role, accent },
        }
        for _, stat in ipairs(stats) do
            local _holder, face = makeBrick(statGrid, stat[3], UDim2.fromOffset(205, 96))
            addStudRow(face, stat[3], 3, 0.14, 26, 11)
            makeTitle(face, stat[1], 14, { Position = UDim2.fromOffset(16, 12) })
            makeTitle(face, stat[2], 30, {
                Position = UDim2.fromOffset(16, 36),
                AutomaticSize = Enum.AutomaticSize.None,
                Size = UDim2.new(1, -24, 0, 40),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
        end
        local quickCard = makeCard(content, "Quick actions", PALETTE.Yellow)
        local quickGrid = makeGrid(quickCard, 250, 62)
        if isOwner then
            makeButton(quickGrid, "Give $1M to me", PALETTE.Green, function(buttonApi)
                sendAction("GiveCash", { amount = "1000000", scope = "me" }, "Give $1M", buttonApi)
            end)
        end
        if snapshot.isStaffServer then
            makeButton(quickGrid, "Return to Public", PALETTE.Grey, function(buttonApi)
                sendAction("ReturnToPublic", {}, "Public Server", buttonApi)
            end)
        else
            makeButton(quickGrid, "Join Staff Server", PALETTE.Purple, function(buttonApi)
                sendAction("JoinStaffServer", {}, "Staff Server", buttonApi)
            end)
        end
        makeButton(quickGrid, "Egg Shower", PALETTE.Teal, function(buttonApi)
            sendAction("EggShower", { amount = 8 }, "Egg Shower", buttonApi)
        end)
        makeButton(quickGrid, "🚨 Update & Rejoin", PALETTE.Yellow, function()
            showConfirm(
                "Trigger Game Update?",
                "Announce update across ALL servers and make all players safely rejoin to load the new version?",
                function()
                    sendAction("AnnounceUpdate", {}, "Update & Rejoin")
                end
            )
        end)
        makeButton(quickGrid, "Start Egg Rush 5m", PALETTE.Orange, function(buttonApi)
            sendAction("StartEvent", { eventId = "rush", seconds = 300 }, "Egg Rush", buttonApi)
        end)
        makeButton(quickGrid, "Stop event", PALETTE.Red, function(buttonApi)
            sendAction("StopEvent", {}, "Stop event", buttonApi)
        end)
        makeButton(quickGrid, "Start Nighttime", PALETTE.Purple, function(buttonApi)
            sendAction("StartNight", { seconds = 60 }, "Start Nighttime", buttonApi)
        end)
        makeButton(quickGrid, "Find a player", PALETTE.Blue, function()
            currentPage = "players"
            render()
        end)
    end
    pages.players = function()
        addPageHeader("Players", #snapshot.players .. " in this server")
        local pickCard = makeCard(content, "Pick a player", PALETTE.Blue)
        for _, playerInfo in ipairs(snapshot.players) do
            addPlayerRow(pickCard, playerInfo)
        end
        local selectedPlayer = getSelectedPlayer()
        local teleportCard = makeCard(
            content,
            "Teleport",
            PALETTE.Teal,
            selectedPlayer and ("Selected: " .. selectedPlayer.name) or "Select a player"
        )
        local teleportGrid = makeGrid(teleportCard, 250, 62)
        makeButton(teleportGrid, "Bring to me", PALETTE.Teal, function(buttonApi)
            sendAction("Bring", {}, "Bring", buttonApi)
        end)
        makeButton(teleportGrid, "Go to them", PALETTE.Teal, function(buttonApi)
            sendAction("GoTo", {}, "Go to player", buttonApi)
        end)
        makeButton(teleportGrid, "Send home", PALETTE.Teal, function(buttonApi)
            sendAction("SendHome", {}, "Send home", buttonApi)
        end)
        makeButton(teleportGrid, "Respawn", PALETTE.Orange, function()
            local selectedNow = getSelectedPlayer()
            if selectedNow then
                showConfirm("Respawn " .. selectedNow.name .. "?", "Their character will restart.", function()
                    sendAction("Respawn", {}, "Respawn")
                end)
            end
        end)
        local moderationCard = makeCard(content, "Moderation", PALETTE.Red)
        local moderationGrid = makeGrid(moderationCard, 250, 62)
        local canPunish = selectedPlayer and not selectedPlayer.role
        local kickButton = makeButton(moderationGrid, "Kick", PALETTE.Red, function()
            local selectedNow = getSelectedPlayer()
            if selectedNow then
                showConfirm(
                    "Kick " .. selectedNow.name .. "?",
                    "They are removed from this server and can rejoin.",
                    function()
                        sendAction("Kick", { userId = selectedNow.userId }, "Kick")
                        refreshSnapshot()
                        render()
                    end
                )
            end
        end)
        kickButton.set(canPunish and true or false)
        if isOwner then
            local banButton = makeButton(moderationGrid, "Ban 24 hours", darken(PALETTE.Red, 0.25), function()
                local selectedNow = getSelectedPlayer()
                if selectedNow then
                    showConfirm(
                        "Ban " .. selectedNow.name .. " for 24 hours?",
                        "Roblox ban. Only works in the published game.",
                        function()
                            sendAction("Ban", { userId = selectedNow.userId }, "Ban 24h")
                        end
                    )
                end
            end)
            banButton.set(canPunish and true or false)
            if selectedPlayer and selectedPlayer.userId ~= context.userId and selectedPlayer.role ~= "Owner" then
                local isAdmin = selectedPlayer.role == "Admin"
                makeButton(moderationGrid, isAdmin and "Remove admin" or "Make admin", PALETTE.Blue, function(buttonApi)
                    sendAction(
                        "SetAdmin",
                        { userId = selectedPlayer.userId, on = not isAdmin },
                        isAdmin and "Remove admin" or "Make admin",
                        buttonApi
                    )
                    refreshSnapshot()
                    render()
                end)
            end
            local unbanBox = makeInput(moderationCard, "User ID to unban", true)
            makeButton(moderationCard, "Unban", PALETTE.Grey, function()
                if unbanBox.Text ~= "" then
                    showConfirm("Unban " .. unbanBox.Text .. "?", "Removes their active ban.", function()
                        sendAction("Unban", { userId = unbanBox.Text }, "Unban")
                    end)
                end
            end, { w = 250 })
        end
        if not canPunish then
            makeLabel(
                moderationCard,
                "Staff can't be kicked or banned. Pick a normal player.",
                15,
                PALETTE.Muted,
                FONT_BODY,
                { LayoutOrder = nextLayoutOrder() }
            )
        end
    end
    -- Mutation used by "Drop in river" on the Eggs page; survives page re-renders.
    local riverMutation = "None"
    -- Owner-only Eggs card: pick an egg + Halloween tier, then DROP IN RIVER sends SpawnEgg {itemId, mutation = tier}.
    local function addHalloweenDropCard()
        local halloweenCard =
            makeCard(content, "Halloween eggs: drop in river", PALETTE.Orange, "Pick one, then press Drop")
        local HALLOWEEN_TIERS = {
            { "Silver", PALETTE.Grey },
            { "Gold", PALETTE.Yellow },
            { "Diamond", PALETTE.Teal },
            { "Rainbow", PALETTE.Pink },
        }
        local pickedEgg, pickedButton
        local pickRow = make(
            "Frame",
            { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 56), LayoutOrder = nextLayoutOrder() },
            halloweenCard
        )
        local pickText = makeTitle(pickRow, "Nothing picked", 20, { Position = UDim2.fromOffset(0, 16) })
        local dropHolder = make("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(260, 56),
        }, pickRow)
        local dropButton = makeButton(dropHolder, "DROP IN RIVER", PALETTE.Green, function(buttonApi)
            if pickedEgg then
                sendAction(
                    "SpawnEgg",
                    { itemId = pickedEgg.id, mutation = pickedEgg.tier },
                    "River " .. pickedEgg.tier .. " " .. pickedEgg.name,
                    buttonApi
                )
            end
        end, { size = UDim2.fromScale(1, 1), textSize = 20 })
        dropButton.set(false)
        for _, item in ipairs(snapshot.catalog) do
            if item.id ~= "Golden Pirate" then
                local itemRow = make(
                    "Frame",
                    { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 46), LayoutOrder = nextLayoutOrder() },
                    halloweenCard
                )
                makeTitle(itemRow, item.name, 17, {
                    Position = UDim2.fromOffset(0, 12),
                    AutomaticSize = Enum.AutomaticSize.None,
                    Size = UDim2.fromOffset(150, 24),
                    TextTruncate = Enum.TextTruncate.AtEnd,
                })
                local tierRow = make("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(160, 0),
                    Size = UDim2.new(1, -160, 1, 0),
                }, itemRow)
                make("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    Padding = UDim.new(0, 8),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                }, tierRow)
                for i, tier in ipairs(HALLOWEEN_TIERS) do
                    makeButton(tierRow, tier[1]:upper(), tier[2], function(buttonApi)
                        if pickedButton then
                            pickedButton.select(false)
                        end
                        pickedButton = buttonApi
                        buttonApi.select(true)
                        pickedEgg = { id = item.id, name = item.name, tier = tier[1] }
                        pickText.Text = tier[1] .. " " .. item.name .. " egg"
                        dropButton.set(true)
                    end, { w = 118, h = 36, depth = 4, order = i, textSize = 15 })
                end
            end
        end
    end
    pages.eggs = function()
        addPageHeader(
            isOwner and "Eggs & Characters" or "River Eggs",
            isOwner and "Give items or drop eggs in the river" or "Drop any egg into the river for everyone"
        )
        local chosenItem
        local selectedCard = makeCard(content, "Selected", PALETTE.Purple)
        local chosenText = makeTitle(selectedCard, "Pick an item below", 22, { LayoutOrder = nextLayoutOrder() })
        local actionGrid = makeGrid(selectedCard, 250, 62)
        local giveEggButton, giveCharacterButton
        if isOwner then
            giveEggButton = makeButton(actionGrid, "Give egg", PALETTE.Green, function(buttonApi)
                if chosenItem then
                    local function giveChosen()
                        sendAction("GiveEgg", { itemId = chosenItem.id }, "Give " .. chosenItem.name, buttonApi)
                    end
                    if scope == "lobby" then
                        showConfirm("Give egg to everyone?", chosenItem.name, giveChosen)
                    else
                        giveChosen()
                    end
                end
            end)
            giveCharacterButton = makeButton(actionGrid, "Give character", PALETTE.Yellow, function(buttonApi)
                if chosenItem then
                    local function giveChosen()
                        sendAction("GiveCharacter", { itemId = chosenItem.id }, "Give " .. chosenItem.name, buttonApi)
                    end
                    if scope == "lobby" then
                        showConfirm("Give character to everyone?", chosenItem.name, giveChosen)
                    else
                        giveChosen()
                    end
                end
            end)
            giveEggButton.set(false)
            giveCharacterButton.set(false)
        end
        local riverDropButton = makeButton(actionGrid, "Drop in river", PALETTE.Teal, function(buttonApi)
            if chosenItem then
                sendAction(
                    "SpawnEgg",
                    { itemId = chosenItem.id, mutation = riverMutation ~= "None" and riverMutation or nil },
                    "River " .. (riverMutation ~= "None" and riverMutation .. " " or "") .. chosenItem.name,
                    buttonApi
                )
            end
        end)
        riverDropButton.set(false)
        if isOwner then
            makeLabel(
                selectedCard,
                "River egg mutation (Halloween eggs)",
                15,
                PALETTE.Muted,
                FONT_BODY,
                { LayoutOrder = nextLayoutOrder() }
            )
            local mutationGrid = makeGrid(selectedCard, 130, 50)
            local mutationButtons = {}
            for _, mutation in ipairs({
                { "None", PALETTE.Purple },
                { "Silver", PALETTE.Grey },
                { "Gold", PALETTE.Yellow },
                { "Diamond", PALETTE.Teal },
                { "Rainbow", PALETTE.Pink },
            }) do
                mutationButtons[mutation[1]] = makeButton(mutationGrid, mutation[1]:upper(), mutation[2], function()
                    riverMutation = mutation[1]
                    for mutationName, mutationButton in pairs(mutationButtons) do
                        mutationButton.select(mutationName == riverMutation)
                    end
                end, { h = 40, studs = 1, textSize = 16 })
            end
            for mutationName, mutationButton in pairs(mutationButtons) do
                mutationButton.select(mutationName == riverMutation)
            end
        end
        if isOwner then
            addHalloweenDropCard()
        end
        local catalogCard = makeCard(content, "Catalog", PALETTE.Blue, #snapshot.catalog .. " items")
        local catalogGrid = makeGrid(catalogCard, 190, 84)
        for _, item in ipairs(snapshot.catalog) do
            local rarityColor = RARITY_COLORS[item.rarity] or PALETTE.Grey
            local _holder, face = makeBrick(catalogGrid, PALETTE.Inset, UDim2.fromOffset(190, 84), 5)
            make("Frame", {
                BackgroundColor3 = rarityColor,
                BorderSizePixel = 0,
                Size = UDim2.new(0, 8, 1, -16),
                Position = UDim2.fromOffset(8, 8),
            }, face)
            makeTitle(face, item.name, 17, {
                Position = UDim2.fromOffset(24, 12),
                AutomaticSize = Enum.AutomaticSize.None,
                Size = UDim2.new(1, -30, 0, 24),
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            makeLabel(face, (item.rarity or ""):upper(), 14, rarityColor, FONT, { Position = UDim2.fromOffset(24, 42) })
            local hitbox =
                make("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, face)
            hitbox.Activated:Connect(function()
                chosenItem = item
                chosenText.Text = item.name .. "  •  " .. (item.rarity or "")
                if giveEggButton then
                    giveEggButton.set(item.eggAvailable)
                    giveCharacterButton.set(item.charAvailable)
                end
                riverDropButton.set(item.eggAvailable and not item.noRiver)
                for _, cell in ipairs(catalogGrid:GetChildren()) do
                    local cellFace = cell:FindFirstChild("Face")
                    if cellFace then
                        cellFace:FindFirstChildOfClass("UIStroke").Color = INK
                    end
                end
                face:FindFirstChildOfClass("UIStroke").Color = PALETTE.White
            end)
        end
    end
    pages.money = function()
        addPageHeader("Money", "Give or set cash")
        local amountCard = makeCard(content, "Amount", PALETTE.Green)
        local amountBox = makeInput(amountCard, "Amount", true)
        amountBox.Text = "1000000"
        local preview = makeTitle(amountCard, "", 22, { LayoutOrder = nextLayoutOrder() })
        local function updatePreview()
            local amount = tonumber(amountBox.Text)
            preview.Text = amount and amount > 0 and ("$" .. formatNumber(amount)) or "Enter an amount"
        end
        amountBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
        updatePreview()
        addAmountPresets(amountCard, amountBox)
        local sendCard = makeCard(content, "Send it", PALETTE.Yellow)
        local sendGrid = makeGrid(sendCard, 250, 62)
        makeButton(sendGrid, "Give cash", PALETTE.Green, function(buttonApi)
            if scope == "lobby" then
                showConfirm("Give cash to everyone?", "Every player gets $" .. formatNumber(amountBox.Text), function()
                    sendAction("GiveCash", { amount = amountBox.Text }, "Give lobby", buttonApi)
                end)
            else
                sendAction("GiveCash", { amount = amountBox.Text }, "Give $" .. formatNumber(amountBox.Text), buttonApi)
            end
        end)
        makeButton(sendGrid, "Set exact balance", PALETTE.Orange, function()
            showConfirm("Replace balance?", "Their current cash is overwritten.", function()
                sendAction("SetCash", { amount = amountBox.Text }, "Set $" .. formatNumber(amountBox.Text))
            end)
        end)
        makeButton(sendGrid, "Give whole lobby", PALETTE.Purple, function()
            showConfirm("Give cash to everyone?", "Every player gets $" .. formatNumber(amountBox.Text), function()
                sendAction(
                    "GiveCash",
                    { amount = amountBox.Text, scope = "lobby" },
                    "Give lobby $" .. formatNumber(amountBox.Text)
                )
            end)
        end)
    end
    pages.temple = function()
        addPageHeader("Temples", "Plot of the selected player")
        local selectedPlayer = getSelectedPlayer()
        if scope == "lobby" or not selectedPlayer then
            makeCard(content, "Pick one player first (Me or Selected)", PALETTE.Grey)
            return
        end
        local plot = selectedPlayer.plot
        local templeCard = makeCard(
            content,
            selectedPlayer.name .. "'s temple",
            PALETTE.Orange,
            plot and ("Level " .. (plot.level or 1) .. "/3  •  " .. (plot.slots or 0) .. " slots") or "No plot"
        )
        local templeGrid = makeGrid(templeCard, 250, 62)
        makeButton(templeGrid, "Upgrade temple", PALETTE.Orange, function(buttonApi)
            sendAction("UpgradeTemple", {}, "Upgrade temple", buttonApi)
            refreshSnapshot()
            render()
        end)
        makeButton(templeGrid, "Unlock next slot", PALETTE.Yellow, function(buttonApi)
            sendAction("UnlockSlot", {}, "Unlock slot", buttonApi)
            refreshSnapshot()
            render()
        end)
        makeButton(templeGrid, "Add incubator", PALETTE.Teal, function(buttonApi)
            sendAction("AddIncubator", {}, "Add incubator", buttonApi)
            refreshSnapshot()
            render()
        end)
        if plot and plot.incubators then
            local incubatorCard = makeCard(content, "Incubators", PALETTE.Teal)
            local incubatorGrid = makeGrid(incubatorCard, 250, 62)
            for i, level in pairs(plot.incubators) do
                makeButton(incubatorGrid, ("#%d  Lv %d  ▲"):format(i, level), PALETTE.Teal, function(buttonApi)
                    sendAction("UpgradeIncubator", { index = i }, "Upgrade incubator " .. i, buttonApi)
                    refreshSnapshot()
                    render()
                end).set(level < 3)
            end
        end
        local cleanupCard = makeCard(content, "Clean-up", PALETTE.Red)
        local cleanupGrid = makeGrid(cleanupCard, 250, 62)
        makeButton(cleanupGrid, "Clear inventory", PALETTE.Red, function()
            showConfirm("Clear held inventory?", "Removes held eggs and characters.", function()
                sendAction("ClearInventory", {}, "Clear inventory")
            end)
        end)
        makeButton(cleanupGrid, "Clear placed", PALETTE.Red, function()
            showConfirm("Clear placed characters?", "Removes every placed character on their plot.", function()
                sendAction("ClearPlaced", {}, "Clear placed")
            end)
        end)
        makeButton(cleanupGrid, "Reset slots", PALETTE.Red, function()
            showConfirm("Reset slot unlocks?", "Locks every slot except the first.", function()
                sendAction("ResetSlots", {}, "Reset slots")
            end)
        end)
    end
    -- Event length in seconds picked on the Events page (5 / 10 / 30 min).
    local eventDuration = 300
    pages.events = function()
        addPageHeader("Events", "Start server events for everyone")
        local durationCard = makeCard(content, "How long?", PALETTE.Purple)
        local durationGrid = makeGrid(durationCard, 150, 58)
        for _, option in ipairs({ { "5 min", 300 }, { "10 min", 600 }, { "30 min", 1800 } }) do
            local durationButton = makeButton(durationGrid, option[1], PALETTE.Purple, function()
                eventDuration = option[2]
                render()
            end, { h = 46, studs = 1 })
            durationButton.select(eventDuration == option[2])
        end
        local eventCard = makeCard(
            content,
            "Events",
            PALETTE.Orange,
            (snapshot.event and snapshot.event ~= "None") and ("Running: " .. snapshot.event) or "Nothing running"
        )
        local eventGrid = makeGrid(eventCard, 250, 110)
        for _, eventDef in ipairs({
            { "rush", "EGG RUSH", "Eggs spawn 2x faster", PALETTE.Orange },
            { "cash", "DOUBLE CASH", "All income doubled", PALETTE.Green },
            { "gold", "GOLDEN HOUR", "Golden sunset", PALETTE.Yellow },
        }) do
            local eventHolder =
                make("Frame", { BackgroundTransparency = 1, LayoutOrder = nextLayoutOrder() }, eventGrid)
            addVerticalList(eventHolder, 4)
            makeButton(eventHolder, eventDef[2], eventDef[4], function(buttonApi)
                sendAction(
                    "StartEvent",
                    { eventId = eventDef[1], seconds = eventDuration },
                    "Start " .. eventDef[2],
                    buttonApi
                )
                refreshSnapshot()
            end, { h = 56 })
            makeLabel(
                eventHolder,
                eventDef[3] .. "  •  " .. math.floor(eventDuration / 60) .. " min",
                14,
                PALETTE.Muted,
                FONT_BODY,
                { LayoutOrder = nextLayoutOrder() }
            )
        end
        local extraGrid = makeGrid(eventCard, 250, 62)
        makeButton(extraGrid, "EGG SHOWER", PALETTE.Teal, function(buttonApi)
            sendAction("EggShower", { amount = 8 }, "Egg Shower", buttonApi)
        end)
        makeButton(extraGrid, "Stop event", PALETTE.Red, function(buttonApi)
            sendAction("StopEvent", {}, "Stop event", buttonApi)
            refreshSnapshot()
        end)
        makeButton(extraGrid, "START NIGHTTIME", PALETTE.Purple, function(buttonApi)
            sendAction("StartNight", { seconds = eventDuration }, "Start Nighttime", buttonApi)
        end)
        makeButton(extraGrid, "End Nighttime", PALETTE.Grey, function(buttonApi)
            sendAction("StopNight", {}, "End Nighttime", buttonApi)
        end)
        local announceCard = makeCard(content, "Announcement", PALETTE.Pink, "Shows a banner to players")
        local messageBox = makeInput(announceCard, "Write a message (optional for update)...", false)
        local announceGrid = makeGrid(announceCard, 250, 62)
        makeButton(announceGrid, "This server only", PALETTE.Pink, function(buttonApi)
            sendAction(
                "Announce",
                { text = messageBox.Text, color = "pink", allServers = false },
                "Announcement",
                buttonApi
            )
        end)
        makeButton(announceGrid, "ALL SERVERS", PALETTE.Purple, function(buttonApi)
            showConfirm(
                "Broadcast to ALL servers?",
                "Send this announcement to every live server across the game universe?",
                function()
                    sendAction(
                        "Announce",
                        { text = messageBox.Text, color = "purple", allServers = true },
                        "Global Announcement",
                        buttonApi
                    )
                end
            )
        end)
        makeButton(announceGrid, "🚨 Update & Rejoin", PALETTE.Yellow, function(buttonApi)
            showConfirm(
                "Trigger Game Update?",
                "Announce update across ALL servers and make all players safely rejoin to load the new version?",
                function()
                    sendAction(
                        "AnnounceUpdate",
                        { text = messageBox.Text ~= "" and messageBox.Text or nil },
                        "Update & Rejoin",
                        buttonApi
                    )
                end
            )
        end)
        local riverCard = makeCard(content, "River speed", PALETTE.Blue, "Seconds between eggs (1.5 - 30)")
        local riverBox = makeInput(riverCard, "e.g. 4", false)
        makeButton(riverCard, "Set river speed", PALETTE.Blue, function(buttonApi)
            sendAction(
                "SetSpawnInterval",
                { seconds = riverBox.Text },
                "River speed " .. riverBox.Text .. "s",
                buttonApi
            )
        end, { w = 250 })
    end
    pages.admins = function()
        addPageHeader("Admins", "People who can open the Admin Panel")
        local adminsCard = makeCard(content, "Current admins", PALETTE.Blue)
        if #(snapshot.admins or {}) == 0 then
            makeLabel(adminsCard, "No admins yet.", 16, PALETTE.Muted, FONT_BODY, { LayoutOrder = nextLayoutOrder() })
        end
        for _, adminInfo in ipairs(snapshot.admins or {}) do
            local _holder, face =
                makeBrick(adminsCard, PALETTE.Inset, UDim2.new(1, 0, 0, 66), 5, { LayoutOrder = nextLayoutOrder() })
            local avatar = make("ImageLabel", {
                Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60"):format(adminInfo.userId),
                BackgroundColor3 = PALETTE.Plate,
                Position = UDim2.fromOffset(10, 7),
                Size = UDim2.fromOffset(46, 46),
            }, face)
            addCorner(avatar, 10)
            addStroke(avatar, 2.5)
            makeTitle(face, adminInfo.name, 18, { Position = UDim2.fromOffset(68, 9) })
            makeLabel(
                face,
                tostring(adminInfo.userId) .. (adminInfo.fixed and "  •  set in AdminRoles script" or ""),
                14,
                PALETTE.Muted,
                FONT_BODY,
                { Position = UDim2.fromOffset(68, 35) }
            )
            do
                local isOnline = game:GetService("Players"):GetPlayerByUserId(tonumber(adminInfo.userId) or 0) ~= nil
                makeLabel(
                    face,
                    isOnline and "● ONLINE — can use the panel now" or "○ offline",
                    14,
                    isOnline and PALETTE.Green or PALETTE.Grey,
                    FONT_BODY,
                    { Position = UDim2.fromOffset(68, 53) }
                )
            end
            if not adminInfo.fixed then
                local removeHolder = make("Frame", {
                    BackgroundTransparency = 1,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -10, 0.5, 0),
                    Size = UDim2.fromOffset(130, 48),
                }, face)
                makeButton(removeHolder, "Remove", PALETTE.Red, function(buttonApi)
                    sendAction("SetAdmin", { userId = adminInfo.userId, on = false }, "Remove admin", buttonApi)
                    refreshSnapshot()
                    render()
                end, { h = 40, studs = false, size = UDim2.fromScale(1, 1), textSize = 16 })
            end
        end
        local addCard = makeCard(content, "Add an admin", PALETTE.Green, "Saved in the published game")
        local userIdBox = makeInput(addCard, "User ID", true)
        makeButton(addCard, "Add admin", PALETTE.Green, function(buttonApi)
            if userIdBox.Text ~= "" then
                sendAction("SetAdmin", { userId = userIdBox.Text, on = true }, "Add admin", buttonApi)
                refreshSnapshot()
                render()
            end
        end, { w = 250 })
        local infoCard = makeCard(content, "What admins can do", PALETTE.Grey)
        makeLabel(
            infoCard,
            "✓ Join private Staff Server (/staffserver)\n✓ Trigger game update & rejoin (/update)\n✓ Start / stop events, Egg Shower, drop eggs in the river\n✓ Announcements, river speed\n✓ Teleport, send home, respawn, kick normal players\n✕ No money, no giving eggs/characters, no bans, no temple edits",
            16,
            PALETTE.White,
            FONT_BODY,
            {
                LayoutOrder = nextLayoutOrder(),
                TextWrapped = true,
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
            }
        )
    end
    -- Text of the Punish page's player box, kept across re-renders.
    local punishWho = ""
    pages.punish = function()
        addPageHeader("Punish", "Take money or wipe a player (online or offline)")
        local selectedPlayer = getSelectedPlayer()
        if punishWho == "" and selectedPlayer and selectedPlayer.userId ~= context.userId then
            punishWho = selectedPlayer.user
        end
        local playerCard = makeCard(content, "Player", PALETTE.Red, "Username or User ID")
        local whoBox = makeInput(playerCard, "Username or User ID", false)
        whoBox.Text = punishWho
        whoBox:GetPropertyChangedSignal("Text"):Connect(function()
            punishWho = whoBox.Text
        end)
        local takeCard = makeCard(content, "Take money", PALETTE.Orange, "Their cash can't go below $0")
        local amountBox = makeInput(takeCard, "Amount to take", true)
        local preview = makeTitle(takeCard, "", 20, { LayoutOrder = nextLayoutOrder() })
        local function updatePreview()
            local amount = tonumber(amountBox.Text)
            preview.Text = amount and amount > 0 and ("Take $" .. formatNumber(amount)) or "Enter an amount"
        end
        amountBox:GetPropertyChangedSignal("Text"):Connect(updatePreview)
        updatePreview()
        addAmountPresets(takeCard, amountBox)
        local takeGrid = makeGrid(takeCard, 250, 62)
        makeButton(takeGrid, "Take amount", PALETTE.Orange, function()
            if whoBox.Text == "" or not tonumber(amountBox.Text) then
                showToast(false, "Enter a player and an amount")
                return
            end
            showConfirm(
                "Take $" .. formatNumber(amountBox.Text) .. " from " .. whoBox.Text .. "?",
                "Their cash goes down by this amount (online or offline).",
                function()
                    sendAction(
                        "TakeCash",
                        { who = whoBox.Text, amount = amountBox.Text },
                        "Take $" .. formatNumber(amountBox.Text) .. " from " .. whoBox.Text
                    )
                end
            )
        end)
        makeButton(takeGrid, "Take ALL money", PALETTE.Red, function()
            if whoBox.Text == "" then
                showToast(false, "Enter a player first")
                return
            end
            showConfirm(
                "Take ALL money from " .. whoBox.Text .. "?",
                "Their cash (and money waiting on their stands) is set to $0.",
                function()
                    sendAction("TakeCash", { who = whoBox.Text, amount = "all" }, "Take all from " .. whoBox.Text)
                end
            )
        end)
        local wipeCard = makeCard(content, "Wipe all data", PALETTE.Red, "Can't be undone here")
        makeLabel(
            wipeCard,
            "Resets their save to a brand-new player (cash, eggs, characters, temple, slots, index) and removes them from ALL leaderboards. If they're online they get kicked first. An older save can still be brought back on the Restore page.",
            15,
            PALETTE.Muted,
            FONT_BODY,
            {
                LayoutOrder = nextLayoutOrder(),
                TextWrapped = true,
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
            }
        )
        makeButton(wipeCard, "WIPE PLAYER", darken(PALETTE.Red, 0.25), function(buttonApi)
            if whoBox.Text == "" then
                showToast(false, "Enter a player first")
                return
            end
            showConfirm(
                "Wipe " .. whoBox.Text .. "?",
                "Their whole save is reset and they're removed from every leaderboard. Are you sure?",
                function()
                    sendAction("WipePlayer", { who = whoBox.Text }, "Wipe " .. whoBox.Text, buttonApi)
                end
            )
        end, { w = 250 })
    end
    -- Restore page: last searched player and the SaveList reply ({name, userId, online, versions}).
    local saveWho, saveList = "", nil
    pages.saves = function()
        addPageHeader("Restore saves", "Bring back a player's stuff from an older save (Roblox keeps ~30 days)")
        local findCard = makeCard(content, "Find player", PALETTE.Pink)
        local whoBox = makeInput(findCard, "Username or User ID", false)
        whoBox.Text = saveWho
        makeButton(findCard, "Show saves", PALETTE.Pink, function(buttonApi)
            saveWho = whoBox.Text
            if saveWho == "" then
                return
            end
            buttonApi.set(false, "Loading...")
            local callOk, success, data = pcall(context.invoke, "SaveList", { who = saveWho })
            buttonApi.set(true, "Show saves")
            if callOk and success and type(data) == "table" then
                saveList = data
                render()
            else
                showToast(false, callOk and tostring(data) or "Server didn't respond")
            end
        end, { w = 250 })
        if saveList then
            local versionsCard = makeCard(
                content,
                "@" .. saveList.name .. "'s saves (newest first)",
                PALETTE.Blue,
                saveList.online and "ONLINE: kick them before restoring" or "offline"
            )
            if #saveList.versions == 0 then
                makeLabel(
                    versionsCard,
                    "No saves found.",
                    16,
                    PALETTE.Muted,
                    FONT_BODY,
                    { LayoutOrder = nextLayoutOrder() }
                )
            end
            for i, saveVersion in ipairs(saveList.versions) do
                local _holder, face = makeBrick(
                    versionsCard,
                    i == 1 and darken(PALETTE.Blue, 0.3) or PALETTE.Inset,
                    UDim2.new(1, 0, 0, 64),
                    5,
                    { LayoutOrder = nextLayoutOrder() }
                )
                makeTitle(
                    face,
                    os.date("%d %b  %H:%M", saveVersion.time) .. (i == 1 and "  (current)" or ""),
                    18,
                    { Position = UDim2.fromOffset(14, 8) }
                )
                makeLabel(
                    face,
                    ("$%s  •  %d items  •  %d placed  •  temple %d"):format(
                        formatNumber(saveVersion.cash),
                        saveVersion.items,
                        saveVersion.placed,
                        saveVersion.temple
                    ),
                    15,
                    PALETTE.Muted,
                    FONT_BODY,
                    { Position = UDim2.fromOffset(14, 36) }
                )
                if i > 1 then
                    local restoreHolder = make("Frame", {
                        BackgroundTransparency = 1,
                        AnchorPoint = Vector2.new(1, 0.5),
                        Position = UDim2.new(1, -10, 0.5, 0),
                        Size = UDim2.fromOffset(140, 46),
                    }, face)
                    makeButton(restoreHolder, "Restore", PALETTE.Green, function()
                        showConfirm(
                            "Restore @" .. saveList.name .. "?",
                            "Their save goes back to "
                                .. os.date("%d %b %H:%M", saveVersion.time)
                                .. " ($"
                                .. formatNumber(saveVersion.cash)
                                .. ", "
                                .. saveVersion.items
                                .. " items, "
                                .. saveVersion.placed
                                .. " placed). Anything after that is replaced.",
                            function()
                                sendAction(
                                    "SaveRestore",
                                    { who = tostring(saveList.userId), version = saveVersion.version },
                                    "Restore save"
                                )
                            end
                        )
                    end, { h = 40, studs = false, size = UDim2.fromScale(1, 1), textSize = 16 })
                end
            end
        end
    end
    pages.log = function()
        addPageHeader("Activity", "Your last 50 actions this session")
        local logCard = makeCard(content, "Log", PALETTE.Grey)
        if #logRows == 0 then
            makeLabel(logCard, "Nothing yet.", 16, PALETTE.Muted, FONT_BODY, { LayoutOrder = nextLayoutOrder() })
        end
        for _, entry in ipairs(logRows) do
            local _holder, face = makeBrick(
                logCard,
                entry.ok and darken(PALETTE.Green, 0.35) or darken(PALETTE.Red, 0.3),
                UDim2.new(1, 0, 0, 48),
                4,
                { LayoutOrder = nextLayoutOrder() }
            )
            makeTitle(face, entry.time .. "   " .. entry.action, 16, { Position = UDim2.fromOffset(14, 11) })
            makeLabel(
                face,
                entry.msg,
                14,
                PALETTE.White,
                FONT_BODY,
                { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 13) }
            )
        end
    end

    -- ----- 5.7 Sidebar nav and scope buttons -----
    -- { pageId, label, colour } per sidebar tab.
    local navItems = isOwner
            and {
                { "home", "Home", PALETTE.Red },
                { "players", "Players", PALETTE.Blue },
                { "eggs", "Eggs", PALETTE.Purple },
                { "money", "Money", PALETTE.Green },
                { "temple", "Temples", PALETTE.Orange },
                { "events", "Events", PALETTE.Yellow },
                { "admins", "Admins", PALETTE.Teal },
                { "saves", "Restore", PALETTE.Pink },
                { "punish", "Punish", darken(PALETTE.Red, 0.2) },
                { "log", "Activity", PALETTE.Grey },
            }
        or {
            { "home", "Home", PALETTE.Blue },
            { "players", "Players", PALETTE.Purple },
            { "eggs", "River Eggs", PALETTE.Teal },
            { "events", "Events", PALETTE.Yellow },
            { "log", "Activity", PALETTE.Grey },
        }
    local navBtns = {}
    for i, navItem in ipairs(navItems) do
        local navButton = makeButton(sidebar, navItem[2], navItem[3], function()
            currentPage = navItem[1]
            render()
        end, { h = 50, depth = 4, order = i, textSize = 20, nav = true })
        navButton.label.TextXAlignment = Enum.TextXAlignment.Left
        navButton.label.AnchorPoint = Vector2.new(0, 0.5)
        navButton.label.Position = UDim2.new(0, 42, 0.55, 0)
        navButton.label.Size = UDim2.new(1, -50, 1, 0)
        local navDot = make("Frame", {
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 16, 0.5, 0),
            Size = UDim2.fromOffset(14, 14),
            ZIndex = navButton.face.ZIndex + 1,
        }, navButton.face)
        addCorner(navDot, 3)
        applyGradient(navDot, navItem[3])
        addStroke(navDot, 2, INK)
        navBtns[navItem[1]] = navButton
    end
    local scopeOptions = isOwner and { { "me", "Me" }, { "selected", "Selected" }, { "lobby", "Lobby" } }
        or { { "me", "Me" }, { "selected", "Selected" } }
    for i, scopeOption in ipairs(scopeOptions) do
        scopeBtns[scopeOption[1]] = makeButton(topRight, scopeOption[2], PALETTE.Purple, function()
            scope = scopeOption[1]
            if scope == "me" then
                selectedId = context.userId
            end
            render()
        end, { w = 104, h = 40, depth = 4, studs = 1, order = 1 + i, textSize = 17, nav = true })
    end
    _closeButton = makeButton(topRight, "X", PALETTE.Red, function()
        gui.Enabled = false
    end, { w = 60, h = 56, depth = 5, studs = 1, order = 10, textSize = 30 })

    -- ----- 5.8 Render and public API -----
    -- Rebuild the current page from scratch: clear content, reset LayoutOrder, sync nav/scope highlights.
    render = function()
        for _, child in ipairs(content:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        layoutOrder = 0
        for pageId, navButton in pairs(navBtns) do
            navButton.select(pageId == currentPage)
        end
        for scopeId, scopeButton in pairs(scopeBtns) do
            scopeButton.select(scopeId == scope)
        end
        local selectedPlayer = getSelectedPlayer()
        targetText.Text = scope == "lobby" and ("Target: everyone (" .. #snapshot.players .. ")")
            or scope == "me" and "Target: me"
            or (selectedPlayer and ("Target: " .. selectedPlayer.name) or "Target: nobody")
        pages[currentPage]()
        content.CanvasPosition = Vector2.zero
    end
    local panelApi = {}
    function panelApi.open()
        refreshSnapshot()
        render()
        gui.Enabled = true
        refitToViewport()
        panelRoot.Position = UDim2.new(0.5, 0, 0.5, 30)
        TweenService
            :Create(panelRoot, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) })
            :Play()
    end
    function panelApi.close()
        gui.Enabled = false
    end
    function panelApi.toggle()
        if gui.Enabled then
            panelApi.close()
        else
            panelApi.open()
        end
    end
    function panelApi.refresh()
        if gui.Enabled then
            refreshSnapshot()
            render()
        end
    end
    function panelApi.show(pageId)
        currentPage = pageId
        render()
    end
    return panelApi
end
return StudPanel

-- StudSkin texture is applied by StarterPlayerScripts.StudSkin
