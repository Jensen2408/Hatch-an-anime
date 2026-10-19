--[[ StarterGui.GameMenus.MenuLogic (LocalScript)
Opens/closes the four ForgeGUI panels and fills them with live data from ServerScriptService.GameMenu.
All positions below are fractions of each panel image, so they scale with it (except the shop, which is
laid out in pixels at a design width and scaled with its UIScale — see layoutMenus).

Panels (ImageLabel children of this ScreenGui, opened by the SideButtons whose "Panel" attribute names them):
  Index    RENDER.Index    character collection: season tabs, rarity filters, 5x3 grid, detail card
  Quests   RENDER.Quests   Daily / Weekly / Milestone quest lists with Claim buttons
  VipShop  RENDER.VipShop  Robux shop (limited deal, boosts, passes, cash packs, daily rewards)
  Plot     RENDER.Plot     "My Temple": stat cards, 12-slot grid, upgrade rows
  Every RENDER fn clears the panel's "Live" layer and rebuilds it from scratch on each refresh.

Remotes (contract documented in GameMenuServer.server.luau / GameAdapter.luau):
  ReplicatedStorage.GameMenu.Remotes.GetState  (RF)  fetchState(section) -> data | nil, message
  ReplicatedStorage.GameMenu.Remotes.Action    (RF)  runAction(name, args) -> ok   (toast shows the message)
  ReplicatedStorage.GameMenu.Remotes.Changed   (RE)  server says "your data changed" -> refresh()
  ReplicatedStorage.ShopSystem.ShopRemote      (RF)  VipShop only: "State", "Buy", "BuyMoneyLevel", "ClaimDaily"
Bindables created here (children of this ScreenGui, used by other LocalScripts):
  LocalRefresh  (fire to re-render the open panel, e.g. Plot/PromptCards)
  OpenMenu      (fire with a panel name to open it, e.g. FigmaSkin)
Cross-script globals: _G.__shopPrices  [("p"|"d") .. id] = live Robux price | false (lookup pending/failed);
  shared with any script that reads the same cache. Warmed once at start (bottom of file) and by the shop.
Attributes: panel "Fit" (UIScale for the current screen, written by layoutMenus), "Page" (Plot), card "Inner",
  workspace "HalloweenMode" / "HalloweenEndsAt", plot "OwnerUserId", slot/chamber attributes (read-only),
  ReplicatedStorage.GameMenuImages "Tile<ButtonName>" (side-button icon overrides).

Init order (all at top level, in this order — WaitForChild calls yield):
  Dim + SideButtons -> DisplayOrder hook -> responsive layout -> remotes / Config / UISound -> helpers and
  RENDER fns -> hide all panels -> refresh/close/show -> Dim click, Changed, LocalRefresh, OpenMenu ->
  side buttons (WaitForChild per panel) -> tile icons -> deferred shop price warm-up.

Contents: 1 layout · 2 shared UI primitives · 3 clean skin · 4 toast + remotes · 5 v3 cards/tabs ·
  6 Index · 7 Quests · 8 VipShop · 9 Plot (legacy pages + current) · 10 open/close + wiring · 11 price warm-up
]]

-- ===== 1. Services, root instances, responsive layout =====
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent
local dimOverlay = gui:WaitForChild("Dim")
local sideButtons = gui:WaitForChild("SideButtons")
-- Modal panels must cover HUDs from other ScreenGuis, including Settings.
local hudDisplayOrder = gui.DisplayOrder
local function updateOverlayOrder()
    gui.DisplayOrder = dimOverlay.Visible and math.max(60, hudDisplayOrder) or hudDisplayOrder
end
dimOverlay:GetPropertyChangedSignal("Visible"):Connect(updateOverlayOrder)
updateOverlayOrder()
-- Use the safe area's height as well as width: wide phones are still short.
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local SHOP_PHONE_WIDTH = 680
local closingPanel -- panel playing its close tween
local sideScale = Instance.new("UIScale")
sideScale.Name = "ResponsiveScale"
sideScale.Parent = sideButtons
local function extendDimPastInsets(screenSize)
    -- The ScreenGui sits inside the safe insets (top bar / notch), so the dim backdrop must reach
    -- past them or the screen edges stay undimmed on phones.
    local camera = workspace.CurrentCamera
    if camera then
        local topLeftInset, _bottomRightInset = game:GetService("GuiService"):GetGuiInset()
        local outsideSafeArea = camera.ViewportSize - screenSize
        local left, top = math.min(topLeftInset.X, outsideSafeArea.X), math.min(topLeftInset.Y, outsideSafeArea.Y)
        local right, bottom = math.max(0, outsideSafeArea.X - left), math.max(0, outsideSafeArea.Y - top)
        dimOverlay.AnchorPoint = Vector2.new(0, 0)
        dimOverlay.Position = UDim2.fromOffset(-left, -top)
        dimOverlay.Size = UDim2.new(1, left + right, 1, top + bottom)
    end
end
-- Sizes one panel for the current screen and stores its UIScale in the "Fit" attribute.
local function fitPanelToScreen(name, screenSize, compact)
    local panel = gui:FindFirstChild(name)
    if panel then
        local ratio = panel.UIAspectRatioConstraint.AspectRatio
        local width = math.min(1000, screenSize.X * 0.86, (screenSize.Y - 32) * ratio)
        -- The shop is laid out in pixels, so on phones it is built at a fixed design width
        -- and shrunk with its UIScale ("Fit") instead of squeezing the panel.
        local designWidth = (compact and name == "VipShop") and SHOP_PHONE_WIDTH or nil
        if designWidth then
            width = math.min(width, screenSize.X * 0.8, (screenSize.Y - 48) * ratio)
        end
        local fitScale = designWidth and width / designWidth or 1
        local builtWidth = designWidth or width
        panel.Size = UDim2.fromOffset(math.max(1, builtWidth), math.max(1, builtWidth / ratio))
        panel:SetAttribute("Fit", fitScale)
        if panel.Visible and panel ~= closingPanel then
            panel.UIScale.Scale = fitScale
        end
    end
end
local function layoutMenus()
    local screenSize = gui.AbsoluteSize
    if screenSize.X <= 0 or screenSize.Y <= 0 then
        return
    end
    extendDimPastInsets(screenSize)
    local compact = math.min(screenSize.X, screenSize.Y) < 600
    local desktopScale = compact and math.min(1, screenSize.X / 600, screenSize.Y / 560) or 1
    -- Phone buttons are 20% smaller; desktop keeps its original size.
    sideScale.Scale = compact and math.clamp(screenSize.Y * 0.15, 44, 52) / 92 or desktopScale
    sideButtons.AnchorPoint = compact and Vector2.new(0, 0) or Vector2.new(0, 0.5)
    sideButtons.Position = compact and UDim2.fromOffset(10, screenSize.X < screenSize.Y and 82 or 48)
        or UDim2.new(0, 16, 0.5, 0)
    for _, name in { "Plot", "Index", "Quests", "VipShop" } do
        fitPanelToScreen(name, screenSize, compact)
    end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutMenus)
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layoutMenus)
end
layoutMenus()
-- Remotes + shared modules (WaitForChild yields until the server/replication has created them).
local remotes = ReplicatedStorage:WaitForChild("GameMenu"):WaitForChild("Remotes")
local GetState, Action, Changed =
    remotes:WaitForChild("GetState"), remotes:WaitForChild("Action"), remotes:WaitForChild("Changed")
local Config = require(ReplicatedStorage.GameMenu.Config)
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))

-- ===== 2. Shared UI primitives: palette, create / box / text / button =====

-- DISABLED (returns immediately; nothing calls it). Kept for reference.
-- ADD STUDS: put the stud pattern inside any frame.   addStuds(frame, size, strength)
--   size = stud size in pixels (smaller = smaller studs) · strength: 0 = strong, 1 = invisible
local function _addStuds(frame, size, strength)
    do
        return
    end
    local pattern = Instance.new("ImageLabel")
    pattern.Name = "StudPattern"
    pattern.BackgroundTransparency = 1
    pattern.Image = "rbxassetid://95251902376685"
    pattern.ScaleType = Enum.ScaleType.Tile
    pattern.TileSize = UDim2.fromOffset(size or 18, size or 18)
    pattern.ImageTransparency = strength or 0.5
    pattern.Size = UDim2.fromScale(1, 1)
    pattern.ZIndex = frame.ZIndex
    local corner = frame:FindFirstChildOfClass("UICorner")
    if corner then
        corner:Clone().Parent = pattern
    end
    pattern.Parent = frame
    return pattern
end
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local INK = Color3.fromRGB(17, 23, 26) -- Check-UI outline
local CREAM = Color3.fromRGB(42, 31, 74) -- recessed card (Figma night)
local GREEN = Color3.fromRGB(67, 220, 78)
local GREY = Color3.fromRGB(122, 129, 145)
local RARITY_COLORS = {
    Common = Color3.fromRGB(150, 155, 165),
    Uncommon = Color3.fromRGB(70, 180, 70),
    Rare = Color3.fromRGB(60, 130, 230),
    Epic = Color3.fromRGB(150, 80, 220),
    Legendary = Color3.fromRGB(235, 175, 30),
}

local FX_IMAGES = {
    rays = "rbxthumb://type=Asset&id=110993746998606&w=420&h=420",
    glow = "rbxthumb://type=Asset&id=85372533044428&w=420&h=420",
    sparkle = "rbxthumb://type=Asset&id=87376394612367&w=420&h=420",
    star = "rbxthumb://type=Asset&id=81892896754419&w=420&h=420",
}
local RARITY_TIER = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
-- create(className, props, parent): new instance with `props` applied, parented last.
local function create(className, props, parent)
    local instance = Instance.new(className)
    for property, value in props do
        instance[property] = value
    end
    instance.Parent = parent
    return instance
end
-- box(parent, cx, cy, w, h, props): centred (AnchorPoint 0.5) scale-sized instance; props.Class picks the
-- class (default Frame), transparent background and ZIndex 7 unless props override them.
local function box(parent, cx, cy, w, h, props)
    props = props or {}
    local class = props.Class or "Frame"
    props.Class = nil
    props.AnchorPoint = Vector2.new(0.5, 0.5)
    props.Position = UDim2.fromScale(cx, cy)
    props.Size = UDim2.fromScale(w, h)
    props.BackgroundTransparency = props.BackgroundTransparency or 1
    props.BorderSizePixel = 0
    props.ZIndex = props.ZIndex or 7
    return create(class, props, parent)
end
-- text(parent, str, color, props): scaled Fredoka label with an outline. Dark colours are forced to white so
-- labels stay readable on the dark cards. props: Size, Position, AnchorPoint, X (alignment), ZIndex,
-- Max (max text size, default 22), Stroke (outline thickness, min 1.6).
local function text(parent, str, color, props)
    props = props or {}
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = props.Size or UDim2.fromScale(1, 1),
        Position = props.Position or UDim2.new(),
        AnchorPoint = props.AnchorPoint or Vector2.new(),
        FontFace = FONT,
        Text = str,
        TextColor3 = color or INK,
        TextScaled = true,
        TextWrapped = true,
        TextXAlignment = props.X or Enum.TextXAlignment.Center,
        ZIndex = props.ZIndex or 8,
    }, parent)
    do
        local textColor = label.TextColor3
        if 0.299 * textColor.R + 0.587 * textColor.G + 0.114 * textColor.B < 0.42 then
            label.TextColor3 = Color3.new(1, 1, 1)
        end
    end -- readable on dark cards
    create("UITextSizeConstraint", { MaxTextSize = props.Max or 22 }, label)
    create("UIStroke", { Color = INK, Thickness = math.max(props.Stroke or 0, 1.6) }, label)
    return label
end
-- button(parent, cx, cy, w, h, labelText, color): studded 3D TextButton (default green) with Click/Hover sounds.
local function button(parent, cx, cy, w, h, labelText, color)
    local textButton = box(parent, cx, cy, w, h, {
        Class = "TextButton",
        BackgroundTransparency = 0,
        BackgroundColor3 = color or GREEN,
        Text = "",
        AutoButtonColor = true,
        ZIndex = 8,
    })
    create("UIStroke", {
        Color = Color3.new(1, 1, 1),
        Thickness = 3,
        LineJoinMode = Enum.LineJoinMode.Round,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, textButton)
    create("UICorner", { CornerRadius = UDim.new(0, 10) }, textButton) -- v2
    local _studTexture = create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = "rbxassetid://132561191216691",
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(22, 22),
        ZIndex = 8,
    }, textButton)
    create(
        "UIGradient",
        { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)) },
        textButton
    )
    do
        local bevel = create("Frame", {
            BackgroundColor3 = Color3.new(0, 0, 0),
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 6),
            ZIndex = 8,
        }, textButton)
        create("UICorner", { CornerRadius = UDim.new(0, 10) }, bevel)
        local shine = create("Frame", {
            BackgroundColor3 = Color3.new(1, 1, 1),
            BackgroundTransparency = 0.7,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 8, 0, 4),
            Size = UDim2.new(1, -16, 0, 4),
            ZIndex = 8,
        }, textButton)
        create("UICorner", { CornerRadius = UDim.new(1, 0) }, shine)
    end -- 3D bevel + shine
    text(textButton, labelText, Color3.new(1, 1, 1), {
        Stroke = 2,
        ZIndex = 9,
        Size = UDim2.fromScale(0.85, 0.7),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
    })
    textButton.Activated:Connect(function()
        UISound.Play("Click")
    end)
    textButton.MouseEnter:Connect(function()
        UISound.Play("Hover")
    end)
    return textButton
end
-- Destroys every child of `layer`.
local function clear(layer)
    for _, child in layer:GetChildren() do
        child:Destroy()
    end
end
-- ===== 3. Clean skin: themed header, divider and 3D close button, applied on first open =====

-- CLEAN SKIN (Check-UI style + square studs): solid canvas, themed header, 2-tier divider, 3D close button.
local STUDS_IMAGE = "rbxassetid://132561191216691"
local SKINS = {
    Index = {
        title = "INDEX",
        grad = { Color3.fromRGB(59, 120, 255), Color3.fromRGB(11, 42, 156) },
        top = Color3.fromRGB(180, 240, 255),
        div = Color3.fromRGB(0, 50, 110),
    },
    Quests = {
        title = "QUESTS",
        grad = { Color3.fromRGB(67, 220, 78), Color3.fromRGB(11, 122, 27) },
        top = Color3.fromRGB(224, 255, 176),
        div = Color3.fromRGB(37, 96, 0),
    },
    VipShop = workspace:GetAttribute("HalloweenMode") and {
        title = "HALLOWEEN SHOP",
        grad = { Color3.fromRGB(255, 170, 30), Color3.fromRGB(240, 90, 0) },
        top = Color3.fromRGB(255, 225, 160),
        div = Color3.fromRGB(130, 50, 0),
    } or {
        title = "SHOP",
        grad = { Color3.fromRGB(255, 201, 63), Color3.fromRGB(163, 92, 0) },
        top = Color3.fromRGB(255, 200, 225),
        div = Color3.fromRGB(125, 0, 18),
    },
    Plot = {
        title = "MY TEMPLE",
        grad = { Color3.fromRGB(255, 74, 74), Color3.fromRGB(179, 0, 15) },
        top = Color3.fromRGB(255, 200, 225),
        div = Color3.fromRGB(125, 0, 18),
    },
}
-- Tiled stud texture covering `frame` (copies its UICorner).
local function studLayer(frame, tileSize, transparency)
    local studs = create("ImageLabel", {
        Name = "Studs",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUDS_IMAGE,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(tileSize, tileSize),
        ImageTransparency = transparency or 0,
        ZIndex = frame.ZIndex,
    }, frame)
    local corner = frame:FindFirstChildOfClass("UICorner")
    if corner then
        corner:Clone().Parent = studs
    end
    return studs
end
-- Idempotent: does nothing for panels without a SKINS entry or that already have a "CleanSkin" child.
local function skinPanel(panel)
    local theme = SKINS[panel.Name]
    if not theme or panel:FindFirstChild("CleanSkin") then
        return
    end
    panel.ImageTransparency = 1
    create("Frame", {
        Name = "CleanBase",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 0,
    }, panel) -- hard shadow
    local skin = create(
        "Frame",
        { Name = "CleanSkin", BackgroundColor3 = Color3.fromRGB(59, 88, 102), Size = UDim2.fromScale(1, 1), ZIndex = 1 },
        panel
    )
    create("UIStroke", {
        Color = Color3.new(1, 1, 1),
        Thickness = 5,
        LineJoinMode = Enum.LineJoinMode.Miter,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, skin)
    skin.BackgroundColor3 = Color3.new(1, 1, 1)
    create(
        "UIGradient",
        { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(47, 35, 87), Color3.fromRGB(20, 13, 43)) },
        skin
    )
    studLayer(skin, 30, 0.6) -- quiet body texture so content reads first
    -- header
    local header = create("Frame", {
        Name = "Header",
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0.15, 0),
        ZIndex = 2,
    }, skin)
    create("UIGradient", { Rotation = 90, Color = ColorSequence.new(theme.grad[1], theme.grad[2]) }, header)
    studLayer(header, 30, 0)
    local titleLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Text = theme.title,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromScale(0.6, 0.62),
        ZIndex = 4,
    }, header)
    create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 4 }, titleLabel)
    -- 2-tier shadow divider
    create("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.15, 0),
        Size = UDim2.new(1, 0, 0, 4),
        ZIndex = 3,
    }, skin)
    -- 3D beveled square close button (restyles the existing Close so its click still works)
    local closeButton = panel:FindFirstChild("Close")
    if closeButton then
        for _, child in closeButton:GetChildren() do
            if not child:IsA("UIScale") then
                child:Destroy()
            end
        end
        closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
        closeButton.Position = UDim2.new(1, -30, 0.075, 0)
        closeButton.Size = UDim2.fromOffset(42, 42)
        closeButton.Text = ""
        closeButton.BackgroundColor3 = Color3.new(0, 0, 0)
        closeButton.AutoButtonColor = false
        closeButton.ZIndex = 25
        create(
            "UIStroke",
            { Color = Color3.new(0, 0, 0), Thickness = 2.8, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            closeButton
        )
        local face = create("Frame", {
            Name = "Face",
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, -5),
            ZIndex = 26,
        }, closeButton)
        face.BackgroundColor3 = Color3.fromRGB(232, 48, 48)
        local _inner = create("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -2, 1, -2),
            ZIndex = 27,
        }, face)

        local closeGlyph = create("TextLabel", {
            BackgroundTransparency = 1,
            Text = "X",
            FontFace = FONT,
            TextSize = 30,
            TextColor3 = Color3.new(1, 1, 1),
            Size = UDim2.fromScale(1, 1),
            ZIndex = 28,
        }, face)
        create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3 }, closeGlyph)
        local pressScale = closeButton:FindFirstChildOfClass("UIScale") or create("UIScale", {}, closeButton)
        closeButton.MouseEnter:Connect(function()
            TweenService:Create(pressScale, TweenInfo.new(0.08), { Scale = 1.08 }):Play()
        end)
        closeButton.MouseLeave:Connect(function()
            TweenService:Create(pressScale, TweenInfo.new(0.08), { Scale = 1 }):Play()
        end)
        closeButton.MouseButton1Down:Connect(function()
            TweenService:Create(pressScale, TweenInfo.new(0.05), { Scale = 0.92 }):Play()
        end)
    end
end
-- The "Live" layer holds everything a RENDER fn builds; it is cleared on every refresh.
local function liveLayerOf(panel)
    return panel:FindFirstChild("Live")
        or create(
            "Frame",
            { Name = "Live", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7 },
            panel
        )
end

-- ===== 4. Toast + GetState / Action wrappers =====

local toast = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -110),
    Size = UDim2.new(1, -32, 0, 40),
    BackgroundColor3 = CREAM,
    FontFace = FONT,
    TextScaled = true,
    TextColor3 = Color3.new(1, 1, 1),
    Visible = false,
    ZIndex = 20,
}, gui)
create("UIStroke", { Color = INK, Thickness = 1.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, toast)
create("UICorner", { CornerRadius = UDim.new(0, 12) }, toast)
create("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, toast)
create("UIPadding", {
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 12),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
}, toast)
create("UISizeConstraint", { MaxSize = Vector2.new(420, 40) }, toast)
local toastId = 0
local function showToast(message)
    if not message or message == "" then
        return
    end
    toastId += 1
    local thisToastId = toastId
    toast.Text = message
    toast.Visible = true
    task.delay(2.2, function()
        if toastId == thisToastId then
            toast.Visible = false
        end
    end)
end
local refresh -- assigned in section 10; runAction calls it after a successful action
-- One Action call at a time (client-side guard; the server also serialises and rate-limits).
-- Returns the server's ok flag; the server's message (if any) is shown as a toast.
local actionBusy = false
local function runAction(actionName, args)
    if actionBusy then
        return false
    end
    actionBusy = true
    local ok, success, message = pcall(function()
        return Action:InvokeServer(actionName, args)
    end)
    actionBusy = false
    if not ok then
        showToast("Server error")
        return false
    end
    showToast(message)
    if success then
        if actionName and actionName:find("Claim") then
            UISound.Play("Claim")
        elseif actionName and (actionName:find("Upgrade") or actionName:find("Unlock") or actionName:find("Buy")) then
            UISound.Play("Purchase")
        end
        if refresh then
            refresh()
        end
    end
    return success
end
-- GetState wrapper: returns data, or nil + a message to show. Retries (up to 3 tries) only on the
-- server's rate-limit reply "Please wait a moment.".
local function fetchState(section)
    for attempt = 1, 3 do
        local ok, data = pcall(function()
            return GetState:InvokeServer(section)
        end)
        if not ok or type(data) ~= "table" then
            return nil, "Couldn't load"
        end
        if not data.error then
            return data
        end
        if data.error ~= "Please wait a moment." then
            return nil, data.error
        end
        task.wait(0.06 * attempt)
    end
    return nil, "Couldn't refresh. Please reopen the menu."
end

-- RENDER[panelName](panel) rebuilds that panel's Live layer; called through refresh() inside a pcall.
local RENDER = {}

local _EDGE_COLOR, CARD_COLOR, CELL_COLOR =
    Color3.fromRGB(150, 120, 230), Color3.fromRGB(42, 31, 74), Color3.fromRGB(53, 40, 98)
-- Accent colour of the panel (direct child of the ScreenGui) that contains `instance`.
local function accentOf(instance)
    while instance and instance.Parent ~= gui do
        instance = instance.Parent
    end
    local theme = instance and SKINS[instance.Name]
    return theme and theme.grad[1] or Color3.fromRGB(255, 196, 60)
end
-- Rounded studded card; cards inside an "Inner" box also get an accent strip in the menu colour.
local function card(parent, cx, cy, w, h, color, _radius, zIndex)
    local cardFrame = box(
        parent,
        cx,
        cy,
        w,
        h,
        { BackgroundTransparency = 0, BackgroundColor3 = color or CARD_COLOR, ZIndex = zIndex or 6 }
    )
    create("UIStroke", {
        Color = Color3.new(1, 1, 1),
        Thickness = 3,
        Transparency = 0,
        LineJoinMode = Enum.LineJoinMode.Round,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, cardFrame)
    create("UICorner", { CornerRadius = UDim.new(0, 10) }, cardFrame) -- v2
    create(
        "UIGradient",
        { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(165, 160, 185)) },
        cardFrame
    ) -- figma: lighter top, darker base
    create("ImageLabel", {
        Name = "Studs",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = "rbxassetid://132561191216691",
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(22, 22),
        ImageTransparency = 0.72,
        ZIndex = cardFrame.ZIndex,
    }, cardFrame)
    if parent:GetAttribute("Inner") then -- main cards: accent strip in the menu colour
        create("Frame", {
            Name = "Accent",
            BackgroundColor3 = accentOf(parent),
            BorderSizePixel = 0,
            Size = UDim2.new(0, 6, 1, 0),
            ZIndex = cardFrame.ZIndex,
        }, cardFrame)
    end
    return cardFrame
end
-- Unused.
local function _innerOf(layer)
    local innerBox = box(layer, 0.5, 0.58, 0.9, 0.72)
    innerBox:SetAttribute("Inner", true)
    return innerBox
end

-- ===== 5. v3 cards, tabs and icons =====
-- UI v3 (Figma "Index v3 · Seasons" / "Quest v3")
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local GAME_ICONS = {
    Book = "rbxassetid://104286530759848",
    Scroll = "rbxassetid://79414603176573",
    Key = "rbxassetid://86826769942442",
    Trophy = "rbxassetid://93664136134324",
    Medal = "rbxassetid://115933046975719",
    Clock = "rbxassetid://112731802177209",
    Diamond = "rbxassetid://125953814573772",
    Gem = "rbxassetid://139683651057323",
    Chest = "rbxassetid://108828180161951",
    Hatch = "EGG",
    Boost = "rbxassetid://115300000098827",
    Money = "rbxassetid://91503030293166",
    Crown = "rbxassetid://132384741215584",
    ShopCrown = "rbxassetid://132384741215584",
    Starter = "rbxassetid://89561259739700",
    Coins = "rbxassetid://125162321561970",
    Plot = "rbxassetid://77749732102580",
    Index = "rbxassetid://101507685468144",
    Quest = "rbxassetid://81682814875935",
    Cash = "rbxassetid://113092821462846",
}
-- gameIcon(parent, image, cx, cy, iconSize, zIndex): square icon (RelativeYY); the special image "EGG"
-- shows the real UnknownEgg shop model in a small ViewportFrame instead.
local function gameIcon(parent, image, cx, cy, iconSize, zIndex)
    if image == "EGG" then -- the real Limited (Unknown) egg model, framed in a small viewport
        local viewport = create("ViewportFrame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(cx, cy),
            Size = UDim2.fromScale(iconSize, iconSize),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            ZIndex = zIndex or 12,
            Ambient = Color3.fromRGB(210, 210, 230),
            LightColor = Color3.fromRGB(255, 245, 225),
            LightDirection = Vector3.new(-1, -1, -1),
        }, parent)
        local shopModels = ReplicatedStorage:FindFirstChild("ShopSystem")
            and ReplicatedStorage.ShopSystem:FindFirstChild("ShopModels")
        local eggTemplate = shopModels and shopModels:FindFirstChild("UnknownEgg")
        if eggTemplate then
            local egg = eggTemplate:Clone()
            egg.Parent = viewport
            local boundsCFrame, boundsSize = egg:GetBoundingBox()
            egg:PivotTo(CFrame.new(-boundsCFrame.Position) * egg:GetPivot())
            local camera = create("Camera", { FieldOfView = 30 }, viewport)
            viewport.CurrentCamera = camera
            camera.CFrame =
                CFrame.lookAt(Vector3.new(0, boundsSize.Y * 0.05, -boundsSize.Magnitude * 1.55), Vector3.zero)
        end
        return viewport
    end
    local iconImage = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = image,
        ScaleType = Enum.ScaleType.Fit,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(cx, cy),
        Size = UDim2.fromScale(iconSize, iconSize),
        SizeConstraint = Enum.SizeConstraint.RelativeYY,
        ZIndex = zIndex or 12,
    }, parent)
    return iconImage
end
local function v3card(parent, cx, cy, w, h, color, zIndex)
    local cardFrame =
        box(parent, cx, cy, w, h, { BackgroundTransparency = 0, BackgroundColor3 = color, ZIndex = zIndex or 8 })
    create("UICorner", { CornerRadius = UDim.new(0, 10) }, cardFrame)
    create("UIStroke", {
        Color = WHITE,
        Thickness = 3,
        LineJoinMode = Enum.LineJoinMode.Round,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, cardFrame)
    create("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 165, 190)) }, cardFrame)
    create("ImageLabel", {
        Name = "Studs",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = STUDS_IMAGE,
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(22, 22),
        ImageTransparency = 0.7,
        ZIndex = cardFrame.ZIndex,
    }, cardFrame)
    return cardFrame
end
-- v3tab(parent, cx, cy, w, h, label, color, isActive, onClick, subtitle, image): tab card; the active tab
-- pulses. Without onClick the tab is dimmed and not clickable (e.g. "coming soon").
local function v3tab(parent, cx, cy, w, h, label, color, isActive, onClick, subtitle, image)
    local tabFrame = v3card(parent, cx, cy, w, h, isActive and color or Color3.fromRGB(53, 40, 98), 9)
    tabFrame = tabFrame -- frame; clickable overlay
    local hitbox = create(
        "TextButton",
        { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 14 },
        tabFrame
    )
    if image then
        local tabIcon = gameIcon(tabFrame, image, 0.13, 0.5, 0.9, 13)
        if isActive then
            TweenService:Create(
                tabIcon,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Rotation = 8 }
            ):Play()
        end
    end
    text(tabFrame, label, WHITE, {
        Stroke = 2,
        Max = 20,
        Size = UDim2.fromScale(image and 0.66 or 0.9, subtitle and 0.5 or 0.62),
        Position = UDim2.fromScale(image and 0.6 or 0.5, subtitle and 0.36 or 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 12,
    })
    if subtitle then
        text(tabFrame, subtitle, Color3.fromRGB(230, 225, 255), {
            Max = 12,
            Size = UDim2.fromScale(0.9, 0.3),
            Position = UDim2.fromScale(0.5, 0.78),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
    end
    local stroke = tabFrame:FindFirstChildOfClass("UIStroke")
    if isActive then
        TweenService:Create(
            stroke,
            TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Thickness = 4.5 }
        ):Play()
    end
    if onClick then
        local hoverScale = create("UIScale", {}, tabFrame)
        hitbox.MouseEnter:Connect(function()
            UISound.Play("Hover")
            TweenService:Create(hoverScale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
        end)
        hitbox.MouseLeave:Connect(function()
            TweenService:Create(hoverScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
        end)
        hitbox.Activated:Connect(function()
            UISound.Play("Click")
            onClick()
        end)
    else
        tabFrame.BackgroundTransparency = 0.35
    end
    return tabFrame
end
-- Recolours / retitles the clean-skin header of `panel` (no-op before skinPanel ran).
local function setHeader(panel, title, topColor, bottomColor)
    local skin = panel:FindFirstChild("CleanSkin")
    local header = skin and skin:FindFirstChild("Header")
    if not header then
        return
    end
    local gradient = header:FindFirstChildOfClass("UIGradient")
    if gradient then
        gradient.Color = ColorSequence.new(topColor, bottomColor)
    end
    local titleLabel = header:FindFirstChildOfClass("TextLabel")
    if titleLabel then
        titleLabel.Text = title
    end
end
-- "[Nd ]HH:MM:SS"; negative values clamp to 0.
local function formatCountdown(seconds)
    seconds = math.max(0, math.floor(seconds))
    local days = seconds // 86400
    return (days > 0 and (days .. "d ") or "")
        .. string.format("%02d:%02d:%02d", (seconds // 3600) % 24, (seconds // 60) % 60, seconds % 60)
end

-- ===== 6. Index panel =====
-- View state survives refreshes: season tab, rarity filter and the selected character id.
local indexSeason = workspace:GetAttribute("HalloweenMode") and "Halloween" or "Original"
local indexFilter, indexSelectedId = "All", nil
local HALLOWEEN_ORANGE = Color3.fromRGB(255, 140, 30)
-- Season tabs (Original / Halloween / Winter) + the Halloween countdown pill.
local function buildIndexSeasonTabs(panel, content, characters, isHalloween)
    -- season tabs
    local isEventLive = workspace:GetAttribute("HalloweenMode") == true
    v3tab(content, 0.09, 0.045, 0.17, 0.085, "ORIGINAL", Color3.fromRGB(60, 120, 240), not isHalloween, function()
        indexSeason = "Original"
        RENDER.Index(panel)
    end, #characters .. " characters", GAME_ICONS.Book)
    local halloweenTab = v3tab(
        content,
        0.275,
        0.045,
        0.19,
        0.085,
        "🎃 HALLOWEEN",
        HALLOWEEN_ORANGE,
        isHalloween,
        function()
            indexSeason = "Halloween"
            RENDER.Index(panel)
        end,
        isEventLive and "LIVE EVENT" or "event ended"
    )
    if isEventLive then
        local liveBadge = v3card(halloweenTab, 0.92, -0.12, 0.3, 0.42, Color3.fromRGB(230, 40, 60), 15)
        text(liveBadge, "LIVE", WHITE, {
            Stroke = 1.5,
            Max = 13,
            Size = UDim2.fromScale(0.9, 0.8),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 16,
        })
        local liveBadgeScale = create("UIScale", {}, liveBadge)
        TweenService:Create(
            liveBadgeScale,
            TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Scale = 1.12 }
        ):Play()
    end
    v3tab(content, 0.46, 0.045, 0.16, 0.085, "🔒 WINTER", Color3.fromRGB(40, 36, 70), false, nil, "coming soon")
    local endsAt = workspace:GetAttribute("HalloweenEndsAt")
    if isHalloween then
        local timerPill = v3card(content, 0.87, 0.045, 0.26, 0.075, Color3.fromRGB(110, 50, 190), 9)
        local timerLabel = text(
            timerPill,
            typeof(endsAt) == "number" and ("⏳ ENDS IN " .. formatCountdown(endsAt - os.time()))
                or "⏳ LIMITED EVENT",
            Color3.fromRGB(255, 220, 120),
            {
                Stroke = 2,
                Max = 18,
                Size = UDim2.fromScale(0.92, 0.7),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 12,
            }
        )
        if typeof(endsAt) == "number" then
            task.spawn(function()
                while timerLabel.Parent and panel.Visible do
                    timerLabel.Text = "⏳ ENDS IN " .. formatCountdown(endsAt - os.time())
                    task.wait(1)
                end
            end)
        end
    end
end
-- "DISCOVERED n / m" strip with progress bar and the set-complete chip.
local function buildIndexProgressStrip(content, characters, discoveredCount, isHalloween)
    -- progress strip
    local progressStrip =
        v3card(content, 0.5, 0.155, 1, 0.1, isHalloween and Color3.fromRGB(70, 30, 80) or Color3.fromRGB(33, 24, 69), 8)
    if isHalloween then
        progressStrip:FindFirstChildOfClass("UIStroke").Color = HALLOWEEN_ORANGE
    end
    text(
        progressStrip,
        isHalloween and "HALLOWEEN SET" or "DISCOVERED",
        isHalloween and Color3.fromRGB(255, 190, 110) or Color3.fromRGB(195, 180, 230),
        {
            Max = 14,
            Size = UDim2.fromScale(0.16, 0.36),
            Position = UDim2.fromScale(0.015, 0.1),
            X = Enum.TextXAlignment.Left,
            ZIndex = 10,
        }
    )
    text(progressStrip, discoveredCount .. " / " .. #characters, WHITE, {
        Stroke = 2,
        Max = 26,
        Size = UDim2.fromScale(0.12, 0.5),
        Position = UDim2.fromScale(0.015, 0.44),
        X = Enum.TextXAlignment.Left,
        ZIndex = 10,
    })
    local track = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(13, 10, 20),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.15, 0.32),
        Size = UDim2.fromScale(0.58, 0.36),
        ZIndex = 10,
    }, progressStrip)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    create("UIStroke", { Color = WHITE, Thickness = 2 }, track)
    local fill = create("Frame", {
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(math.max(discoveredCount / math.max(#characters, 1), 0.03), 1),
        ZIndex = 11,
    }, track)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    create("UIGradient", {
        Color = isHalloween and ColorSequence.new(Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 100, 0))
            or ColorSequence.new(Color3.fromRGB(130, 255, 110), Color3.fromRGB(40, 190, 60)),
    }, fill)
    local rewardChip = v3card(
        progressStrip,
        0.865,
        0.5,
        0.24,
        0.6,
        isHalloween and HALLOWEEN_ORANGE or Color3.fromRGB(255, 214, 72),
        10
    )
    gameIcon(rewardChip, GAME_ICONS.Trophy, 0.1, 0.5, 1.1, 13)
    text(
        rewardChip,
        discoveredCount >= #characters and "   SET COMPLETE!"
            or ("     " .. (#characters - discoveredCount) .. " left to find"),
        discoveredCount >= #characters and WHITE or INK,
        {
            Max = 16,
            Size = UDim2.fromScale(0.92, 0.7),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        }
    )
end
-- Rarity filter chips; clicking one sets indexFilter and re-renders.
local function buildIndexRarityFilters(panel, content)
    -- rarity filters
    local FILTERS = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" }
    local filterX = 0
    for _, filterName in FILTERS do
        local filterWidth = 0.05 + #filterName * 0.0075
        local isActive = indexFilter == filterName
        local filterColor = filterName == "All" and WHITE or RARITY_COLORS[filterName]
        local filterChip = v3card(
            content,
            filterX + filterWidth / 2,
            0.24,
            filterWidth,
            0.05,
            isActive and filterColor or Color3.fromRGB(53, 40, 98),
            9
        )
        text(filterChip, string.upper(filterName), (isActive and filterName == "All") and INK or WHITE, {
            Max = 13,
            Size = UDim2.fromScale(0.9, 0.75),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
        local hitbox = create(
            "TextButton",
            { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 14 },
            filterChip
        )
        hitbox.Activated:Connect(function()
            UISound.Play("Click")
            indexFilter = filterName
            RENDER.Index(panel)
        end)
        filterX += filterWidth + 0.008
    end
end
-- One grid cell: discovered = rarity card with FX + click-to-select; otherwise a silhouette "???".
local function buildIndexCell(panel, grid, i, character, data, isHalloween)
    local isDiscovered = data.discovered[character.id] == true
    local column, row = (i - 1) % 5, math.floor((i - 1) / 5)
    local cell = card(
        grid,
        0.1 + column * 0.2,
        0.165 + row * 0.335,
        0.185,
        0.31,
        isDiscovered and (RARITY_COLORS[character.rarity] or CELL_COLOR) or Color3.fromRGB(28, 22, 46),
        0.18,
        7
    )
    if isDiscovered then
        local rarityColor = RARITY_COLORS[character.rarity] or GREY
        local lightColor = rarityColor:Lerp(WHITE, 0.55)
        local tier = RARITY_TIER[character.rarity] or 6
        cell.ClipsDescendants = true
        local rays = create("ImageLabel", {
            Name = "Rays",
            BackgroundTransparency = 1,
            Image = FX_IMAGES.rays,
            ImageColor3 = lightColor,
            ImageTransparency = tier >= 3 and 0.45 or 0.7,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.45),
            Size = UDim2.fromScale(1.5, 1.5),
            SizeConstraint = Enum.SizeConstraint.RelativeXX,
            ZIndex = 7,
        }, cell)
        TweenService
            :Create(
                rays,
                TweenInfo.new(24, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
                { Rotation = 360 }
            )
            :Play()
        create("ImageLabel", {
            Name = "Glow",
            BackgroundTransparency = 1,
            Image = FX_IMAGES.glow,
            ImageColor3 = lightColor,
            ImageTransparency = 0.25,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.46),
            Size = UDim2.fromScale(0.9, 0.9),
            SizeConstraint = Enum.SizeConstraint.RelativeYY,
            ZIndex = 7,
        }, cell)
        for sparkleIndex, offset in { { 0.12, 0.3 }, { 0.88, 0.42 }, { 0.18, 0.66 }, { 0.84, 0.7 }, { 0.72, 0.18 } } do
            if sparkleIndex > tier then
                break
            end
            local sparkle = create("ImageLabel", {
                BackgroundTransparency = 1,
                Image = FX_IMAGES.sparkle,
                ImageColor3 = sparkleIndex % 2 == 0 and WHITE or lightColor,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(offset[1], offset[2]),
                Size = UDim2.fromOffset(sparkleIndex % 2 == 0 and 9 or 13, sparkleIndex % 2 == 0 and 9 or 13),
                ZIndex = 10,
            }, cell)
            TweenService
                :Create(
                    sparkle,
                    TweenInfo.new(
                        0.9 + sparkleIndex * 0.17,
                        Enum.EasingStyle.Sine,
                        Enum.EasingDirection.InOut,
                        -1,
                        true
                    ),
                    { ImageTransparency = 0.8 }
                )
                :Play()
        end
        if character.image and character.image ~= "" then
            create("ImageLabel", {
                BackgroundTransparency = 1,
                Image = character.image,
                ScaleType = Enum.ScaleType.Fit,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.42),
                Size = UDim2.fromScale(1.3, 0.7),
                ZIndex = 9,
            }, cell)
        end
        local nameBar = create("Frame", {
            BackgroundColor3 = Color3.fromRGB(13, 10, 20),
            BackgroundTransparency = 0.45,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -5),
            Size = UDim2.fromScale(0.9, 0.19),
            ZIndex = 10,
        }, cell)
        create("UICorner", { CornerRadius = UDim.new(0, 6) }, nameBar)
        text(nameBar, character.name, WHITE, {
            Stroke = 1.5,
            Max = 15,
            Size = UDim2.fromScale(0.94, 0.8),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 11,
        })
        if isHalloween then
            text(cell, "🎃", WHITE, {
                Max = 18,
                Size = UDim2.fromScale(0.22, 0.16),
                Position = UDim2.fromScale(0.03, 0.03),
                ZIndex = 12,
            })
        end
        if indexSelectedId == character.id then
            local stroke = cell:FindFirstChildOfClass("UIStroke")
            stroke.Color = isHalloween and HALLOWEEN_ORANGE or Color3.fromRGB(255, 214, 72)
            TweenService:Create(
                stroke,
                TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Thickness = 5 }
            ):Play()
        end
        local hitbox = create(
            "TextButton",
            { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 15 },
            cell
        )
        local cellScale = create("UIScale", {}, cell)
        hitbox.MouseEnter:Connect(function()
            UISound.Play("Hover")
            TweenService:Create(cellScale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
        end)
        hitbox.MouseLeave:Connect(function()
            TweenService:Create(cellScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
        end)
        hitbox.Activated:Connect(function()
            UISound.Play("Click")
            indexSelectedId = character.id
            RENDER.Index(panel)
        end)
    else
        if character.image and character.image ~= "" then
            create("ImageLabel", {
                BackgroundTransparency = 1,
                Image = character.image,
                ImageColor3 = BLACK,
                ImageTransparency = 0.15,
                ScaleType = Enum.ScaleType.Fit,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.42),
                Size = UDim2.fromScale(1.15, 0.7),
                ZIndex = 8,
            }, cell)
        else
            text(cell, "?", GREY, {
                Size = UDim2.fromScale(0.5, 0.45),
                Position = UDim2.fromScale(0.5, 0.36),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 8,
            })
        end
        text(cell, "???", RARITY_COLORS[character.rarity] or GREY, {
            Stroke = 1.5,
            Max = 15,
            Size = UDim2.fromScale(0.7, 0.18),
            Position = UDim2.fromScale(0.5, 0.86),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 9,
        })
    end
end
-- Right-hand detail card for indexSelectedId (or a hint when nothing is discovered yet).
local function buildIndexDetail(content, data, characters, isHalloween)
    -- detail panel
    local selected
    for _, character in characters do
        if character.id == indexSelectedId then
            selected = character
        end
    end
    local detailColor = selected and (RARITY_COLORS[selected.rarity] or GREY) or Color3.fromRGB(53, 40, 98)
    local detailCard =
        v3card(content, 0.85, 0.635, 0.3, 0.72, isHalloween and Color3.fromRGB(255, 150, 40) or detailColor, 8)
    if selected then
        detailCard.ClipsDescendants = true
        local rays = create("ImageLabel", {
            BackgroundTransparency = 1,
            Image = FX_IMAGES.rays,
            ImageColor3 = WHITE,
            ImageTransparency = 0.6,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.32),
            Size = UDim2.fromScale(1.6, 1.6),
            SizeConstraint = Enum.SizeConstraint.RelativeXX,
            ZIndex = 9,
        }, detailCard)
        TweenService
            :Create(
                rays,
                TweenInfo.new(20, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
                { Rotation = 360 }
            )
            :Play()
        local rarityBadge = v3card(detailCard, 0.24, 0.06, 0.38, 0.06, Color3.fromRGB(226, 66, 60), 12)
        text(rarityBadge, string.upper(selected.rarity or "?"), WHITE, {
            Stroke = 1.5,
            Max = 14,
            Size = UDim2.fromScale(0.9, 0.8),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 13,
        })
        if isHalloween then
            local eventBadge = v3card(detailCard, 0.76, 0.06, 0.4, 0.06, Color3.fromRGB(110, 40, 190), 12)
            text(eventBadge, "👻 EVENT", WHITE, {
                Stroke = 1.5,
                Max = 14,
                Size = UDim2.fromScale(0.9, 0.8),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 13,
            })
        end
        if selected.image and selected.image ~= "" then
            local portrait = create("ImageLabel", {
                BackgroundTransparency = 1,
                Image = selected.image,
                ScaleType = Enum.ScaleType.Fit,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.33),
                Size = UDim2.fromScale(0.95, 0.4),
                ZIndex = 11,
            }, detailCard)
            TweenService:Create(
                portrait,
                TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Position = UDim2.fromScale(0.5, 0.31) }
            ):Play()
        end
        text(detailCard, selected.name, WHITE, {
            Stroke = 2.5,
            Max = 30,
            Size = UDim2.fromScale(0.92, 0.09),
            Position = UDim2.fromScale(0.5, 0.6),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
        local infoCard = v3card(detailCard, 0.5, 0.76, 0.9, 0.17, Color3.fromRGB(33, 24, 69), 11)
        text(infoCard, selected.obtain or "", Color3.fromRGB(215, 210, 240), {
            Max = 14,
            Size = UDim2.fromScale(0.92, 0.45),
            Position = UDim2.fromScale(0.5, 0.3),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 13,
        })
        local ownedCount = data.owned and data.owned[selected.id] or 0
        text(infoCard, "OWNED: " .. ownedCount, Color3.fromRGB(120, 255, 120), {
            Stroke = 1.5,
            Max = 18,
            Size = UDim2.fromScale(0.9, 0.35),
            Position = UDim2.fromScale(0.5, 0.75),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 13,
        })
        text(detailCard, selected.description or "", WHITE, {
            Max = 13,
            Size = UDim2.fromScale(0.9, 0.08),
            Position = UDim2.fromScale(0.5, 0.92),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
    else
        text(detailCard, "Hatch eggs to discover characters!", WHITE, {
            Stroke = 2,
            Max = 20,
            Size = UDim2.fromScale(0.85, 0.2),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
    end
end
RENDER.Index = function(panel)
    local data, errorMessage = fetchState("index")
    local layer = liveLayerOf(panel)
    clear(layer)
    if not data then
        text(box(layer, 0.5, 0.5, 0.6, 0.08), errorMessage)
        return
    end
    local isHalloween = indexSeason == "Halloween"
    if isHalloween then
        setHeader(panel, "HALLOWEEN INDEX", Color3.fromRGB(255, 160, 40), Color3.fromRGB(200, 60, 0))
    else
        setHeader(panel, "INDEX", SKINS.Index.grad[1], SKINS.Index.grad[2])
    end
    local content = box(layer, 0.5, 0.575, 0.94, 0.79)
    local characters = {}
    for i, character in data.catalog.characters do
        if i <= 15 then
            table.insert(characters, character)
        end
    end
    local discoveredCount = 0
    for _, character in characters do
        if data.discovered[character.id] == true then
            discoveredCount += 1
        end
    end
    buildIndexSeasonTabs(panel, content, characters, isHalloween)
    buildIndexProgressStrip(content, characters, discoveredCount, isHalloween)
    buildIndexRarityFilters(panel, content)
    -- grid
    local visibleCharacters = {}
    for _, character in characters do
        if indexFilter == "All" or character.rarity == indexFilter then
            table.insert(visibleCharacters, character)
        end
    end
    if not indexSelectedId then
        for _, character in characters do
            if data.discovered[character.id] == true then
                indexSelectedId = character.id
            end
        end
    end
    local grid = box(content, 0.34, 0.635, 0.68, 0.72)
    for i, character in visibleCharacters do
        buildIndexCell(panel, grid, i, character, data, isHalloween)
    end
    buildIndexDetail(content, data, characters, isHalloween)
end

-- ===== 7. Quests panel =====
-- Selected period tab: "Daily" | "Weekly" | "Monthly" (shown as MILESTONES).
local questTab = "Daily"
-- Period tabs with a red badge counting claimable quests; clicking switches questTab.
local function buildQuestTabs(panel, content, data)
    local QUEST_TABS = {
        { "Daily", "DAILY", Color3.fromRGB(255, 190, 40), GAME_ICONS.Clock },
        { "Weekly", "WEEKLY", Color3.fromRGB(255, 120, 40), GAME_ICONS.Chest },
        { "Monthly", "MILESTONES", Color3.fromRGB(150, 100, 230), GAME_ICONS.Trophy },
    }
    for i, tabDef in QUEST_TABS do
        local readyCount = 0
        for _, quest in data.list or {} do
            if quest.period == tabDef[1] and quest.progress >= quest.target and not quest.claimed then
                readyCount += 1
            end
        end
        local tabFrame = v3tab(
            content,
            0.1 + (i - 1) * 0.21,
            0.05,
            0.195,
            0.085,
            tabDef[2],
            tabDef[3],
            questTab == tabDef[1],
            function()
                if questTab ~= tabDef[1] then
                    questTab = tabDef[1]
                    RENDER.Quests(panel)
                end
            end,
            nil,
            tabDef[4]
        )
        if readyCount > 0 then
            local readyBadge = v3card(tabFrame, 0.97, 0.08, 0.17, 0.5, Color3.fromRGB(230, 40, 60), 15)
            text(readyBadge, tostring(readyCount), WHITE, {
                Stroke = 1.5,
                Max = 14,
                Size = UDim2.fromScale(0.9, 0.85),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 16,
            })
        end
    end
end
-- "New quests in ..." countdown for the selected period (server-time corrected).
local function buildQuestTimer(panel, content, data)
    local endsAt = data.ends and data.ends[questTab]
    local timerPill = v3card(content, 0.86, 0.05, 0.28, 0.07, Color3.fromRGB(20, 14, 40), 9)
    gameIcon(timerPill, GAME_ICONS.Clock, 0.08, 0.5, 0.9, 13)
    local timerLabel = text(timerPill, "", Color3.fromRGB(255, 214, 72), {
        Stroke = 1.5,
        Max = 16,
        Size = UDim2.fromScale(0.92, 0.7),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        ZIndex = 12,
    })
    if endsAt then
        local clockOffset = (data.serverTime or os.time()) - os.time()
        task.spawn(function()
            while timerLabel.Parent and panel.Visible do
                timerLabel.Text = "      New quests in " .. formatCountdown(endsAt - (os.time() + clockOffset))
                task.wait(1)
            end
        end)
    end
end
-- One quest row: icon, title/description, progress bar, reward chip and CLAIM / GO / DONE button.
local function buildQuestRow(content, i, quest, rowHeight)
    local isComplete = quest.progress >= quest.target
    local isClaimable = isComplete and not quest.claimed
    local rowY = 0.13 + (i - 0.5) * rowHeight
    local row = v3card(
        content,
        0.5,
        rowY,
        1,
        rowHeight * 0.88,
        isClaimable and Color3.fromRGB(40, 150, 60)
            or quest.claimed and Color3.fromRGB(45, 42, 62)
            or Color3.fromRGB(42, 31, 74),
        8
    )
    if isClaimable then
        local stroke = row:FindFirstChildOfClass("UIStroke")
        stroke.Color = Color3.fromRGB(150, 255, 120)
        TweenService:Create(
            stroke,
            TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Thickness = 5 }
        ):Play()
    end
    local titleLower = string.lower(quest.title or "")
    local _emoji = titleLower:find("hatch") and "🥚"
        or titleLower:find("discover") and "📖"
        or titleLower:find("steal") and "🦹"
        or titleLower:find("place") and "🐾"
        or titleLower:find("upgrade") and "⭐"
        or titleLower:find("cash") and "💰"
        or "⭐"
    local iconCard = v3card(row, 0.045, 0.5, 0.06, 0.8, quest.claimed and GREEN or Color3.fromRGB(70, 140, 255), 10)
    create("UIAspectRatioConstraint", { AspectRatio = 1 }, iconCard)
    local questImage = (titleLower:find("hatch") or titleLower:find("egg")) and GAME_ICONS.Hatch
        or titleLower:find("discover") and GAME_ICONS.Book
        or (titleLower:find("place") or titleLower:find("upgrade") or titleLower:find("temple") or titleLower:find(
            "slot"
        )) and GAME_ICONS.Plot
        or (titleLower:find("cash") or titleLower:find("income") or titleLower:find("earn")) and GAME_ICONS.Coins
        or titleLower:find("steal") and GAME_ICONS.Chest
        or GAME_ICONS.Scroll
    if quest.claimed then
        text(iconCard, "✓", WHITE, {
            Stroke = 2,
            Max = 34,
            Size = UDim2.fromScale(0.85, 0.85),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
    else
        local questIcon = gameIcon(iconCard, questImage, 0.5, 0.5, 0.92, 12)
        if isClaimable and questIcon:IsA("ImageLabel") then
            TweenService:Create(
                questIcon,
                TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Rotation = 10 }
            ):Play()
        end
    end
    text(row, quest.title or "", WHITE, {
        Stroke = 2,
        Max = 22,
        Size = UDim2.fromScale(0.4, 0.4),
        Position = UDim2.fromScale(0.1, 0.1),
        X = Enum.TextXAlignment.Left,
        ZIndex = 11,
    })
    text(row, quest.description or "", Color3.fromRGB(205, 200, 230), {
        Max = 14,
        Size = UDim2.fromScale(0.4, 0.3),
        Position = UDim2.fromScale(0.1, 0.55),
        X = Enum.TextXAlignment.Left,
        ZIndex = 11,
    })
    local track = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(13, 10, 20),
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.52, 0.14),
        Size = UDim2.fromScale(0.26, 0.32),
        ZIndex = 10,
    }, row)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    create("UIStroke", { Color = WHITE, Thickness = 2 }, track)
    local fill = create("Frame", {
        BackgroundColor3 = WHITE,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(math.clamp(quest.progress / quest.target, 0.04, 1), 1),
        ZIndex = 11,
    }, track)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    create("UIGradient", {
        Color = isComplete and ColorSequence.new(Color3.fromRGB(130, 255, 110), Color3.fromRGB(40, 190, 60))
            or ColorSequence.new(Color3.fromRGB(255, 210, 60), Color3.fromRGB(255, 140, 0)),
    }, fill)
    text(
        track,
        math.min(quest.progress, quest.target) .. " / " .. quest.target,
        WHITE,
        { Stroke = 1.5, Max = 14, ZIndex = 12 }
    )
    local rewardText = quest.reward
            and (quest.reward.cash and ("     $" .. Config.Short(quest.reward.cash)) or quest.reward.label)
        or nil
    if rewardText then
        local chip = v3card(row, 0.585, 0.73, 0.13, 0.32, Color3.fromRGB(20, 14, 40), 10)
        text(chip, rewardText, Color3.fromRGB(120, 255, 120), {
            Stroke = 1.5,
            Max = 14,
            Size = UDim2.fromScale(0.9, 0.8),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            ZIndex = 12,
        })
        if quest.reward.cash then
            gameIcon(chip, GAME_ICONS.Coins, 0.2, 0.5, 1.1, 13)
        end
    end
    local buttonLabel = quest.claimed and "DONE" or isClaimable and "CLAIM" or "GO"
    local actionButton = button(
        row,
        0.9,
        0.5,
        0.16,
        0.66,
        buttonLabel,
        quest.claimed and GREY or isClaimable and GREEN or Color3.fromRGB(60, 120, 240)
    )
    actionButton.ZIndex = 12
    if isClaimable then
        local pulseScale = create("UIScale", {}, actionButton)
        TweenService:Create(
            pulseScale,
            TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Scale = 1.06 }
        ):Play()
        actionButton.Activated:Connect(function()
            runAction("Claim", { id = quest.id })
        end)
    elseif not quest.claimed then
        actionButton.Activated:Connect(function()
            showToast(quest.description or quest.title)
        end)
    else
        actionButton.AutoButtonColor = false
    end
end
RENDER.Quests = function(panel)
    local data, errorMessage = fetchState("quests")
    local layer = liveLayerOf(panel)
    clear(layer)
    if not data then
        text(box(layer, 0.5, 0.5, 0.6, 0.08), errorMessage)
        return
    end
    local content = box(layer, 0.5, 0.575, 0.94, 0.79)
    buildQuestTabs(panel, content, data)
    buildQuestTimer(panel, content, data)
    local visibleQuests = {}
    for _, quest in data.list or {} do
        if quest.period == questTab then
            table.insert(visibleQuests, quest)
        end
    end
    table.sort(visibleQuests, function(a, b)
        local aClaimed, bClaimed = a.claimed and 1 or 0, b.claimed and 1 or 0
        if aClaimed ~= bClaimed then
            return aClaimed < bClaimed
        end
        local aDone, bDone = (a.progress >= a.target) and 0 or 1, (b.progress >= b.target) and 0 or 1
        if aDone ~= bDone then
            return aDone < bDone
        end
        return (a.order or 0) < (b.order or 0)
    end)
    if #visibleQuests == 0 then
        text(box(content, 0.5, 0.5, 0.8, 0.1), "No quests here right now", GREY)
        return
    end
    local rowCount = math.max(#visibleQuests, 5)
    local rowHeight = 0.84 / rowCount
    for i, quest in visibleQuests do
        buildQuestRow(content, i, quest, rowHeight)
    end
end

-- ===== 8. VipShop panel =====
-- Pixel-based layout (scaled via the panel's UIScale "Fit"); every helper below is local to one render.
-- Data comes from ShopSystem.ShopRemote ("State"), not from the GameMenu remotes.
RENDER.VipShop = function(panel)
    -- Shop v3 (Figma "Shop v3 FX"): sidebar that jumps to sections, one scrolling page, glowing cards.
    local layer = liveLayerOf(panel)
    clear(layer)
    local shopSystem = game:GetService("ReplicatedStorage"):FindFirstChild("ShopSystem")
    local shopRemote = shopSystem and shopSystem:FindFirstChild("ShopRemote")
    local ShopConfig = shopSystem and require(shopSystem.ShopConfig)
    if not shopRemote then
        text(box(layer, 0.5, 0.5, 0.6, 0.08), "Shop is loading…")
        return
    end
    local ok, shopState = shopRemote:InvokeServer("State")
    if not ok then
        text(box(layer, 0.5, 0.5, 0.6, 0.08), tostring(shopState))
        return
    end
    local ShopTweenService = game:GetService("TweenService") -- same service as TweenService (local alias)
    local RunService = game:GetService("RunService")
    local SHOP_BLACK, SHOP_WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
    local function rgb(r, g, b)
        return Color3.fromRGB(r, g, b)
    end
    local PINK, GOLD, SHOP_GREEN, BLUE, PURP, RED =
        rgb(226, 66, 150), rgb(248, 188, 44), rgb(70, 190, 70), rgb(60, 120, 235), rgb(150, 90, 230), rgb(226, 52, 60)
    local SHOP_ICONS = table.clone(ShopConfig.Icons or {})
    local SPARKLE_IMAGE = FX_IMAGES.sparkle
    local function roundCorners(instance, radius)
        create("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, instance)
    end
    local function shopLabel(parent, labelText, textSize, color, props)
        local label = create("TextLabel", {
            BackgroundTransparency = 1,
            Text = labelText,
            FontFace = FONT,
            TextSize = textSize,
            TextColor3 = color or SHOP_WHITE,
            ZIndex = 14,
            Size = UDim2.new(1, 0, 0, textSize + 6),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
        }, parent)
        if props then
            for property, value in props do
                if property ~= "NoStroke" then
                    label[property] = value
                end
            end
        end
        if not (props and props.NoStroke) then
            create(
                "UIStroke",
                { Color = SHOP_BLACK, Thickness = textSize >= 24 and 3 or 2, LineJoinMode = Enum.LineJoinMode.Round },
                label
            )
        end
        return label
    end
    local function addStudTexture(frame, transparency, tileSize)
        return create("ImageLabel", {
            Name = "Studs",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = STUDS_IMAGE,
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(tileSize or 24, tileSize or 24),
            ImageTransparency = transparency or 0.55,
            ZIndex = frame.ZIndex,
        }, frame)
    end
    -- Shared Robux price cache (see header). livePrice returns the cached live price or `fallback`.
    _G.__shopPrices = _G.__shopPrices or {}
    local function livePrice(id, isGamePass, fallback)
        if not id or id == 0 then
            return fallback
        end
        local cacheKey = (isGamePass and "p" or "d") .. id
        if _G.__shopPrices[cacheKey] == nil then -- never block the shop on a price lookup: show the config price now, the live one next open
            _G.__shopPrices[cacheKey] = false
            task.spawn(function()
                local fetched, productInfo = pcall(
                    game:GetService("MarketplaceService").GetProductInfo,
                    game:GetService("MarketplaceService"),
                    id,
                    isGamePass and Enum.InfoType.GamePass or Enum.InfoType.Product
                )
                _G.__shopPrices[cacheKey] = fetched and productInfo and productInfo.PriceInRobux or false
            end)
        end
        return _G.__shopPrices[cacheKey] or fallback
    end
    local function priceText(key, isGamePass)
        local productId = isGamePass and ShopConfig.GamePasses[key] or ShopConfig.Products[key]
        return "R$ " .. tostring(livePrice(productId, isGamePass, ShopConfig.Prices[key]) or "?")
    end
    local function formatHms(seconds)
        seconds = math.max(0, math.floor(seconds))
        return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
    end

    -- glowing studded card; returns face, holder, faceStroke, glow
    local function glowCard(parent, color, size, pos, z)
        local holder = create(
            "Frame",
            { BackgroundTransparency = 1, Size = size, Position = pos or UDim2.new(), ZIndex = z or 9 },
            parent
        )
        local shadow = create("Frame", {
            BackgroundColor3 = SHOP_BLACK,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.fromScale(1, 1),
            ZIndex = holder.ZIndex,
        }, holder)
        roundCorners(shadow, 14)
        local face = create("Frame", {
            Name = "Face",
            BackgroundColor3 = SHOP_WHITE,
            BorderSizePixel = 0,
            Size = UDim2.fromScale(1, 1),
            ZIndex = holder.ZIndex + 1,
            ClipsDescendants = true,
        }, holder)
        roundCorners(face, 14)
        create(
            "UIGradient",
            { Rotation = 90, Color = ColorSequence.new(color:Lerp(SHOP_WHITE, 0.12), color:Lerp(SHOP_BLACK, 0.22)) },
            face
        )
        addStudTexture(face, 0.5)
        local faceStroke = create(
            "UIStroke",
            { Color = SHOP_WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            face
        )
        local glow = create("ImageLabel", {
            Name = "Glow",
            BackgroundTransparency = 1,
            Image = FX_IMAGES.glow,
            ImageColor3 = color,
            ImageTransparency = 0.55,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, 60, 1, 60),
            ZIndex = holder.ZIndex - 1,
        }, holder)
        return face, holder, faceStroke, glow
    end
    local function addFloatingSparkles(face, count, tint)
        for _i = 1, count do
            local sparkle = create("ImageLabel", {
                BackgroundTransparency = 1,
                Image = SPARKLE_IMAGE,
                AnchorPoint = Vector2.new(0.5, 0.5),
                ImageColor3 = tint or SHOP_WHITE,
                ImageTransparency = 1,
                ZIndex = face.ZIndex + 4,
            }, face)
            task.spawn(function()
                task.wait(math.random() * 2)
                while sparkle.Parent do
                    local sparkleSize = math.random(8, 15)
                    sparkle.Size = UDim2.fromOffset(sparkleSize, sparkleSize)
                    local sparkleX = 0.06 + math.random() * 0.88
                    sparkle.Position = UDim2.fromScale(sparkleX, 0.15 + math.random() * 0.75)
                    sparkle.ImageTransparency = 1
                    sparkle.Rotation = 0
                    ShopTweenService:Create(
                        sparkle,
                        TweenInfo.new(0.5, Enum.EasingStyle.Sine),
                        { ImageTransparency = 0.1, Rotation = 45 }
                    ):Play()
                    task.wait(0.6)
                    ShopTweenService:Create(
                        sparkle,
                        TweenInfo.new(0.7, Enum.EasingStyle.Sine),
                        { ImageTransparency = 1, Rotation = 90 }
                    ):Play()
                    task.wait(0.8 + math.random() * 1.6)
                end
            end)
        end
    end
    local function playBuyBurst()
        local host = create(
            "Frame",
            { Name = "BuyBurst", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60 },
            layer
        )
        local ring = create("ImageLabel", {
            BackgroundTransparency = 1,
            Image = FX_IMAGES.glow,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(40, 40),
            ImageColor3 = GOLD,
            ZIndex = 60,
        }, host)
        ShopTweenService:Create(
            ring,
            TweenInfo.new(0.5, Enum.EasingStyle.Quad),
            { Size = UDim2.fromOffset(520, 520), ImageTransparency = 1 }
        ):Play()
        for i = 1, 24 do
            local coinImage = i % 3 ~= 0 and SHOP_ICONS.Coins
            local piece = create("ImageLabel", {
                BackgroundTransparency = 1,
                Image = coinImage or SPARKLE_IMAGE,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(coinImage and 34 or 22, coinImage and 34 or 22),
                ScaleType = Enum.ScaleType.Fit,
                ZIndex = 61,
            }, host)
            local angle = (i / 24) * math.pi * 2
            local distance = 0.18 + math.random() * 0.2
            ShopTweenService
                :Create(piece, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {
                    Position = UDim2.fromScale(
                        0.5 + math.cos(angle) * distance,
                        0.5 + math.sin(angle) * distance * 1.4
                    ),
                    Rotation = math.random(-200, 200),
                })
                :Play()
            task.delay(0.55, function()
                if piece.Parent then
                    ShopTweenService:Create(piece, TweenInfo.new(0.45), { ImageTransparency = 1 }):Play()
                end
            end)
        end
        task.delay(1.3, function()
            host:Destroy()
        end)
    end
    local function shopAction(action, ...)
        local success, message = shopRemote:InvokeServer(action, ...)
        if message then
            showToast(message)
        end
        if success then
            UISound.Play(
                (action and (string.find(action, "Buy") or string.find(action, "Purchase"))) and "Purchase" or "Claim"
            )
            pcall(playBuyBurst)
        end
        RENDER.VipShop(panel)
    end
    -- green studded buy button with shine sweep
    local function buyButton(parent, label, size, pos, onClick, opts)
        opts = opts or {}
        local baseColor = opts.color or SHOP_GREEN
        local holder = create("Frame", {
            BackgroundTransparency = 1,
            Size = size,
            Position = pos,
            AnchorPoint = opts.anchor or Vector2.new(0, 0),
            ZIndex = parent.ZIndex + 2,
        }, parent)
        local dropShadow = create("Frame", {
            BackgroundColor3 = SHOP_BLACK,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(0, 5),
            Size = UDim2.fromScale(1, 1),
            ZIndex = holder.ZIndex,
        }, holder)
        roundCorners(dropShadow, 10)
        local face = create("TextButton", {
            BackgroundColor3 = SHOP_WHITE,
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.fromScale(1, 1),
            ZIndex = holder.ZIndex + 1,
            ClipsDescendants = true,
        }, holder)
        roundCorners(face, 10)
        local isEnabled = opts.disabled ~= true
        local faceColor = isEnabled and baseColor or rgb(120, 128, 150)
        create("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new(faceColor:Lerp(SHOP_WHITE, 0.25), faceColor:Lerp(SHOP_BLACK, 0.15)),
        }, face)
        addStudTexture(face, 0.55, 20)
        create("UIStroke", { Color = SHOP_WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
        create("Frame", {
            BackgroundColor3 = SHOP_WHITE,
            BackgroundTransparency = 0.65,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(8, 4),
            Size = UDim2.new(1, -16, 0, 4),
            ZIndex = face.ZIndex + 1,
        }, face)
        shopLabel(
            face,
            label,
            opts.textSize or 20,
            SHOP_WHITE,
            { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = face.ZIndex + 3 }
        )
        if isEnabled then
            local shine = create("Frame", {
                BackgroundColor3 = SHOP_WHITE,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(1, 1),
                ZIndex = face.ZIndex + 2,
            }, face)
            local shineGradient = create("UIGradient", {
                Rotation = 20,
                Offset = Vector2.new(-1.2, 0),
                Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.42, 1),
                    NumberSequenceKeypoint.new(0.5, 0.45),
                    NumberSequenceKeypoint.new(0.58, 1),
                    NumberSequenceKeypoint.new(1, 1),
                }),
            }, shine)
            task.spawn(function()
                while shine.Parent do
                    shineGradient.Offset = Vector2.new(-1.2, 0)
                    ShopTweenService
                        :Create(
                            shineGradient,
                            TweenInfo.new(0.9, Enum.EasingStyle.Sine),
                            { Offset = Vector2.new(1.2, 0) }
                        )
                        :Play()
                    task.wait(2.6 + math.random())
                end
            end)
            local hoverScale = create("UIScale", {}, holder)
            if opts.pulse then
                ShopTweenService:Create(
                    hoverScale,
                    TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    { Scale = 1.04 }
                ):Play()
            end
            face.MouseEnter:Connect(function()
                UISound.Play("Hover")
                if not opts.pulse then
                    ShopTweenService:Create(hoverScale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.05 })
                        :Play()
                end
            end)
            face.MouseLeave:Connect(function()
                if not opts.pulse then
                    ShopTweenService:Create(hoverScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
                end
            end)
            face.MouseButton1Down:Connect(function()
                face.Position = UDim2.fromOffset(0, 3)
            end)
            face.MouseButton1Up:Connect(function()
                face.Position = UDim2.new()
            end)
            face.Activated:Connect(function()
                UISound.Play("Click")
                if onClick then
                    onClick()
                end
            end)
        end
        return face, holder
    end
    local function badgeTag(parent, labelText, color, pos, anchor, textColor)
        local tagFrame = create("Frame", {
            AnchorPoint = anchor or Vector2.new(1, 0),
            Position = pos,
            Size = UDim2.fromOffset(0, 26),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = color,
            ZIndex = parent.ZIndex + 6,
        }, parent)
        roundCorners(tagFrame, 8)
        create(
            "UIStroke",
            { Color = SHOP_BLACK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            tagFrame
        )
        create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tagFrame)
        shopLabel(tagFrame, labelText, 14, textColor or SHOP_WHITE, {
            Size = UDim2.new(0, 0, 1, 0),
            AutomaticSize = Enum.AutomaticSize.X,
            ZIndex = tagFrame.ZIndex + 1,
            TextXAlignment = Enum.TextXAlignment.Center,
            NoStroke = textColor ~= nil,
        })
        return tagFrame
    end
    local function shopIcon(parent, image, pos, size, zIndex, shouldBob)
        if not image or image == "" then
            return
        end
        local iconImage = create("ImageLabel", {
            BackgroundTransparency = 1,
            Image = image,
            ScaleType = Enum.ScaleType.Fit,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = pos,
            Size = size,
            ZIndex = zIndex or parent.ZIndex + 3,
        }, parent)
        if shouldBob then
            ShopTweenService:Create(
                iconImage,
                TweenInfo.new(1.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Position = pos - UDim2.fromOffset(0, 5) }
            ):Play()
        end
        return iconImage
    end

    -- ===== layout: sidebar + scrolling page =====
    local shopRoot = create(
        "Frame",
        { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, ClipsDescendants = true },
        layer
    )
    local sidebar = create("Frame", {
        Name = "ShopTabs",
        BackgroundColor3 = rgb(20, 13, 43),
        BackgroundTransparency = 0.1,
        Position = UDim2.new(0.018, 0, 0.15, 16),
        Size = UDim2.new(0.18, 0, 0.85, -32),
        ZIndex = 9,
    }, shopRoot)
    roundCorners(sidebar, 12)
    create("UIStroke", { Color = SHOP_WHITE, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, sidebar)
    create("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, sidebar)
    create(
        "UIPadding",
        { PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) },
        sidebar
    )
    local pageScroll = create("ScrollingFrame", {
        Position = UDim2.new(0.215, 0, 0.15, 10),
        Size = UDim2.new(0.77, 0, 0.85, -20),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = rgb(150, 120, 230),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 9,
    }, shopRoot)
    create("UIListLayout", { Padding = UDim.new(0, 16), SortOrder = Enum.SortOrder.LayoutOrder }, pageScroll)
    create("UIPadding", {
        PaddingTop = UDim.new(0, 12),
        PaddingBottom = UDim.new(0, 24),
        PaddingLeft = UDim.new(0, 8),
        PaddingRight = UDim.new(0, 16),
    }, pageScroll)
    local sections = {}
    local layoutOrder = 0
    local function addHeading(title, key)
        layoutOrder += 1
        local headingLabel = shopLabel(
            pageScroll,
            title,
            24,
            SHOP_WHITE,
            { LayoutOrder = layoutOrder, Size = UDim2.new(1, 0, 0, 30), ZIndex = 12 }
        )
        sections[key] = headingLabel
        return headingLabel
    end
    local function addRow(height)
        layoutOrder += 1
        return create(
            "Frame",
            { BackgroundTransparency = 1, LayoutOrder = layoutOrder, Size = UDim2.new(1, 0, 0, height), ZIndex = 10 },
            pageScroll
        )
    end

    -- Limited-deal egg: glowing halo, rotating sparkle ring and the spinning egg model (ShopModels[key]).
    local function addDealEggShowcase(face, limitedDeal)
        local eggBox = create("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.2, 0, 0.56, 0),
            Size = UDim2.fromOffset(190, 190),
            ZIndex = face.ZIndex + 1,
        }, face)
        -- soft halo behind the egg: two breathing glows + a slow ring of sparkles (replaces the hard rays)
        local halo = create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1.55, 1.55),
            BackgroundTransparency = 1,
            Image = FX_IMAGES.glow,
            ImageColor3 = rgb(255, 160, 230),
            ImageTransparency = 0.15,
            ZIndex = eggBox.ZIndex,
        }, eggBox)
        ShopTweenService:Create(
            halo,
            TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { Size = UDim2.fromScale(1.75, 1.75), ImageTransparency = 0.35 }
        ):Play()
        local core = create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.52),
            Size = UDim2.fromScale(1.05, 1.05),
            BackgroundTransparency = 1,
            Image = FX_IMAGES.glow,
            ImageColor3 = rgb(255, 250, 215),
            ImageTransparency = 0,
            ZIndex = eggBox.ZIndex,
        }, eggBox)
        ShopTweenService:Create(
            core,
            TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { ImageTransparency = 0.25 }
        ):Play()
        core.Size = UDim2.fromScale(1.3, 1.3)
        for _, glowSize in { 1.15, 0.95 } do
            create("ImageLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.52),
                Size = UDim2.fromScale(glowSize, glowSize),
                BackgroundTransparency = 1,
                Image = FX_IMAGES.glow,
                ImageColor3 = rgb(255, 255, 240),
                ZIndex = eggBox.ZIndex,
            }, eggBox)
        end -- stacked so the dark egg has a bright light behind it
        local sparkleRing = create("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(1.3, 1.3),
            ZIndex = eggBox.ZIndex,
        }, eggBox)
        for sparkleIndex = 1, 8 do
            local angle = sparkleIndex / 8 * math.pi * 2
            local sparkle = create("ImageLabel", {
                BackgroundTransparency = 1,
                Image = FX_IMAGES.sparkle,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5 + math.cos(angle) * 0.5, 0.5 + math.sin(angle) * 0.5),
                Size = UDim2.fromOffset(sparkleIndex % 2 == 0 and 12 or 18, sparkleIndex % 2 == 0 and 12 or 18),
                ImageColor3 = sparkleIndex % 2 == 0 and SHOP_WHITE or rgb(255, 225, 140),
                ZIndex = eggBox.ZIndex + 2,
            }, sparkleRing)
            ShopTweenService
                :Create(
                    sparkle,
                    TweenInfo.new(0.7 + sparkleIndex * 0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    { ImageTransparency = 0.8 }
                )
                :Play()
        end
        ShopTweenService:Create(
            sparkleRing,
            TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
            { Rotation = 360 }
        ):Play()
        local eggViewport = create("ViewportFrame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            ZIndex = eggBox.ZIndex + 1,
            Ambient = rgb(255, 255, 255),
            LightColor = rgb(255, 255, 255),
            LightDirection = Vector3.new(-0.4, -0.6, -1),
        }, eggBox) -- bright so the dark egg reads
        local eggTemplate = shopSystem:FindFirstChild("ShopModels")
            and shopSystem.ShopModels:FindFirstChild(limitedDeal.key)
        if eggTemplate then
            local egg = eggTemplate:Clone()
            egg.Parent = eggViewport
            local boundsCFrame, boundsSize = egg:GetBoundingBox()
            egg:PivotTo(CFrame.new(-boundsCFrame.Position) * egg:GetPivot())
            local camera = create("Camera", { FieldOfView = 40 }, eggViewport)
            eggViewport.CurrentCamera = camera
            camera.CFrame =
                CFrame.lookAt(Vector3.new(0, boundsSize.Y * 0.08, -boundsSize.Magnitude * 1.2), Vector3.zero)
            local basePivot = egg:GetPivot()
            local spinStart = os.clock()
            local spinConnection
            spinConnection = RunService.RenderStepped:Connect(function()
                if not eggViewport.Parent then
                    spinConnection:Disconnect()
                    return
                end
                local elapsed = os.clock() - spinStart
                egg:PivotTo(
                    CFrame.new(0, math.sin(elapsed * 2) * 0.25, 0) * CFrame.Angles(0, elapsed * 0.9, 0) * basePivot
                )
            end)
        end
    end
    -- DAYS / HRS / MIN / SEC boxes, ticking while the shop stays open.
    local function addDealCountdown(dealInfo, limitedDeal)
        -- countdown boxes
        local countdownRow = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(0, 78),
            Size = UDim2.new(1, 0, 0, 64),
            ZIndex = dealInfo.ZIndex,
        }, dealInfo)
        create("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }, countdownRow)
        local countdownLabels = {}
        for i, unit in { "DAYS", "HRS", "MIN", "SEC" } do
            local unitBox = create("Frame", {
                LayoutOrder = i,
                BackgroundColor3 = rgb(20, 14, 40),
                Size = UDim2.fromOffset(66, 64),
                ZIndex = countdownRow.ZIndex + 1,
            }, countdownRow)
            roundCorners(unitBox, 10)
            create(
                "UIStroke",
                { Color = SHOP_WHITE, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
                unitBox
            )
            countdownLabels[i] = shopLabel(unitBox, "00", 28, GOLD, {
                Size = UDim2.new(1, 0, 0, 38),
                Position = UDim2.fromOffset(0, 2),
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = unitBox.ZIndex + 1,
            })
            shopLabel(unitBox, unit, 11, rgb(200, 190, 230), {
                Size = UDim2.new(1, 0, 0, 16),
                Position = UDim2.fromOffset(0, 42),
                TextXAlignment = Enum.TextXAlignment.Center,
                ZIndex = unitBox.ZIndex + 1,
                NoStroke = true,
            })
        end
        task.spawn(function()
            while countdownLabels[1].Parent and panel.Visible do
                local secondsLeft = math.max(0, limitedDeal.endsAt - os.time())
                countdownLabels[1].Text = string.format("%02d", secondsLeft // 86400)
                countdownLabels[2].Text = string.format("%02d", (secondsLeft // 3600) % 24)
                countdownLabels[3].Text = string.format("%02d", (secondsLeft // 60) % 60)
                countdownLabels[4].Text = string.format("%02d", secondsLeft % 60)
                task.wait(1)
            end
        end)
    end

    -- ===== FEATURED: limited deal =====
    local limitedDeal = ShopConfig.LimitedDeal
    sections.FEATURED = addRow(0)
    if limitedDeal then
        local dealRow = addRow(250)
        local face, _, faceStroke = glowCard(dealRow, PINK, UDim2.fromScale(1, 1))
        faceStroke.Thickness = 5
        local rainbowGradient = create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, GOLD),
                ColorSequenceKeypoint.new(0.33, SHOP_WHITE),
                ColorSequenceKeypoint.new(0.66, rgb(255, 90, 200)),
                ColorSequenceKeypoint.new(1, rgb(90, 220, 255)),
            }),
        }, faceStroke)
        ShopTweenService:Create(
            rainbowGradient,
            TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
            { Rotation = 360 }
        ):Play()
        badgeTag(face, "🔥 LIMITED DEAL", RED, UDim2.fromOffset(14, 12), Vector2.new(0, 0))
        addDealEggShowcase(face, limitedDeal)
        local dealInfo = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.4, 0, 0, 22),
            Size = UDim2.new(0.57, 0, 1, -30),
            ZIndex = face.ZIndex + 1,
        }, face)
        shopLabel(dealInfo, limitedDeal.name, 38, SHOP_WHITE, { Size = UDim2.new(1, 0, 0, 44) })
        shopLabel(
            dealInfo,
            limitedDeal.text,
            16,
            rgb(255, 225, 240),
            { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 46) }
        )
        addDealCountdown(dealInfo, limitedDeal)
        local productId = ShopConfig.Products[limitedDeal.key]
        buyButton(
            dealInfo,
            ShopConfig.Prices[limitedDeal.key]
                    and ("BUY  R$ " .. livePrice(productId, false, ShopConfig.Prices[limitedDeal.key]))
                or "SOON",
            UDim2.fromOffset(260, 58),
            UDim2.new(1, -4, 1, -8),
            function()
                shopAction("Buy", limitedDeal.key)
            end,
            { anchor = Vector2.new(1, 1), textSize = 24, pulse = true }
        )
        addFloatingSparkles(face, 9, rgb(255, 235, 160))
    end

    -- ===== BOOSTS =====
    addHeading("BOOSTS", "BOOSTS")
    local boostRow = addRow(160)
    local function boostCard(slotIndex, slotCount, title, desc, key, color, image, activeUntil, isGamePass, isOwned)
        local face = glowCard(
            boostRow,
            color,
            UDim2.new(1 / slotCount, -10, 1, 0),
            UDim2.new((slotIndex - 1) / slotCount, 5, 0, 0)
        )
        shopIcon(face, image, UDim2.new(0, 56, 0.5, -8), UDim2.fromOffset(84, 84), nil, true)
        shopLabel(
            face,
            title,
            22,
            SHOP_WHITE,
            { Position = UDim2.fromOffset(108, 12), Size = UDim2.new(1, -116, 0, 28), TextScaled = true }
        )
        local descLabel = shopLabel(
            face,
            desc,
            13,
            rgb(240, 240, 255),
            { Position = UDim2.fromOffset(108, 42), Size = UDim2.new(1, -116, 0, 34), NoStroke = true }
        )
        if activeUntil and activeUntil > shopState.serverTime then
            local timerTrack = create("Frame", {
                BackgroundColor3 = rgb(13, 10, 20),
                Position = UDim2.fromOffset(108, 84),
                Size = UDim2.new(1, -124, 0, 16),
                ZIndex = face.ZIndex + 2,
            }, face)
            roundCorners(timerTrack, 8)
            create("UIStroke", { Color = SHOP_WHITE, Thickness = 2 }, timerTrack)
            local timerFill = create("Frame", {
                BackgroundColor3 = SHOP_WHITE,
                BorderSizePixel = 0,
                Size = UDim2.fromScale(0.5, 1),
                ZIndex = timerTrack.ZIndex + 1,
            }, timerTrack)
            roundCorners(timerFill, 8)
            create("UIGradient", { Color = ColorSequence.new(rgb(150, 255, 120), rgb(60, 200, 60)) }, timerFill)
            local activeLabel = shopLabel(
                face,
                "",
                13,
                SHOP_WHITE,
                { Position = UDim2.fromOffset(108, 104), Size = UDim2.new(1, -116, 0, 18) }
            )
            local startClock = os.clock()
            task.spawn(function()
                while activeLabel.Parent and panel.Visible do
                    local secondsLeft = activeUntil - (shopState.serverTime + os.clock() - startClock)
                    timerFill.Size =
                        UDim2.fromScale(math.clamp(secondsLeft / ((ShopConfig.BoostMinutes or 30) * 60), 0.03, 1), 1)
                    activeLabel.Text = secondsLeft > 0 and ("ACTIVE " .. formatHms(secondsLeft)) or "ENDED"
                    task.wait(1)
                end
            end)
        end
        buyButton(
            face,
            isOwned and "OWNED" or priceText(key, isGamePass),
            UDim2.fromOffset(140, 44),
            UDim2.new(1, -14, 1, -14),
            (not isOwned) and function()
                shopAction("Buy", key)
            end or nil,
            { anchor = Vector2.new(1, 1), disabled = isOwned, textSize = 18 }
        )
        addFloatingSparkles(face, 3)
        return descLabel
    end
    boostCard(
        1,
        3,
        "2× MONEY",
        ShopConfig.BoostMinutes .. " min of double cash",
        "Money2x",
        SHOP_GREEN,
        SHOP_ICONS.Money2x,
        shopState.money2xUntil
    )
    boostCard(
        2,
        3,
        "2× HATCH",
        "Eggs hatch twice as fast",
        "Hatch2x",
        GOLD,
        SHOP_ICONS.Hatch2x,
        shopState.hatch2xUntil
    )
    boostCard(
        3,
        3,
        "STARTER PACK",
        "$"
            .. Config.Short(ShopConfig.StarterPack.cash)
            .. " + "
            .. ShopConfig.StarterPack.boostMinutes
            .. " min 2× money & hatch",
        "StarterPack",
        PURP,
        SHOP_ICONS.StarterPack,
        nil,
        true,
        shopState.starter
    )

    -- ===== PASSES: VIP + money multiplier =====
    addHeading("PASSES", "PASSES")
    local passRow = addRow(170)
    do
        local face = glowCard(passRow, PURP, UDim2.new(0.5, -8, 1, 0), UDim2.fromScale(0, 0))
        shopIcon(face, SHOP_ICONS.Crown, UDim2.new(0, 70, 0.5, 0), UDim2.fromOffset(110, 110), nil, true)
        shopLabel(face, "VIP", 34, GOLD, { Position = UDim2.fromOffset(136, 12), Size = UDim2.new(1, -144, 0, 40) })
        shopLabel(
            face,
            "Crown + gold chat tag\n+10% cash · 2× daily cash",
            14,
            rgb(235, 225, 255),
            { Position = UDim2.fromOffset(136, 54), Size = UDim2.new(1, -144, 0, 40), NoStroke = true }
        )
        buyButton(
            face,
            shopState.vip and "OWNED" or priceText("VIP", true),
            UDim2.fromOffset(170, 50),
            UDim2.new(1, -14, 1, -14),
            (not shopState.vip) and function()
                shopAction("Buy", "VIP")
            end or nil,
            { anchor = Vector2.new(1, 1), disabled = shopState.vip, color = GOLD, textSize = 20 }
        )
        addFloatingSparkles(face, 4, rgb(255, 230, 140))
    end
    do
        local moneyLevel = shopState.moneyLevel or 0
        local currentMult = moneyLevel > 0 and ShopConfig.MoneyLevels[moneyLevel].mult or 1
        local nextLevel = ShopConfig.MoneyLevels[moneyLevel + 1]
        local face = glowCard(passRow, SHOP_GREEN, UDim2.new(0.5, -8, 1, 0), UDim2.new(0.5, 8, 0, 0))
        shopIcon(face, SHOP_ICONS.Coins, UDim2.new(0, 64, 0.5, -6), UDim2.fromOffset(96, 96), nil, true)
        shopLabel(
            face,
            "MONEY MULTIPLIER",
            20,
            SHOP_WHITE,
            { Position = UDim2.fromOffset(124, 12), Size = UDim2.new(1, -132, 0, 26) }
        )
        shopLabel(
            face,
            nextLevel and (currentMult .. "×  →  " .. nextLevel.mult .. "×") or (currentMult .. "×  MAXED!"),
            28,
            rgb(200, 255, 170),
            { Position = UDim2.fromOffset(124, 42), Size = UDim2.new(1, -132, 0, 34) }
        )
        local pips = create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(124, 82),
            Size = UDim2.new(1, -132, 0, 16),
            ZIndex = face.ZIndex + 2,
        }, face)
        create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4) }, pips)
        for i = 1, #ShopConfig.MoneyLevels do
            local pip = create("Frame", {
                BackgroundColor3 = i <= moneyLevel and GOLD or rgb(30, 60, 30),
                Size = UDim2.fromOffset(14, 14),
                ZIndex = pips.ZIndex,
            }, pips)
            roundCorners(pip, 4)
            create("UIStroke", { Color = SHOP_BLACK, Thickness = 1.5 }, pip)
        end
        if nextLevel then
            buyButton(
                face,
                nextLevel.productId == 0 and "SOON" or ("R$ " .. livePrice(nextLevel.productId, false, nextLevel.robux)),
                UDim2.fromOffset(150, 46),
                UDim2.new(1, -14, 1, -14),
                function()
                    shopAction("BuyMoneyLevel")
                end,
                { anchor = Vector2.new(1, 1), textSize = 20 }
            )
        end
        addFloatingSparkles(face, 3)
    end

    -- ===== CASH PACKS =====
    addHeading("CASH PACKS", "CASH")
    local cashRow = addRow(210)
    local cashPackKeys = { "CashSmall", "CashMedium", "CashLarge" }
    local function robuxPriceOf(productKey)
        return tonumber(livePrice(ShopConfig.Products[productKey], false, ShopConfig.Prices[productKey]))
            or ShopConfig.Prices[productKey]
            or 1
    end
    local baseRate = (ShopConfig.CashPacks.CashSmall or 1) / math.max(robuxPriceOf("CashSmall"), 1)
    for i, packKey in cashPackKeys do
        local cardColor = ({ BLUE, GOLD, BLUE })[i]
        local face, _, faceStroke, glow =
            glowCard(cashRow, cardColor, UDim2.new(1 / 3, -10, 1, 0), UDim2.new((i - 1) / 3, 5, 0, 0))
        local amount = ShopConfig.CashPacks[packKey] or 0
        local coinCount = ({ 1, 3, 6 })[i]
        for coinIndex = 1, coinCount do
            shopIcon(
                face,
                SHOP_ICONS.Coins,
                UDim2.new(0.5, (coinIndex - (coinCount + 1) / 2) * 22, 0, 60 - (coinIndex % 2) * 8),
                UDim2.fromOffset(46, 46),
                face.ZIndex + 3 + coinIndex
            )
        end
        shopLabel(face, "$" .. Config.Short(amount), 32, rgb(150, 255, 120), {
            Position = UDim2.fromOffset(0, 96),
            Size = UDim2.new(1, 0, 0, 38),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        local rate = amount / math.max(robuxPriceOf(packKey), 1)
        local bonus = math.floor((rate / baseRate - 1) * 100 + 0.5)
        if i == 2 then
            badgeTag(face, "MOST POPULAR", RED, UDim2.new(1, -10, 0, 10))
            faceStroke.Color = rgb(255, 90, 100)
            ShopTweenService:Create(
                faceStroke,
                TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Thickness = 5 }
            ):Play()
            glow.ImageColor3 = rgb(255, 90, 100)
        elseif bonus > 0 then
            badgeTag(face, "+" .. bonus .. "% MORE", GOLD, UDim2.new(1, -10, 0, 10), nil, SHOP_BLACK)
        end
        buyButton(
            face,
            ShopConfig.Products[packKey] == 0 and "SOON" or priceText(packKey),
            UDim2.new(1, -28, 0, 50),
            UDim2.new(0.5, 0, 1, -14),
            function()
                shopAction("Buy", packKey)
            end,
            { anchor = Vector2.new(0.5, 1), textSize = 22 }
        )
        addFloatingSparkles(face, 3 + i, rgb(255, 240, 160))
    end

    -- ===== DAILY REWARDS =====
    addHeading("DAILY REWARDS", "DAILY")
    local daily = shopState.daily
    local dailyRow = addRow(220)
    local dailyCard = glowCard(dailyRow, BLUE, UDim2.fromScale(1, 1))
    for i, reward in ShopConfig.Daily do
        local isClaimed = (i < daily.day) or (i == daily.day and not daily.ready)
        local isToday = i == daily.day and daily.ready
        local dayColor = isToday and GOLD or (i == 7 and RED or rgb(42, 31, 74))
        local dayCard = glowCard(
            dailyCard,
            dayColor,
            UDim2.new(1 / 7, -10, 0, 128),
            UDim2.new((i - 1) / 7, 5, 0, 16),
            dailyCard.ZIndex + 1
        )
        shopLabel(dayCard, "DAY " .. i, 14, SHOP_WHITE, {
            Position = UDim2.fromOffset(0, 6),
            Size = UDim2.new(1, 0, 0, 18),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        local iconKey = reward.kind == "cash" and "Coins"
            or reward.kind == "mystery" and (SHOP_ICONS.Chalice and "Chalice" or "Chest")
            or reward.boost
        shopIcon(dayCard, SHOP_ICONS[iconKey], UDim2.new(0.5, 0, 0, 54), UDim2.fromOffset(44, 44), nil, isToday)
        shopLabel(
            dayCard,
            reward.label or ("$" .. Config.Short(reward.amount)),
            13,
            reward.kind == "cash" and rgb(150, 255, 120) or rgb(230, 200, 255),
            {
                Position = UDim2.fromOffset(2, 80),
                Size = UDim2.new(1, -4, 0, 28),
                TextXAlignment = Enum.TextXAlignment.Center,
            }
        )
        shopLabel(
            dayCard,
            isClaimed and "✓" or (isToday and "READY" or "🔒"),
            13,
            isClaimed and SHOP_GREEN or SHOP_WHITE,
            {
                Position = UDim2.new(0, 0, 1, -22),
                Size = UDim2.new(1, 0, 0, 18),
                TextXAlignment = Enum.TextXAlignment.Center,
            }
        )
        if isToday then
            local dayStroke = dayCard:FindFirstChildOfClass("UIStroke")
            if dayStroke then
                ShopTweenService:Create(
                    dayStroke,
                    TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    { Thickness = 5 }
                ):Play()
            end
        end
    end
    if daily.ready then
        buyButton(dailyCard, "CLAIM DAY " .. daily.day, UDim2.fromOffset(260, 46), UDim2.new(0.5, 0, 1, -12), function()
            shopAction("ClaimDaily")
        end, { anchor = Vector2.new(0.5, 1), textSize = 20, pulse = true })
    else
        local nextLabel = shopLabel(dailyCard, "Next reward in " .. formatHms(daily.nextIn), 17, rgb(220, 225, 255), {
            Position = UDim2.new(0, 0, 1, -40),
            Size = UDim2.new(1, 0, 0, 24),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        local nextRewardAt = os.clock() + daily.nextIn
        task.spawn(function()
            while nextLabel.Parent and panel.Visible do
                nextLabel.Text = "Next reward in " .. formatHms(nextRewardAt - os.clock())
                task.wait(1)
            end
        end)
    end

    -- ===== sidebar tabs: jump to a section =====
    local SIDEBAR_TABS = {
        { "FEATURED", SHOP_ICONS.Fire or SHOP_ICONS.StarterPack, PINK },
        { "BOOSTS", SHOP_ICONS.Money2x, SHOP_GREEN },
        { "PASSES", SHOP_ICONS.Crown, PURP },
        { "CASH", SHOP_ICONS.Coins, GOLD },
        { "DAILY", SHOP_ICONS.Chest, BLUE },
    }
    local tabFaces = {}
    local function setActiveTab(name)
        for tabName, tab in tabFaces do
            local isActive = tabName == name
            tab.face.BackgroundColor3 = isActive and tab.color or rgb(53, 40, 98)
            tab.stroke.Thickness = isActive and 4 or 2.5
        end
    end
    for i, tabDef in SIDEBAR_TABS do
        local tabButton = create("TextButton", {
            LayoutOrder = i,
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = rgb(53, 40, 98),
            Size = UDim2.new(1, 0, 0, 58),
            ZIndex = 11,
        }, sidebar)
        roundCorners(tabButton, 10)
        addStudTexture(tabButton, 0.65, 20)
        local tabStroke = create(
            "UIStroke",
            { Color = SHOP_WHITE, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            tabButton
        )
        shopIcon(tabButton, tabDef[2], UDim2.new(0, 28, 0.5, 0), UDim2.fromOffset(38, 38), 13)
        shopLabel(
            tabButton,
            tabDef[1],
            16,
            SHOP_WHITE,
            { Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -56, 1, 0), ZIndex = 13 }
        )
        tabFaces[tabDef[1]] = { face = tabButton, stroke = tabStroke, color = tabDef[3] }
        if tabDef[1] == "DAILY" and daily.ready then
            local alertBadge = create("Frame", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(1, -6, 0, 6),
                Size = UDim2.fromOffset(24, 24),
                BackgroundColor3 = RED,
                ZIndex = 15,
            }, tabButton)
            roundCorners(alertBadge, 12)
            create("UIStroke", { Color = SHOP_WHITE, Thickness = 2 }, alertBadge)
            shopLabel(
                alertBadge,
                "!",
                16,
                SHOP_WHITE,
                { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 16 }
            )
            local badgeScale = create("UIScale", {}, alertBadge)
            ShopTweenService:Create(
                badgeScale,
                TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Scale = 1.2 }
            ):Play()
        end
        local hoverScale = create("UIScale", {}, tabButton)
        tabButton.MouseEnter:Connect(function()
            UISound.Play("Hover")
            ShopTweenService:Create(hoverScale, TweenInfo.new(0.1), { Scale = 1.05 }):Play()
        end)
        tabButton.MouseLeave:Connect(function()
            ShopTweenService:Create(hoverScale, TweenInfo.new(0.1), { Scale = 1 }):Play()
        end)
        tabButton.Activated:Connect(function()
            UISound.Play("Click")
            local target = sections[tabDef[1]]
            if target then
                local scrollY = target.AbsolutePosition.Y
                    - pageScroll.AbsolutePosition.Y
                    + pageScroll.CanvasPosition.Y
                    - 8
                ShopTweenService:Create(
                    pageScroll,
                    TweenInfo.new(0.35, Enum.EasingStyle.Quad),
                    { CanvasPosition = Vector2.new(0, math.max(0, scrollY)) }
                ):Play()
            end
            setActiveTab(tabDef[1])
        end)
    end
    setActiveTab("FEATURED")
    pageScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        local bestTab, bestTabY = "FEATURED", -math.huge
        for _, tabDef in SIDEBAR_TABS do
            local sectionHeading = sections[tabDef[1]]
            if sectionHeading then
                local sectionY = sectionHeading.AbsolutePosition.Y - pageScroll.AbsolutePosition.Y
                if sectionY <= 40 and sectionY > bestTabY then
                    bestTab, bestTabY = tabDef[1], sectionY
                end
            end
        end
        setActiveTab(bestTab)
    end)
end

-- ===== 9. Plot panel ("My Temple") =====
-- _plotTabs / _legacyOverview / _legacyUpgrades (and plotPage) are the old pages; nothing calls them any more
-- because RENDER.Plot draws the Figma layout. Kept for reference.
local plotPage = "overview" -- "overview" | "upgrades"
local SLOT_PRICES =
    { 0, 250, 2500, 25000, 150000, 750000, 5000000, 25000000, 150000000, 750000000, 3000000000, 15000000000 }

-- The workspace.Plots child owned by the local player (nil if none yet).
local function findMyPlot()
    for _, plot in workspace.Plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            return plot
        end
    end
end

-- page switch tab on top of the panel
local function _plotTabs(layer, panel)
    local bar = box(layer, 0.5, 0.235, 0.9, 0.065)
    bar.Name = "PlotTabs"
    local function tab(x, label, page)
        local isActive = plotPage == page
        local tabButton = button(
            bar,
            x,
            0.5,
            0.48,
            1,
            label,
            isActive and Color3.fromRGB(214, 52, 45) or Color3.fromRGB(150, 120, 100)
        )
        tabButton.Name = page == "upgrades" and "UpgradesTab" or "OverviewTab"
        tabButton.Activated:Connect(function()
            if plotPage ~= page then
                plotPage = page
                RENDER.Plot(panel)
            end
        end)
    end
    tab(0.25, "OVERVIEW", "overview")
    tab(0.75, "UPGRADES", "upgrades")
end

local function _legacyOverview(layer, data)
    local plot = findMyPlot()
    local placed, storedCount, income = {}, 0, 0
    for _, item in data.items or {} do
        if item.state == "placed" then
            table.insert(placed, item)
            income += item.income or 0
        else
            storedCount += 1
        end
    end
    local level = data.level or 1
    local slotCap = data.availableSlots or level * 12
    local unlockedCount = data.unlocked or 0
    local RED = Color3.fromRGB(188, 57, 44)
    local MUTED = Color3.fromRGB(170, 195, 205)
    local PAPER = Color3.fromRGB(34, 58, 70)
    local sheet =
        box(layer, 0.5, 0.615, 0.9, 0.65, { BackgroundTransparency = 0, BackgroundColor3 = CREAM, ZIndex = 7 })
    sheet.Name = "PlotContent"
    create("UICorner", { CornerRadius = UDim.new(0, 14) }, sheet)
    local scroll = create("ScrollingFrame", {
        Name = "Sections",
        Size = UDim2.new(1, -8, 1, -8),
        Position = UDim2.fromOffset(4, 4),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Color3.fromRGB(75, 125, 145),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 8,
    }, sheet)
    create("UIPadding", {
        PaddingLeft = UDim.new(0, 5),
        PaddingRight = UDim.new(0, 12),
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 8),
    }, scroll)
    create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
    local order = 0
    local function section(name, height)
        order += 1
        local sectionFrame = create("Frame", {
            Name = name,
            LayoutOrder = order,
            Size = UDim2.new(1, 0, 0, height),
            BackgroundColor3 = PAPER,
            BorderSizePixel = 0,
            ZIndex = 8,
        }, scroll)
        create("UIStroke", {
            Color = Color3.new(0, 0, 0),
            Thickness = 3,
            LineJoinMode = Enum.LineJoinMode.Miter,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, sectionFrame)
        create("Frame", {
            Name = "Accent",
            BackgroundColor3 = SKINS.Plot.grad[1],
            BorderSizePixel = 0,
            Size = UDim2.new(0, 6, 1, 0),
            ZIndex = 9,
        }, sectionFrame)
        return sectionFrame
    end
    local function label(parent, str, x, y, w, h, size, color)
        return text(parent, str, color or INK, {
            Position = UDim2.new(x, 0, 0, y),
            Size = UDim2.new(w, 0, 0, h),
            X = Enum.TextXAlignment.Left,
            Max = size,
            ZIndex = 10,
        })
    end
    local function addActionButton(parent, name, x, y, w, h, labelText, color, callback)
        local buttonInstance = create("TextButton", {
            Name = name,
            AnchorPoint = Vector2.new(0, 0),
            Position = UDim2.new(x, 0, 0, y),
            Size = UDim2.new(w, 0, 0, h),
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            ZIndex = 10,
        }, parent)
        create("UIStroke", {
            Color = Color3.new(0, 0, 0),
            Thickness = 2.5,
            LineJoinMode = Enum.LineJoinMode.Miter,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, buttonInstance)
        local _buttonLabel = text(
            buttonInstance,
            labelText,
            Color3.new(1, 1, 1),
            { Position = UDim2.new(0, 7, 0, 4), Size = UDim2.new(1, -14, 1, -8), Max = 16, ZIndex = 11 }
        )
        buttonInstance.MouseEnter:Connect(function()
            UISound.Play("Hover")
            TweenService
                :Create(
                    buttonInstance,
                    TweenInfo.new(0.12),
                    { BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.1) }
                )
                :Play()
        end)
        buttonInstance.MouseLeave:Connect(function()
            TweenService:Create(buttonInstance, TweenInfo.new(0.12), { BackgroundColor3 = color }):Play()
        end)
        if callback then
            buttonInstance.Activated:Connect(function()
                UISound.Play("Click")
                callback()
            end)
        else
            buttonInstance.Interactable = false
        end
        return buttonInstance
    end
    local hero = section("TempleSummary", 86)
    label(hero, "TEMPLE  /  LEVEL " .. level, 0.035, 12, 0.59, 25, 23)
    label(
        hero,
        level >= 3 and "Your temple is fully upgraded" or "Unlock every slot to open the next floor",
        0.035,
        44,
        0.59,
        25,
        14,
        MUTED
    )
    addActionButton(
        hero,
        "UpgradeTemple",
        0.66,
        23,
        0.305,
        40,
        level >= 3 and "MAX LEVEL"
            or data.canUpgrade and ("UPGRADE $" .. Config.Short(
                require(game.ReplicatedStorage.UpgradePrices).Temple[level + 1]
            ))
            or unlockedCount .. " / " .. slotCap .. " SLOTS",
        data.canUpgrade and RED or Color3.fromRGB(70, 92, 104),
        level < 3
                and function()
                    if data.canUpgrade then
                        runAction("UpgradeTemple")
                    else
                        showToast("Unlock all " .. slotCap .. " slots to open the next floor")
                    end
                end
            or nil
    )
    local stats = section("Stats", 58)
    for i, stat in
        {
            { title = "INCOME / SEC", value = "$" .. Config.Short(income), color = Color3.fromRGB(60, 137, 65) },
            { title = "CHARACTERS PLACED", value = #placed .. " / " .. unlockedCount },
            { title = "IN BACKPACK", value = tostring(storedCount) },
        }
    do
        local columnX = 0.035 + (i - 1) * 0.325
        label(stats, stat.title, columnX, 7, 0.3, 17, 11, MUTED)
        label(stats, stat.value, columnX, 25, 0.3, 25, 22, stat.color)
    end
    local incubators = section("Incubators", 150)
    label(incubators, "INCUBATORS", 0.035, 10, 0.8, 24, 18)
    local chambers = plot and plot:FindFirstChild("Chambers")
    local chamberCount = chambers and #chambers:GetChildren() or 0
    for i = 1, 3 do
        local columnX = 0.035 + (i - 1) * 0.325
        local incubatorCard = create("Frame", {
            Name = "Incubator" .. i,
            Position = UDim2.new(columnX, 0, 0, 43),
            Size = UDim2.new(0.305, 0, 0, 95),
            BackgroundColor3 = Color3.fromRGB(40, 66, 80),
            BorderSizePixel = 0,
            ZIndex = 9,
        }, incubators)
        create("UICorner", { CornerRadius = UDim.new(0, 8) }, incubatorCard)
        local chamber = chambers and chambers:FindFirstChild("Chamber" .. i)
        local chamberLevel = chamber and (chamber:GetAttribute("UpgradeLevel") or 1)
        label(
            incubatorCard,
            "#" .. i .. (chamberLevel and "   LEVEL " .. chamberLevel or "   LOCKED"),
            0.07,
            6,
            0.88,
            20,
            15
        )
        local status = chamber and tostring(chamber:GetAttribute("Status") or "Ready")
            or (i == chamberCount + 1 and "Expand your hatchery" or "Buy the previous incubator")
        label(incubatorCard, status, 0.07, 29, 0.88, 18, 12, MUTED)
        if chamber then
            addActionButton(
                incubatorCard,
                "UpgradeIncubator" .. i,
                0.07,
                55,
                0.86,
                31,
                chamberLevel < 3
                        and ("UPGRADE $" .. Config.Short(
                            require(game.ReplicatedStorage.UpgradePrices).IncubatorLevel[chamberLevel + 1]
                        ))
                    or "MAX LEVEL",
                chamberLevel < 3 and RED or MUTED,
                chamberLevel < 3
                        and function()
                            runAction("UpgradeIncubator", { index = i })
                        end
                    or nil
            )
        elseif i == chamberCount + 1 then
            addActionButton(
                incubatorCard,
                "AddIncubator",
                0.07,
                55,
                0.86,
                31,
                "+ ADD $" .. Config.Short(require(game.ReplicatedStorage.UpgradePrices).AddIncubator[i]),
                Color3.fromRGB(70, 151, 74),
                function()
                    runAction("AddIncubator")
                end
            )
        end
    end
    local slots = section("CharacterSlots", 168)
    label(slots, "CHARACTER SLOTS", 0.035, 10, 0.6, 24, 18)
    label(slots, unlockedCount .. " / " .. slotCap .. " unlocked", 0.67, 12, 0.3, 20, 14, MUTED)
    local nextPrice
    for i = 1, slotCap do
        local slot = plot and plot.Slots:FindFirstChild(string.format("Slot%02d", i))
        if slot and not slot:GetAttribute("Unlocked") then
            nextPrice = slot:GetAttribute("UnlockPrice")
            break
        end
    end
    local track = create("Frame", {
        Position = UDim2.new(0.035, 0, 0, 43),
        Size = UDim2.new(0.93, 0, 0, 6),
        BackgroundColor3 = Color3.fromRGB(20, 30, 36),
        BorderSizePixel = 0,
        ZIndex = 9,
    }, slots)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
    local fill = create("Frame", {
        Size = UDim2.fromScale(math.clamp(unlockedCount / slotCap, 0, 1), 1),
        BackgroundColor3 = Color3.fromRGB(91, 163, 80),
        BorderSizePixel = 0,
        ZIndex = 10,
    }, track)
    create("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
    label(
        slots,
        #placed .. " working  ·  " .. math.max(0, unlockedCount - #placed) .. " empty",
        0.035,
        56,
        0.53,
        22,
        15,
        MUTED
    )
    addActionButton(
        slots,
        "UnlockSlot",
        0.60,
        56,
        0.365,
        34,
        nextPrice and "UNLOCK  $" .. Config.Short(nextPrice) or "ALL UNLOCKED",
        nextPrice and Color3.fromRGB(70, 151, 74) or MUTED,
        nextPrice and function()
            runAction("UnlockSlot")
        end or nil
    )
    local placedList = create("ScrollingFrame", {
        Name = "PlacedCharacters",
        Position = UDim2.new(0.035, 0, 0, 101),
        Size = UDim2.new(0.93, 0, 0, 55),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.X,
        ScrollingDirection = Enum.ScrollingDirection.X,
        ZIndex = 9,
    }, slots)
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, placedList)
    table.sort(placed, function(a, b)
        return (a.income or 0) > (b.income or 0)
    end)
    if #placed == 0 then
        label(placedList, "Place a character to start earning cash.", 0, 7, 1, 28, 14, MUTED)
    else
        for i, item in placed do
            local characterCard = create("Frame", {
                Name = "Character" .. i,
                LayoutOrder = i,
                Size = UDim2.fromOffset(145, 46),
                BackgroundColor3 = Color3.fromRGB(40, 66, 80),
                BorderSizePixel = 0,
                ZIndex = 10,
            }, placedList)
            create("UICorner", { CornerRadius = UDim.new(0, 7) }, characterCard)
            label(characterCard, item.name, 0.06, 3, 0.88, 20, 14, RARITY_COLORS[item.rarity] or INK)
            label(
                characterCard,
                "$" .. Config.Short(item.income or 0) .. "/sec",
                0.06,
                24,
                0.88,
                16,
                12,
                Color3.fromRGB(60, 137, 65)
            )
        end
    end
    local footer = section("QuickActions", 48)
    label(footer, "Put your strongest characters to work", 0.035, 10, 0.59, 28, 14, MUTED)
    addActionButton(footer, "EquipBest", 0.66, 7, 0.305, 34, "EQUIP BEST", Color3.fromRGB(66, 126, 177), function()
        runAction("EquipBest")
    end)
    task.defer(function()
        if scroll.Parent then
            scroll.CanvasPosition = Vector2.zero
        end
    end)
end

local function _legacyUpgrades(layer, data)
    -- cover the baked overview art inside the panel with one clean cream sheet
    local sheet = box(
        layer,
        0.5,
        0.57,
        0.9,
        0.55,
        { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(26, 44, 52), ZIndex = 7 }
    )
    create("UICorner", { CornerRadius = UDim.new(0.06, 0) }, sheet)
    create("UIStroke", { Color = Color3.fromRGB(205, 170, 120), Thickness = 2 }, sheet)
    local cover = box(
        layer,
        0.496,
        0.887,
        0.27,
        0.105,
        { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(26, 44, 52), ZIndex = 7 }
    )
    create("UICorner", { CornerRadius = UDim.new(0.4, 0) }, cover)
    text(cover, "Upgrades work from anywhere on your plot", Color3.fromRGB(150, 115, 90), {
        Size = UDim2.fromScale(0.95, 0.42),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Max = 14,
    })
    local function row(y, title)
        local rowFrame = box(
            sheet,
            0.5,
            y,
            0.94,
            0.27,
            { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(34, 58, 70), ZIndex = 8 }
        )
        create("UICorner", { CornerRadius = UDim.new(0.2, 0) }, rowFrame)
        text(rowFrame, title, Color3.fromRGB(200, 60, 45), {
            Size = UDim2.fromScale(0.24, 0.32),
            Position = UDim2.fromScale(0.02, 0.06),
            X = Enum.TextXAlignment.Left,
            ZIndex = 9,
            Max = 18,
        })
        return rowFrame
    end
    local plot = findMyPlot()

    -- TEMPLE
    local templeRow = row(0.17, "TEMPLE")
    templeRow.Name = "TempleUpgrades"
    local templeLevel = data.level or 1
    for i = 1, 3 do
        local pip = box(templeRow, 0.06 + i * 0.075, 0.66, 0.06, 0.36, {
            BackgroundTransparency = 0,
            BackgroundColor3 = i <= templeLevel and Color3.fromRGB(235, 175, 30) or Color3.fromRGB(50, 70, 80),
            ZIndex = 9,
        })
        create("UICorner", { CornerRadius = UDim.new(0.3, 0) }, pip)
        create("UIStroke", { Color = INK, Thickness = 2 }, pip)
    end
    text(templeRow, "Level " .. templeLevel .. " / 3", INK, {
        Size = UDim2.fromScale(0.3, 0.4),
        Position = UDim2.fromScale(0.33, 0.45),
        X = Enum.TextXAlignment.Left,
        ZIndex = 9,
    })
    if templeLevel < 3 then
        local canUpgrade = data.canUpgrade == true
        local cost = require(game.ReplicatedStorage.UpgradePrices).Temple[templeLevel + 1]
        local upgradeButton = button(
            templeRow,
            0.84,
            0.5,
            0.26,
            0.62,
            canUpgrade and ("UPGRADE • $" .. Config.Short(cost)) or "BUY ALL SLOTS",
            canUpgrade and Color3.fromRGB(214, 52, 45) or Color3.fromRGB(70, 92, 104)
        )
        upgradeButton.Interactable = canUpgrade
        if not canUpgrade then
            text(
                templeRow,
                "Buy every current slot first",
                Color3.fromRGB(150, 90, 60),
                { Size = UDim2.fromScale(0.5, 0.22), Position = UDim2.fromScale(0.3, 0.06), ZIndex = 9, Max = 13 }
            )
        end
        upgradeButton.Activated:Connect(function()
            runAction("UpgradeTemple")
        end)
    else
        text(
            templeRow,
            "MAX",
            Color3.fromRGB(235, 175, 30),
            { Stroke = 2, Size = UDim2.fromScale(0.2, 0.5), Position = UDim2.fromScale(0.74, 0.25), ZIndex = 9 }
        )
    end

    -- INCUBATORS
    local incubatorRow = row(0.5, "INCUBATORS")
    incubatorRow.Name = "IncubatorUpgrades"
    local chambers = plot and plot:FindFirstChild("Chambers")
    local chamberCount = chambers and #chambers:GetChildren() or 0
    for i = 1, 3 do
        local chamber = chambers and chambers:FindFirstChild("Chamber" .. i)
        local chamberCard = box(
            incubatorRow,
            0.36 + (i - 1) * 0.215,
            0.62,
            0.2,
            0.62,
            { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(26, 44, 52), ZIndex = 9 }
        )
        create("UICorner", { CornerRadius = UDim.new(0.2, 0) }, chamberCard)
        create("UIStroke", { Color = Color3.fromRGB(205, 170, 120), Thickness = 2 }, chamberCard)
        if chamber then
            local chamberLevel = chamber:GetAttribute("UpgradeLevel") or 1
            text(chamberCard, "#" .. i .. "  LV " .. chamberLevel, INK, {
                Size = UDim2.fromScale(0.38, 0.5),
                Position = UDim2.fromScale(0.04, 0.25),
                X = Enum.TextXAlignment.Left,
                ZIndex = 10,
                Max = 16,
            })
            if chamberLevel < 3 then
                local upgradeButton = button(chamberCard, 0.71, 0.5, 0.52, 0.72, "UPGRADE", Color3.fromRGB(214, 52, 45))
                upgradeButton.ZIndex = 10
                upgradeButton.Activated:Connect(function()
                    runAction("UpgradeIncubator", { index = i })
                end)
            else
                text(chamberCard, "MAX", Color3.fromRGB(235, 175, 30), {
                    Stroke = 1.5,
                    Size = UDim2.fromScale(0.35, 0.5),
                    Position = UDim2.fromScale(0.6, 0.25),
                    ZIndex = 10,
                })
            end
        elseif i == chamberCount + 1 then
            local upgradeButton = button(chamberCard, 0.5, 0.5, 0.8, 0.7, "+ ADD INCUBATOR", GREEN)
            upgradeButton.Activated:Connect(function()
                runAction("AddIncubator")
            end)
        else
            text(chamberCard, "LOCKED", GREY, {
                Size = UDim2.fromScale(0.6, 0.45),
                Position = UDim2.fromScale(0.5, 0.5),
                AnchorPoint = Vector2.new(0.5, 0.5),
                ZIndex = 10,
            })
        end
    end

    -- CHARACTER SLOTS
    local slotRow = row(0.83, "CHARACTER SLOTS")
    local unlockedCount, nextPrice = 0, nil
    local slotCap = data.availableSlots or (templeLevel * 12)
    for i = 1, slotCap do
        local slot = plot and plot.Slots:FindFirstChild(string.format("Slot%02d", i))
        local isUnlocked = slot and slot:GetAttribute("Unlocked")
        if isUnlocked then
            unlockedCount += 1
        elseif not nextPrice then
            nextPrice = slot and slot:GetAttribute("UnlockPrice") or SLOT_PRICES[i]
        end
        local pip = box(slotRow, 0.05 + i * (0.516 / slotCap), 0.68, (0.408 / slotCap), 0.34, {
            BackgroundTransparency = 0,
            BackgroundColor3 = isUnlocked and GREEN or Color3.fromRGB(50, 70, 80),
            ZIndex = 9,
        })
        create("UICorner", { CornerRadius = UDim.new(0.3, 0) }, pip)
        create("UIStroke", { Color = INK, Thickness = 1.5 }, pip)
    end
    text(
        slotRow,
        "FLOOR " .. templeLevel,
        Color3.fromRGB(150, 90, 60),
        { Size = UDim2.fromScale(0.13, 0.25), Position = UDim2.fromScale(0.6, 0.12), ZIndex = 9, Max = 13 }
    )
    text(
        slotRow,
        unlockedCount .. " / " .. slotCap,
        INK,
        { Size = UDim2.fromScale(0.13, 0.4), Position = UDim2.fromScale(0.6, 0.45), ZIndex = 9 }
    )
    if nextPrice then
        local upgradeButton = button(slotRow, 0.86, 0.5, 0.24, 0.62, "UNLOCK • $" .. Config.Short(nextPrice), GREEN)
        upgradeButton.Activated:Connect(function()
            runAction("UnlockSlot")
        end)
    else
        text(
            slotRow,
            "ALL UNLOCKED",
            Color3.fromRGB(235, 175, 30),
            { Stroke = 2, Size = UDim2.fromScale(0.24, 0.45), Position = UDim2.fromScale(0.74, 0.28), ZIndex = 9 }
        )
    end
end

-- Hides the clean skin, adds the FigmaWindow art once and moves the Close hit-box onto the art's X.
local function applyFigmaWindow(panel)
    -- figma window art replaces the old skin
    for _, skinName in { "CleanSkin", "CleanBase" } do
        local oldSkin = panel:FindFirstChild(skinName)
        if oldSkin then
            oldSkin.Visible = false
        end
    end
    local _figmaArt = panel:FindFirstChild("FigmaWindow")
        or create("ImageLabel", {
            Name = "FigmaWindow",
            BackgroundTransparency = 1,
            Image = "rbxassetid://85782174721137",
            Size = UDim2.fromScale(1, 1),
            ScaleType = Enum.ScaleType.Stretch,
            ZIndex = 2,
        }, panel)
    local closeButton = panel:FindFirstChild("Close")
    if closeButton then
        closeButton.AnchorPoint = Vector2.new(0.5, 0.5)
        closeButton.Position = UDim2.fromScale(0.951, 0.064)
        closeButton.Size = UDim2.fromScale(0.058, 0.088)
        closeButton.BackgroundTransparency = 1
        for _, descendant in closeButton:GetDescendants() do
            if descendant:IsA("GuiObject") then
                descendant.Visible = false
            elseif descendant:IsA("UIStroke") then
                descendant.Enabled = false
            end
        end
        closeButton.ZIndex = 30
    end
end
-- Current Plot layout: drawn over the "FigmaWindow" art (the clean skin is hidden).
RENDER.Plot = function(panel)
    local data, errorMessage = fetchState("plot")
    local layer = liveLayerOf(panel)
    clear(layer)
    applyFigmaWindow(panel)
    if not data then
        text(box(layer, 0.5, 0.5, 0.6, 0.08), errorMessage)
        return
    end
    local _BANGERS_FONT = Font.new("rbxasset://fonts/families/Bangers.json")
    local PANEL_FONT = FONT
    local PLOT_BLACK = Color3.new(0, 0, 0)
    local function plotCard(cx, cy, w, h, color, zIndex)
        local cardFrame =
            box(layer, cx, cy, w, h, { BackgroundTransparency = 0, BackgroundColor3 = color, ZIndex = zIndex or 8 })
        cardFrame:SetAttribute("NoSkin", true)
        create("UICorner", { CornerRadius = UDim.new(0.08, 0) }, cardFrame)
        create(
            "UIStroke",
            { Color = PLOT_BLACK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            cardFrame
        )
        create("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = "rbxassetid://132561191216691",
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(26, 26),
            ImageTransparency = 0.55,
            ZIndex = cardFrame.ZIndex,
        }, cardFrame)
        return cardFrame
    end
    local function plotText(parent, str, x, y, w, h, maxTextSize, color, alignment)
        local label = create("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromScale(x, y),
            Size = UDim2.fromScale(w, h),
            Text = str,
            FontFace = PANEL_FONT,
            TextScaled = true,
            TextColor3 = color or Color3.new(1, 1, 1),
            TextXAlignment = alignment or Enum.TextXAlignment.Left,
            ZIndex = parent.ZIndex + 2,
        }, parent)
        create("UITextSizeConstraint", { MaxTextSize = maxTextSize or 30 }, label)
        create("UIStroke", { Color = PLOT_BLACK, Thickness = 2 }, label)
        return label
    end
    -- Slot i of the 4x3 grid: placed character + income, EMPTY, or locked with its unlock price.
    local function addSlotCell(grid, i, slotsFolder, placed, unlockedCount)
        local column, row = (i - 1) % 4, math.floor((i - 1) / 4)
        -- Rows span y 0.14..0.97 of the grid card (below the title bar), so no cell sticks out of the card;
        -- ClipsDescendants keeps the character portrait inside its cell.
        local cell = box(grid, 0.14 + column * 0.24, 0.27 + row * 0.285, 0.21, 0.26, {
            BackgroundTransparency = 0,
            BackgroundColor3 = Color3.fromRGB(46, 36, 92),
            ZIndex = 8,
            ClipsDescendants = true,
        })
        create("UICorner", { CornerRadius = UDim.new(0.08, 0) }, cell)
        create(
            "UIStroke",
            { Color = Color3.new(1, 1, 1), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            cell
        )
        local item = placed[i]
        local slot = slotsFolder and slotsFolder:FindFirstChild(string.format("Slot%02d", i))
        if item then
            if item.image and item.image ~= "" then
                create("ImageLabel", {
                    BackgroundTransparency = 1,
                    Image = item.image,
                    ScaleType = Enum.ScaleType.Fit,
                    Position = UDim2.fromScale(0.1, 0.04),
                    Size = UDim2.fromScale(0.8, 0.7),
                    ZIndex = 9,
                }, cell)
            end
            plotText(
                cell,
                "$" .. Config.Short(item.income or 0) .. "/s",
                0.05,
                0.74,
                0.9,
                0.22,
                14,
                Color3.fromRGB(110, 255, 110),
                Enum.TextXAlignment.Center
            )
        elseif i <= unlockedCount then
            cell.BackgroundColor3 = Color3.fromRGB(60, 50, 110)
            plotText(cell, "EMPTY", 0.05, 0.4, 0.9, 0.22, 14, Color3.fromRGB(190, 180, 230), Enum.TextXAlignment.Center)
        else
            cell.BackgroundColor3 = Color3.fromRGB(110, 110, 118)
            plotText(cell, "🔒", 0.2, 0.12, 0.6, 0.45, 40, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
            local unlockPrice = slot and slot:GetAttribute("UnlockPrice")
            plotText(
                cell,
                unlockPrice and ("$" .. Config.Short(unlockPrice)) or "LOCKED",
                0.05,
                0.72,
                0.9,
                0.22,
                14,
                Color3.fromRGB(255, 210, 60),
                Enum.TextXAlignment.Center
            )
        end
    end
    -- Upgrade row i: title, subtitle, progress bar and a price button that fires rowDef[6].
    local function addUpgradeRow(i, rowDef, slotCap)
        local rowFrame = box(
            layer,
            0.74,
            0.21 + i * 0.16 + 0.02,
            0.45,
            0.145,
            { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(40, 30, 80), ZIndex = 7 }
        )
        -- FirstHatchTutorial (tour steps 11 / 12) highlights these rows by name.
        if rowDef[6] == "UpgradeTemple" then
            rowFrame.Name = "TempleUpgrades"
        elseif rowDef[6] == "AddIncubator" then
            rowFrame.Name = "IncubatorUpgrades"
        end
        create("UICorner", { CornerRadius = UDim.new(0.08, 0) }, rowFrame)
        create(
            "UIStroke",
            { Color = PLOT_BLACK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            rowFrame
        )
        create("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = "rbxassetid://132561191216691",
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(26, 26),
            ImageTransparency = 0.7,
            ZIndex = 7,
        }, rowFrame)
        plotText(rowFrame, rowDef[1], 0.04, 0.1, 0.6, 0.32, 24)
        plotText(rowFrame, rowDef[2], 0.04, 0.44, 0.6, 0.2, 13, Color3.fromRGB(200, 195, 230))
        local progressBar = create("Frame", {
            BackgroundColor3 = Color3.fromRGB(20, 15, 40),
            BorderSizePixel = 0,
            Position = UDim2.fromScale(0.04, 0.72),
            Size = UDim2.fromScale(0.6, 0.14),
            ZIndex = 9,
        }, rowFrame)
        create("UICorner", { CornerRadius = UDim.new(1, 0) }, progressBar)
        create("UIStroke", { Color = PLOT_BLACK, Thickness = 1.5 }, progressBar)
        local fill = create("Frame", {
            BackgroundColor3 = rowDef[5],
            BorderSizePixel = 0,
            Size = UDim2.fromScale(math.clamp(rowDef[4], 0.05, 1), 1),
            ZIndex = 10,
        }, progressBar)
        create("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
        local canBuy = rowDef[7] and rowDef[3] ~= nil
        local buyButton = create("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.fromScale(0.96, 0.5),
            Size = UDim2.fromScale(0.28, 0.66),
            BackgroundColor3 = canBuy and Color3.fromRGB(70, 200, 70) or Color3.fromRGB(110, 110, 118),
            Text = "",
            AutoButtonColor = false,
            ZIndex = 10,
        }, rowFrame)
        create("UICorner", { CornerRadius = UDim.new(0.12, 0) }, buyButton)
        create(
            "UIStroke",
            { Color = PLOT_BLACK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            buyButton
        )
        create("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = "rbxassetid://132561191216691",
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(22, 22),
            ImageTransparency = 0.45,
            ZIndex = 10,
        }, buyButton)
        plotText(
            buyButton,
            rowDef[3] and ("$" .. Config.Short(rowDef[3])) or "MAX",
            0.06,
            0.15,
            0.88,
            0.7,
            26,
            Color3.new(1, 1, 1),
            Enum.TextXAlignment.Center
        )
        buyButton.MouseEnter:Connect(function()
            UISound.Play("Hover")
            TweenService:Create(buyButton, TweenInfo.new(0.1), { Size = UDim2.fromScale(0.3, 0.7) }):Play()
        end)
        buyButton.MouseLeave:Connect(function()
            TweenService:Create(buyButton, TweenInfo.new(0.1), { Size = UDim2.fromScale(0.28, 0.66) }):Play()
        end)
        buyButton.Activated:Connect(function()
            if not canBuy then
                showToast(
                    rowDef[3]
                            and (rowDef[1] == "Temple Upgrade" and "Unlock all " .. slotCap .. " slots first" or "Not available yet")
                        or "Already maxed"
                )
                return
            end
            UISound.Play("Click")
            runAction(rowDef[6], { index = 1 })
        end)
    end
    local plot = findMyPlot()
    local UpgradePrices = require(game.ReplicatedStorage.UpgradePrices)
    local placed, income = {}, 0
    for _, item in data.items or {} do
        if item.state == "placed" then
            table.insert(placed, item)
            income += item.income or 0
        end
    end
    local level, slotCap, unlockedCount = data.level or 1, data.availableSlots or 12, data.unlocked or 0
    local chambers = plot and plot:FindFirstChild("Chambers")
    local incubatorCount = chambers and #chambers:GetChildren() or 0
    -- stat cards
    local stats = {
        { "INCOME", "$" .. Config.Short(income) .. "/s", Color3.fromRGB(70, 200, 70) },
        { "SLOTS", #placed .. " / " .. unlockedCount, Color3.fromRGB(40, 110, 230) },
        { "TEMPLE", "Lv. " .. level, Color3.fromRGB(240, 170, 30) },
        { "INCUBATORS", incubatorCount .. " / 3", Color3.fromRGB(240, 70, 150) },
    }
    for i, stat in stats do
        local statCard = plotCard(0.035 + (i - 1) * 0.245 + 0.1075, 0.21, 0.215, 0.12, stat[3])
        plotText(statCard, stat[1], 0.06, 0.08, 0.8, 0.3, 16)
        plotText(statCard, stat[2], 0.06, 0.38, 0.9, 0.52, 36)
    end
    -- slots grid
    local grid = box(
        layer,
        0.265,
        0.615,
        0.45,
        0.64,
        { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(120, 120, 128), ZIndex = 7 }
    )
    create("UICorner", { CornerRadius = UDim.new(0.03, 0) }, grid)
    create("UIStroke", { Color = Color3.fromRGB(60, 60, 70), Thickness = 2 }, grid)
    plotText(grid, "SLOTS", 0.04, 0.02, 0.4, 0.08, 20)
    -- EQUIP BEST: the server (GameMenu action EquipBest -> InventoryService PlaceBest) places the
    -- highest-income characters on the unlocked slots and replies with the toast message.
    local equipBestButton = create("TextButton", {
        Name = "EquipBestButton",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(0.96, 0.025),
        Size = UDim2.fromScale(0.36, 0.09),
        BackgroundColor3 = Color3.fromRGB(40, 110, 230),
        Text = "",
        AutoButtonColor = false,
        ZIndex = 9,
    }, grid)
    create("UICorner", { CornerRadius = UDim.new(0.2, 0) }, equipBestButton)
    create(
        "UIStroke",
        { Color = PLOT_BLACK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
        equipBestButton
    )
    create("ImageLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = "rbxassetid://132561191216691",
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(22, 22),
        ImageTransparency = 0.45,
        ZIndex = 9,
    }, equipBestButton)
    plotText(equipBestButton, "EQUIP BEST", 0.06, 0.12, 0.88, 0.76, 20, Color3.new(1, 1, 1), Enum.TextXAlignment.Center)
    equipBestButton.MouseEnter:Connect(function()
        UISound.Play("Hover")
        TweenService:Create(equipBestButton, TweenInfo.new(0.1), { Size = UDim2.fromScale(0.38, 0.095) }):Play()
    end)
    equipBestButton.MouseLeave:Connect(function()
        TweenService:Create(equipBestButton, TweenInfo.new(0.1), { Size = UDim2.fromScale(0.36, 0.09) }):Play()
    end)
    equipBestButton.Activated:Connect(function()
        UISound.Play("Click")
        runAction("EquipBest")
    end)
    local slotsFolder = plot and plot:FindFirstChild("Slots")
    for i = 1, 12 do
        addSlotCell(grid, i, slotsFolder, placed, unlockedCount)
    end
    -- upgrade rows
    local nextSlot, nextPrice
    for i = 1, slotCap do
        local slot = slotsFolder and slotsFolder:FindFirstChild(string.format("Slot%02d", i))
        if slot and not slot:GetAttribute("Unlocked") then
            nextSlot, nextPrice = i, slot:GetAttribute("UnlockPrice")
            break
        end
    end
    local chamber1Level = chambers
            and chambers:FindFirstChild("Chamber1")
            and (chambers.Chamber1:GetAttribute("UpgradeLevel") or 1)
        or 1
    local upgradeRows = {
        {
            "Temple Upgrade",
            level >= 3 and "Max level" or ("Lv. " .. level .. " → " .. (level + 1) .. " · unlock all slots first"),
            level >= 3 and nil or UpgradePrices.Temple[level + 1],
            level / 3,
            Color3.fromRGB(240, 170, 30),
            "UpgradeTemple",
            level < 3 and data.canUpgrade,
        },
        {
            "Unlock Slot",
            nextSlot and ("Slot " .. nextSlot .. " · +1 character") or "Floor full",
            nextPrice,
            unlockedCount / math.max(slotCap, 1),
            Color3.fromRGB(40, 110, 230),
            "UnlockSlot",
            nextSlot ~= nil,
        },
        {
            "Incubator Speed",
            chamber1Level >= 3 and "Max level"
                or ("Lv. " .. chamber1Level .. " → " .. (chamber1Level + 1) .. " · faster hatching"),
            chamber1Level < 3 and UpgradePrices.IncubatorLevel[chamber1Level + 1] or nil,
            chamber1Level / 3,
            Color3.fromRGB(70, 200, 70),
            "UpgradeIncubator",
            chamber1Level < 3,
        },
        {
            "More Incubators",
            incubatorCount >= 3 and "All 3 built"
                or (incubatorCount .. " → " .. (incubatorCount + 1) .. " · hatch more at once"),
            incubatorCount < 3 and UpgradePrices.AddIncubator[incubatorCount + 1] or nil,
            incubatorCount / 3,
            Color3.fromRGB(150, 90, 230),
            "AddIncubator",
            incubatorCount < 3,
        },
    }
    for i, rowDef in upgradeRows do
        addUpgradeRow(i, rowDef, slotCap)
    end
    panel:SetAttribute("Page", "figma")
end

-- ===== 10. Open / close, refresh loop and wiring =====
local openPanel -- the panel currently shown (nil = all closed)
for _, child in gui:GetChildren() do
    if child:IsA("ImageLabel") then
        child.Visible = false
    end
end
dimOverlay.Visible = false

-- Coalescing refresh: calls made while a render runs only set refreshPending, so exactly one more render
-- of the (then) open panel follows.
local refreshRunning = false
local refreshPending = false
refresh = function()
    refreshPending = true
    if refreshRunning then
        return
    end
    refreshRunning = true
    task.spawn(function()
        repeat
            refreshPending = false
            local current = openPanel
            if current and RENDER[current.Name] then
                local ok, err = pcall(RENDER[current.Name], current)
                if not ok then
                    warn("[GameMenus] refresh failed:", err)
                end
            end
            if refreshPending then
                task.wait(0.06)
            end
        until not refreshPending
        refreshRunning = false
    end)
end
-- Shrink-out tween, then hide; the dim overlay is hidden only if no other panel opened meanwhile.
local function closeMenu()
    if not openPanel then
        return
    end
    local panel = openPanel
    openPanel = nil
    UISound.Play("Close")
    closingPanel = panel
    TweenService:Create(
        panel.UIScale,
        TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { Scale = 0.85 * (panel:GetAttribute("Fit") or 1) }
    ):Play()
    task.delay(0.15, function()
        if closingPanel == panel then
            closingPanel = nil
        end
        if openPanel ~= panel then
            panel.Visible = false
        end
        if not openPanel then
            dimOverlay.Visible = false
        end
    end)
end
-- Toggle: showing the open panel closes it. Skins the panel on first open, then refreshes it.
local function showPanel(panel)
    if openPanel == panel then
        closeMenu()
        return
    end
    if openPanel then
        openPanel.Visible = false
    end
    skinPanel(panel)
    openPanel = panel
    panel.Visible = true
    dimOverlay.Visible = true
    if closingPanel == panel then
        closingPanel = nil
    end
    local fit = panel:GetAttribute("Fit") or 1
    panel.UIScale.Scale = 0.85 * fit
    TweenService:Create(panel.UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = fit }):Play()
    UISound.Play("Open")
    refresh()
end
local function isClickOnPanel(dimInstance, input)
    -- true if the click landed on any visible part of a panel (anything in this ScreenGui that isn't the dim)
    if not (input and input.Position) then
        return false
    end
    local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local rootGui = dimInstance:FindFirstAncestorWhichIsA("LayerCollector")
    for _, guiObject in playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
        if
            guiObject ~= dimInstance
            and rootGui
            and guiObject:IsDescendantOf(rootGui)
            and not guiObject:IsDescendantOf(dimInstance)
        then
            return true
        end
    end
    return false
end
dimOverlay.Activated:Connect(function(input)
    if isClickOnPanel(dimOverlay, input) then
        return
    end
    closeMenu()
end)
Changed.OnClientEvent:Connect(refresh)
do
    local localRefreshEvent = gui:FindFirstChild("LocalRefresh") or Instance.new("BindableEvent")
    localRefreshEvent.Name = "LocalRefresh"
    localRefreshEvent.Parent = gui
    localRefreshEvent.Event:Connect(function()
        if refresh then
            refresh()
        end
    end)
end
do
    local openMenuEvent = gui:FindFirstChild("OpenMenu") or Instance.new("BindableEvent")
    openMenuEvent.Name = "OpenMenu"
    openMenuEvent.Parent = gui
    openMenuEvent.Event:Connect(function(panelName)
        local panel = gui:FindFirstChild(panelName)
        if panel and openPanel ~= panel then
            showPanel(panel)
        end
    end)
end

for _, sideButton in sideButtons:GetChildren() do
    if sideButton:IsA("GuiButton") then
        local panel = gui:WaitForChild(sideButton:GetAttribute("Panel"))
        panel:WaitForChild("Close").Activated:Connect(closeMenu)
        local hoverScale = sideButton:FindFirstChildOfClass("UIScale")
        sideButton.MouseEnter:Connect(function()
            UISound.Play("Hover")
            if hoverScale then
                TweenService:Create(hoverScale, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
            end
        end)
        sideButton.MouseLeave:Connect(function()
            if hoverScale then
                TweenService:Create(hoverScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
            end
        end)
        local face = sideButton:FindFirstChild("Face", true)
        if face then
            sideButton.MouseButton1Down:Connect(function()
                TweenService:Create(face, TweenInfo.new(0.06), { Position = UDim2.new(0.5, 0, 0, 9) }):Play()
            end)
            local function raiseFace()
                TweenService
                    :Create(face, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 4) })
                    :Play()
            end
            sideButton.MouseButton1Up:Connect(raiseFace)
            sideButton.MouseLeave:Connect(raiseFace)
        end
        sideButton.Activated:Connect(function()
            UISound.Play("Click")
            showPanel(panel)
        end)
    end
end

-- TileIcons: use the object-only icons once they're set in ReplicatedStorage.GameMenuImages
local menuImages = ReplicatedStorage:FindFirstChild("GameMenuImages")
if menuImages then
    for _, sideButton in sideButtons:GetChildren() do
        if sideButton:IsA("GuiButton") then
            local tileIcon = sideButton:FindFirstChild("Icon", true)
            local tileIconShadow = sideButton:FindFirstChild("IconShadow", true)
            local function applyTileImage()
                local tileImage = menuImages:GetAttribute("Tile" .. sideButton.Name)
                if tileIcon and tileImage and tileImage ~= "" then
                    tileIcon.Image = tileImage
                    if tileIconShadow then
                        tileIconShadow.Image = tileImage
                    end
                end
            end
            menuImages:GetAttributeChangedSignal("Tile" .. sideButton.Name):Connect(applyTileImage)
            applyTileImage()
        end
    end
end

-- ===== 11. Warm the shared Robux price cache (_G.__shopPrices) without blocking start-up =====
task.defer(function()
    local shopSystem = ReplicatedStorage:FindFirstChild("ShopSystem")
    local ok, ShopConfig = pcall(function()
        return require(shopSystem.ShopConfig)
    end)
    if not ok then
        return
    end
    _G.__shopPrices = _G.__shopPrices or {}
    local MarketplaceService = game:GetService("MarketplaceService")
    local function warmPrice(id, isGamePass)
        if not id or id == 0 then
            return
        end
        local cacheKey = (isGamePass and "p" or "d") .. id
        if _G.__shopPrices[cacheKey] ~= nil then
            return
        end
        _G.__shopPrices[cacheKey] = false
        task.spawn(function()
            local fetched, productInfo = pcall(
                MarketplaceService.GetProductInfo,
                MarketplaceService,
                id,
                isGamePass and Enum.InfoType.GamePass or Enum.InfoType.Product
            )
            _G.__shopPrices[cacheKey] = fetched and productInfo and productInfo.PriceInRobux or false
        end)
    end
    for _, id in ShopConfig.Products do
        warmPrice(id)
    end
    for _, id in ShopConfig.GamePasses do
        warmPrice(id, true)
    end
    for _, moneyLevel in ShopConfig.MoneyLevels or {} do
        warmPrice(moneyLevel.productId)
    end
end)
