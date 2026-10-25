--[[ StarterGui.GameMenus.MenuLogic (LocalScript)
Opens/closes the four ForgeGUI panels and fills them with live data from ServerScriptService.GameMenu.
All four panels are drawn by their Component modules on the Figma canvas (ReplicatedStorage.StudKit.StudUI),
which scales itself to the panel; RENDER fns only build the view models.

Panels (ImageLabel children of this ScreenGui, opened by the left menu (LeftMenuComponent / LeftMenuConfig):
  Index    RENDER.Index    Figma "02 Index" (IndexComponent / IndexConfig): season tabs, search, rarity
                           filters, scrolling card grid, detail card
  Quests   RENDER.Quests   Figma "04 Quests" (QuestMenuComponent / QuestMenuConfig): Daily / Weekly /
                           Milestone quest rows with Claim, CLAIM ALL
  VipShop  RENDER.VipShop  Robux shop (Figma "01 Shop", drawn by ShopMenuComponent / ShopMenuConfig): tabs
                           FEATURED / BOOSTS / PASSES / CASH / DAILY
  Plot     RENDER.Plot     "My Plot" (Figma "03 Plot", drawn by PlotComponent / PlotConfig): stat tiles,
                           scrolling slot grid or incubator rows, upgrade rows, slots footer
  Every RENDER fn clears the panel's "Live" layer and rebuilds it from scratch on each refresh.

Remotes (contract documented in GameMenuServer.server.luau / GameAdapter.luau):
  ReplicatedStorage.GameMenu.Remotes.GetState  (RF)  fetchState(section) -> data | nil, message
  ReplicatedStorage.GameMenu.Remotes.Action    (RF)  runAction(name, args) -> ok   (toast shows the message)
  ReplicatedStorage.GameMenu.Remotes.Changed   (RE)  server says "your data changed" -> refresh()
  ReplicatedStorage.ShopSystem.ShopRemote      (RF)  VipShop only: "State", "Buy", "BuyMoneyLevel", "BuyHatchLevel", "ClaimDaily"
  ReplicatedStorage.GoHome                     (RE)  left menu HOME button: FireServer() (GameHUD shows the reply)
Left menu SETTINGS fires PlayerGui.MusicSettingsUI.Toggle (Bindable, MusicSettings).
Bindables created here (children of this ScreenGui, used by other LocalScripts):
  LocalRefresh  (fire to re-render the open panel, e.g. Plot/PromptCards)
  OpenMenu      (fire with a panel name to open it, e.g. FigmaSkin)
Cross-script globals: _G.__shopPrices  [("p"|"d") .. id] = live Robux price | false (lookup pending/failed);
  shared with any script that reads the same cache. Warmed once at start (bottom of file) and by the shop.
Attributes: panel "Fit" (UIScale for the current screen, written by layoutMenus), "Page" (Plot),
  workspace "HalloweenMode" / "HalloweenEndsAt", plot "OwnerUserId", slot/chamber attributes (read-only).

Init order (all at top level, in this order — WaitForChild calls yield):
  Dim + SideButtons (hidden) -> left menu -> DisplayOrder hook -> responsive layout -> remotes / Config / UISound
  -> helpers and RENDER fns -> hide all panels -> refresh/close/show -> Dim click, Changed, LocalRefresh, OpenMenu
  -> panel Close buttons + left menu buttons (WaitForChild per panel) -> deferred shop price warm-up.

Contents: 1 layout · 2 shared UI primitives · 3 clean skin · 4 toast + remotes · 5 game icons ·
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
local closingPanel -- panel playing its close tween
-- The left menu (LeftMenuComponent, art buttons) replaces the Studio-built SideButtons, which stay hidden.
local LeftMenuConfig = require(gui:WaitForChild("LeftMenuConfig"))
local StudKit = ReplicatedStorage:WaitForChild("StudKit")
local StudTheme = require(StudKit:WaitForChild("StudTheme"))
local StudUI = require(StudKit:WaitForChild("StudUI"))
local StudToast = require(StudKit:WaitForChild("StudToast"))
local PlotComponent = require(gui:WaitForChild("PlotComponent"))
local IndexConfig = require(gui:WaitForChild("IndexConfig"))
local IndexComponent = require(gui:WaitForChild("IndexComponent"))
local QuestMenuConfig = require(gui:WaitForChild("QuestMenuConfig"))
local QuestMenuComponent = require(gui:WaitForChild("QuestMenuComponent"))
local ShopMenuConfig = require(gui:WaitForChild("ShopMenuConfig"))
local ShopMenuComponent = require(gui:WaitForChild("ShopMenuComponent"))
local leftMenu = require(gui:WaitForChild("LeftMenuComponent")).new(gui)
sideButtons.Visible = false
leftMenu.Root.ZIndex = sideButtons.ZIndex
for _, descendant in leftMenu.Root:GetDescendants() do
    if descendant:IsA("GuiObject") then
        descendant.ZIndex = sideButtons.ZIndex
    end
end
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
-- Sizes one panel for the current screen and stores its UIScale in the "Fit" attribute (always 1 now:
-- Plot and Shop scale their Figma canvas to the panel width themselves; the open/close tweens use "Fit").
local function fitPanelToScreen(name, screenSize)
    local panel = gui:FindFirstChild(name)
    if panel then
        local ratio = panel.UIAspectRatioConstraint.AspectRatio
        local width = math.min(1000, screenSize.X * 0.86, (screenSize.Y - 32) * ratio)
        panel.Size = UDim2.fromOffset(math.max(1, width), math.max(1, width / ratio))
        panel:SetAttribute("Fit", 1)
        if panel.Visible and panel ~= closingPanel then
            panel.UIScale.Scale = 1
        end
    end
end
local function layoutMenus()
    local screenSize = gui.AbsoluteSize
    if screenSize.X <= 0 or screenSize.Y <= 0 then
        return
    end
    extendDimPastInsets(screenSize)
    local compact = math.min(screenSize.X, screenSize.Y) < LeftMenuConfig.CompactBreakpoint
    -- left menu: desktop = left edge, vertically centred; phones = top-left with smaller buttons
    if compact then
        local phone = LeftMenuConfig.Compact
        leftMenu:SetButtonPx(
            math.clamp(screenSize.Y * phone.ButtonPxPerScreenHeight, phone.MinButtonPx, phone.MaxButtonPx)
        )
        leftMenu.Root.AnchorPoint = Vector2.new(0, 0)
        leftMenu.Root.Position =
            UDim2.fromOffset(phone.Margin, screenSize.X < screenSize.Y and phone.TopPortrait or phone.Top)
    else
        leftMenu:SetButtonPx(LeftMenuConfig.Desktop.ButtonPx)
        leftMenu.Root.AnchorPoint = Vector2.new(0, 0.5)
        leftMenu.Root.Position = UDim2.new(0, LeftMenuConfig.Desktop.Margin, 0.5, 0)
    end
    for _, name in { "Plot", "Index", "Quests", "VipShop" } do
        fitPanelToScreen(name, screenSize)
    end
end
-- Every menu is drawn on the Figma canvas (StudUI), so the panels take its aspect ratio
for _, name in { "Plot", "Index", "Quests", "VipShop" } do
    local panel = gui:FindFirstChild(name)
    if panel then
        panel.UIAspectRatioConstraint.AspectRatio = StudTheme.CanvasSize.X / StudTheme.CanvasSize.Y
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

-- Figma "10 Notifications": stacked Toast cards (StudToast). kind: "info" (default) | "success" | "error".
local toasts = StudToast.new(gui)
local function showToast(message, kind)
    toasts:Show(message, kind)
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
        showToast("Server error", "error")
        return false
    end
    showToast(message, success and "success" or "error")
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

-- ===== 5. Game icons (quest rows) =====
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

-- ===== 6. Index panel =====
-- IndexComponent draws Figma "02 Index"; RENDER.Index only builds its view model.
-- View state survives refreshes: season tab, rarity filter, search text, selected character, grid scroll.
local indexSeason = workspace:GetAttribute("HalloweenMode") and "Halloween" or "Original"
local indexFilter, indexSelectedId, indexSearch, indexScrollY = "All", nil, "", 0
local indexView -- IndexComponent of the last render
RENDER.Index = function(panel)
    local data, errorMessage = fetchState("index")
    local layer = liveLayerOf(panel)
    if indexView then
        indexView:Destroy()
        indexView = nil
    end
    clear(layer)
    if not data then
        text(box(layer, 0.5, 0.5, 0.6, 0.08), errorMessage)
        return
    end
    StudUI.useShell(panel)
    local isHalloween = indexSeason == "Halloween"
    local isEventLive = workspace:GetAttribute("HalloweenMode") == true
    -- the collection is the catalog's first 15 characters (both seasons show the same set)
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
            indexSelectedId = indexSelectedId or character.id
        end
    end
    local function selectSeason(season)
        return function()
            indexSeason = season
            RENDER.Index(panel)
        end
    end
    local filters = {}
    for _, rarity in { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" } do
        table.insert(filters, { key = rarity, label = string.upper(rarity), selected = indexFilter == rarity })
    end
    local cards, selected = {}, nil
    for _, character in characters do
        local isDiscovered = data.discovered[character.id] == true
        local rarityColor = RARITY_COLORS[character.rarity] or GREY
        if indexFilter == "All" or character.rarity == indexFilter then
            table.insert(cards, {
                id = character.id,
                name = character.name,
                rarity = character.rarity,
                rarityColor = rarityColor,
                image = character.image,
                discovered = isDiscovered,
                selected = character.id == indexSelectedId,
            })
        end
        if character.id == indexSelectedId and isDiscovered then
            local ownedCount = data.owned and data.owned[character.id] or 0
            selected = {
                name = character.name,
                rarity = character.rarity,
                rarityColor = rarityColor,
                image = character.image,
                status = "DISCOVERED · OWNED " .. ownedCount,
                statusColor = StudTheme.Colors.Green,
                obtain = character.obtain,
            }
        end
    end
    local endsAt = workspace:GetAttribute("HalloweenEndsAt")
    indexView = IndexComponent.new(panel, layer, {
        title = isHalloween and IndexConfig.Titles.Halloween or IndexConfig.Titles.Default,
        seasons = {
            { key = "Original", label = "ORIGINAL", selected = not isHalloween, onActivate = selectSeason("Original") },
            {
                key = "Halloween",
                label = "HALLOWEEN",
                selected = isHalloween,
                live = isEventLive,
                onActivate = selectSeason("Halloween"),
            },
            {
                key = "Winter",
                label = "WINTER 🔒",
                selected = false,
                onActivate = function()
                    showToast("Winter collection is coming soon!")
                end,
            },
        },
        collectionText = (isHalloween and "HALLOWEEN COLLECTION" or "COLLECTION")
            .. " · "
            .. discoveredCount
            .. " / "
            .. #characters,
        progress = discoveredCount / math.max(#characters, 1),
        timerEndsAt = isHalloween and typeof(endsAt) == "number" and endsAt or nil,
        filters = filters,
        onFilter = function(rarity)
            indexFilter = rarity
            indexScrollY = 0
            RENDER.Index(panel)
        end,
        search = indexSearch,
        onSearch = function(searchText)
            indexSearch = searchText
        end,
        characters = cards,
        onSelect = function(id)
            indexSelectedId = id
            RENDER.Index(panel)
        end,
        selected = selected,
        scrollY = indexScrollY,
        onScroll = function(y)
            indexScrollY = y
        end,
    })
end

-- ===== 7. Quests panel =====
-- QuestMenuComponent draws Figma "04 Quests"; RENDER.Quests only builds its view model.
-- Selected period tab: "Daily" | "Weekly" | "Monthly" (shown as MILESTONES).
local questTab = "Daily"
local questView -- QuestMenuComponent of the last render
-- Icon for a quest, picked from words in its title
local function questIcon(title)
    local titleLower = string.lower(title or "")
    local function has(...)
        for _, word in { ... } do
            if titleLower:find(word) then
                return true
            end
        end
        return false
    end
    return has("hatch", "egg") and GAME_ICONS.Index
        or has("discover") and GAME_ICONS.Book
        or has("place", "upgrade", "temple", "slot") and GAME_ICONS.Plot
        or has("cash", "income", "earn") and GAME_ICONS.Coins
        or has("steal") and GAME_ICONS.Chest
        or GAME_ICONS.Quest
end
RENDER.Quests = function(panel)
    local data, errorMessage = fetchState("quests")
    local layer = liveLayerOf(panel)
    if questView then
        questView:Destroy()
        questView = nil
    end
    clear(layer)
    if not data then
        text(box(layer, 0.5, 0.5, 0.6, 0.08), errorMessage)
        return
    end
    StudUI.useShell(panel)
    local tabs, claimableCount = {}, 0
    for _, period in QuestMenuConfig.Tabs.Keys do
        local readyCount = 0
        for _, quest in data.list or {} do
            if quest.period == period and quest.progress >= quest.target and not quest.claimed then
                readyCount += 1
            end
        end
        claimableCount += readyCount
        table.insert(tabs, {
            key = period,
            label = QuestMenuConfig.Tabs.Labels[period],
            selected = questTab == period,
            ready = readyCount,
            onActivate = function()
                questTab = period
                RENDER.Quests(panel)
            end,
        })
    end
    local visibleQuests = {}
    for _, quest in data.list or {} do
        if quest.period == questTab then
            table.insert(visibleQuests, quest)
        end
    end
    -- claimable first, then in progress, claimed last
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
    local quests = {}
    for _, quest in visibleQuests do
        local isClaimable = quest.progress >= quest.target and not quest.claimed
        local reward = quest.reward
        table.insert(quests, {
            title = quest.title or "",
            text = quest.description or "",
            icon = questIcon(quest.title),
            progress = quest.progress / math.max(quest.target, 1),
            count = math.min(quest.progress, quest.target) .. " / " .. quest.target,
            reward = reward and (reward.cash and ("$" .. Config.Short(reward.cash)) or reward.label) or nil,
            rewardIcon = reward and reward.cash and GAME_ICONS.Coins or nil,
            state = quest.claimed and "claimed" or isClaimable and "claimable" or "active",
            onActivate = function()
                if isClaimable then
                    runAction("Claim", { id = quest.id })
                elseif not quest.claimed then
                    showToast(quest.description or quest.title)
                end
            end,
        })
    end
    local endsAt = data.ends and data.ends[questTab]
    questView = QuestMenuComponent.new(panel, layer, {
        tabs = tabs,
        quests = quests,
        emptyText = "No quests here right now",
        -- server end time -> os.clock deadline
        resetEndsAt = endsAt and os.clock() + (endsAt - (data.serverTime or os.time())) or nil,
        -- ClaimAll (server) claims every finished quest of every period
        claimAll = {
            text = claimableCount > 0 and ("CLAIM ALL (" .. claimableCount .. ")") or "CLAIM ALL",
            enabled = claimableCount > 0,
            onActivate = function()
                runAction("ClaimAll")
            end,
        },
    })
end

-- ===== 8. VipShop panel =====
-- ShopMenuComponent draws Figma "01 Shop"; RENDER.VipShop only builds its view model.
-- Data comes from ShopSystem.ShopRemote ("State"), not from the GameMenu remotes.
local shopTab = "FEATURED" -- ShopMenuConfig.Tabs.Keys; the left menu's Daily button opens "DAILY"
local shopView -- ShopMenuComponent of the last render

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

-- Coins and sparkles bursting from the panel centre after a purchase (on the panel, so a re-render keeps it)
local function playBuyBurst(panel, coinImage)
    local host = create(
        "Frame",
        { Name = "BuyBurst", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 60 },
        panel
    )
    local ring = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = FX_IMAGES.glow,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(40, 40),
        ImageColor3 = StudTheme.Colors.Gold,
        ZIndex = 60,
    }, host)
    TweenService:Create(
        ring,
        TweenInfo.new(0.5, Enum.EasingStyle.Quad),
        { Size = UDim2.fromOffset(520, 520), ImageTransparency = 1 }
    ):Play()
    for i = 1, 24 do
        local isCoin = coinImage and i % 3 ~= 0
        local piece = create("ImageLabel", {
            BackgroundTransparency = 1,
            Image = isCoin and coinImage or FX_IMAGES.sparkle,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(isCoin and 34 or 22, isCoin and 34 or 22),
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 61,
        }, host)
        local angle = (i / 24) * math.pi * 2
        local distance = 0.18 + math.random() * 0.2
        TweenService
            :Create(piece, TweenInfo.new(0.6, Enum.EasingStyle.Quart), {
                Position = UDim2.fromScale(0.5 + math.cos(angle) * distance, 0.5 + math.sin(angle) * distance * 1.4),
                Rotation = math.random(-200, 200),
            })
            :Play()
        task.delay(0.55, function()
            if piece.Parent then
                TweenService:Create(piece, TweenInfo.new(0.45), { ImageTransparency = 1 }):Play()
            end
        end)
    end
    task.delay(1.3, function()
        host:Destroy()
    end)
end

RENDER.VipShop = function(panel)
    local layer = liveLayerOf(panel)
    local shopSystem = ReplicatedStorage:FindFirstChild("ShopSystem")
    local shopRemote = shopSystem and shopSystem:FindFirstChild("ShopRemote")
    local ok, shopState
    if shopRemote then
        ok, shopState = shopRemote:InvokeServer("State")
    end
    if shopView then
        shopView:Destroy()
        shopView = nil
    end
    clear(layer)
    if not ok then
        text(box(layer, 0.5, 0.5, 0.6, 0.08), shopRemote and tostring(shopState) or "Shop is loading…")
        return
    end
    StudUI.useShell(panel)
    local ShopConfig = require(shopSystem.ShopConfig)
    local Colors = StudTheme.Colors
    local Icons, Art = ShopConfig.Icons or {}, ShopMenuConfig.Assets
    local icons = {
        crown = Art.Crown or Icons.Crown,
        coin = Art.Coin or Icons.Coins,
        money2x = Art.Coin or Icons.Money2x,
        hatch2x = Art.Hatch or Icons.Hatch2x,
        mystery = Art.Crown or Icons.Chalice or Icons.Chest,
    }
    -- server times (os.time) -> os.clock deadlines for the live countdowns
    local clockOffset = os.clock() - shopState.serverTime
    local function priceText(key, isGamePass)
        local productId = isGamePass and ShopConfig.GamePasses[key] or ShopConfig.Products[key]
        if (productId or 0) == 0 then
            return "SOON"
        end
        return "R$ " .. tostring(livePrice(productId, isGamePass, ShopConfig.Prices[key]) or "?")
    end
    local function shopAction(action, ...)
        local success, message = shopRemote:InvokeServer(action, ...)
        if message then
            showToast(message, success and "success" or "error")
        end
        if success then
            UISound.Play(
                (action and (string.find(action, "Buy") or string.find(action, "Purchase"))) and "Purchase" or "Claim"
            )
            pcall(playBuyBurst, panel, icons.coin)
        end
        RENDER.VipShop(panel)
    end
    local function buy(key)
        return function()
            shopAction("Buy", key)
        end
    end
    local function boost(title, shortText, textLine, key, iconImage, activeUntil)
        return {
            title = title,
            shortText = shortText,
            text = textLine,
            icon = iconImage,
            price = priceText(key),
            activeEnds = (activeUntil or 0) > shopState.serverTime and activeUntil + clockOffset or nil,
            duration = (ShopConfig.BoostMinutes or 30) * 60,
            onBuy = buy(key),
        }
    end

    local limitedDeal = ShopConfig.LimitedDeal
    local shopModels = shopSystem:FindFirstChild("ShopModels")
    local limited = limitedDeal
        and {
            name = limitedDeal.name,
            text = limitedDeal.text,
            art = Art.LimitedArt,
            eggModel = shopModels and shopModels:FindFirstChild(limitedDeal.key),
            endsAt = limitedDeal.endsAt + clockOffset,
            price = priceText(limitedDeal.key),
            onBuy = buy(limitedDeal.key),
        }

    -- money multiplier: one permanent level at a time
    local moneyLevels = ShopConfig.MoneyLevels
    local moneyLevel = shopState.moneyLevel or 0
    local currentMult = moneyLevel > 0 and moneyLevels[moneyLevel].mult or 1
    local nextLevel = moneyLevels[moneyLevel + 1]

    -- hatch speed: permanent levels bought with CASH (ShopConfig.HatchLevels), charged by the server
    local hatchLevels = ShopConfig.HatchLevels or {}
    local hatchLevel = shopState.hatchLevel or 0
    local currentHatchMult = hatchLevel > 0 and hatchLevels[hatchLevel].mult or 1
    local nextHatchLevel = hatchLevels[hatchLevel + 1]

    -- cash packs: bonus = how much more cash per Robux than the small pack
    local function robuxPriceOf(productKey)
        return tonumber(livePrice(ShopConfig.Products[productKey], false, ShopConfig.Prices[productKey]))
            or ShopConfig.Prices[productKey]
            or 1
    end
    local baseRate = (ShopConfig.CashPacks.CashSmall or 1) / math.max(robuxPriceOf("CashSmall"), 1)
    local cash = {}
    for i, packKey in { "CashSmall", "CashMedium", "CashLarge" } do
        local amount = ShopConfig.CashPacks[packKey] or 0
        local bonus = math.floor((amount / math.max(robuxPriceOf(packKey), 1) / baseRate - 1) * 100 + 0.5)
        cash[i] = {
            amount = "$" .. Config.Short(amount),
            text = "Instant cash",
            badge = i == 2 and "MOST POPULAR" or (bonus > 0 and ("+" .. bonus .. "% MORE")) or nil,
            badgeColor = i == 2 and Colors.Red or nil,
            price = priceText(packKey),
            onBuy = buy(packKey),
        }
    end

    -- daily rewards: 7-day streak
    local daily = shopState.daily
    local days = {}
    for i, reward in ShopConfig.Daily do
        days[i] = {
            label = "DAY " .. i,
            icon = reward.kind == "cash" and icons.coin
                or reward.kind == "mystery" and icons.mystery
                or reward.boost == "Hatch2x" and icons.hatch2x
                or icons.money2x,
            value = reward.label or ("$" .. Config.Short(reward.amount)),
            valueColor = reward.kind == "cash" and Colors.Gold or Colors.White,
            state = (i == daily.day and daily.ready) and "today"
                or (i < daily.day or i == daily.day) and "claimed"
                or "locked",
            last = i == #ShopConfig.Daily,
        }
    end

    local minutes = ShopConfig.BoostMinutes or 30
    shopView = ShopMenuComponent.new(panel, layer, {
        title = workspace:GetAttribute("HalloweenMode") and ShopMenuConfig.Titles.Halloween
            or ShopMenuConfig.Titles.Default,
        tab = shopTab,
        onTab = function(tab)
            shopTab = tab
            RENDER.VipShop(panel)
        end,
        icons = icons,
        limited = limited,
        vip = {
            text = "+ Exclusive Perks",
            perks = "Crown + gold chat tag\n+10% cash · 2× daily cash",
            price = priceText("VIP", true),
            owned = shopState.vip,
            onBuy = buy("VIP"),
        },
        boosts = {
            boost(
                "2× MONEY",
                "Earn 2× money",
                minutes .. " min of double cash",
                "Money2x",
                icons.money2x,
                shopState.money2xUntil
            ),
            boost(
                "2× HATCH",
                "Hatch 2× faster",
                "Eggs hatch twice as fast for " .. minutes .. " min",
                "Hatch2x",
                icons.hatch2x,
                shopState.hatch2xUntil
            ),
        },
        starter = {
            title = "STARTER PACK",
            text = "$"
                .. Config.Short(ShopConfig.StarterPack.cash)
                .. " + "
                .. ShopConfig.StarterPack.boostMinutes
                .. " min boosts",
            price = priceText("StarterPack", true),
            owned = shopState.starter,
            onBuy = buy("StarterPack"),
        },
        money = {
            value = nextLevel and (currentMult .. "× → " .. nextLevel.mult .. "×") or (currentMult .. "× MAXED"),
            level = moneyLevel,
            maxLevel = #moneyLevels,
            levelText = "Level " .. moneyLevel .. " / " .. #moneyLevels .. " · permanent",
            price = nextLevel and (nextLevel.productId == 0 and "SOON" or ("R$ " .. livePrice(
                nextLevel.productId,
                false,
                nextLevel.robux
            ))),
            maxed = nextLevel == nil,
            onBuy = function()
                shopAction("BuyMoneyLevel")
            end,
        },
        hatch = {
            value = nextHatchLevel and (currentHatchMult .. "× → " .. nextHatchLevel.mult .. "×")
                or (currentHatchMult .. "× MAXED"),
            level = hatchLevel,
            maxLevel = #hatchLevels,
            price = nextHatchLevel and ("$" .. Config.Short(nextHatchLevel.cash)) or "MAXED",
            maxed = nextHatchLevel == nil,
            onBuy = function()
                shopAction("BuyHatchLevel")
            end,
        },
        cash = cash,
        daily = {
            days = days,
            ready = daily.ready,
            claimText = "CLAIM DAY " .. daily.day,
            nextEnds = os.clock() + (daily.nextIn or 0),
            onClaim = function()
                shopAction("ClaimDaily")
            end,
        },
    })
end

-- ===== 9. Plot panel ("My Plot") =====
-- _plotTabs / _legacyOverview / _legacyUpgrades (and plotPage) are the old pages; nothing calls them any more
-- because RENDER.Plot hands the Figma layout to PlotComponent. Kept for reference.
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

-- Current Plot layout: PlotComponent draws Figma "03 Plot"; RENDER.Plot only builds its view model.
local plotTab = "slots" -- "slots" | "upgrades"
local plotScrollY = { slots = 0, upgrades = 0 } -- kept across refreshes
local plotView -- PlotComponent of the last render

RENDER.Plot = function(panel)
    local data, errorMessage = fetchState("plot")
    local layer = liveLayerOf(panel)
    if plotView then
        plotView:Destroy()
        plotView = nil
    end
    clear(layer)
    panel:SetAttribute("Page", "figma")
    if not data then
        text(box(layer, 0.5, 0.5, 0.6, 0.08), errorMessage)
        return
    end
    StudUI.useShell(panel)
    local UpgradePrices = require(ReplicatedStorage.UpgradePrices)
    local function money(value)
        return "$" .. Config.Short(value)
    end
    local plot = findMyPlot()
    local slotsFolder = plot and plot:FindFirstChild("Slots")
    local chambers = plot and plot:FindFirstChild("Chambers")
    local level, slotCap, unlockedCount = data.level or 1, data.availableSlots or 12, data.unlocked or 0
    local function slotAt(i)
        return slotsFolder and slotsFolder:FindFirstChild(string.format("Slot%02d", i))
    end

    -- placed characters by slot number; any without one fill the first free unlocked cells
    local bySlot, unslotted, income = {}, {}, 0
    for _, item in data.items or {} do
        if item.state == "placed" then
            income += item.income or 0
            if item.slot and not bySlot[item.slot] then
                bySlot[item.slot] = item
            else
                table.insert(unslotted, item)
            end
        end
    end
    local nextSlot -- first locked slot within the temple's capacity (UnlockSlot buys slots in order)
    for i = 1, slotCap do
        local slot = slotAt(i)
        if slot and not slot:GetAttribute("Unlocked") then
            nextSlot = i
            break
        end
    end
    local function unlockNextSlot()
        runAction("UnlockSlot")
    end
    local slots = {}
    for i = 1, slotCap do
        local slot = slotAt(i)
        local isUnlocked = if slot then slot:GetAttribute("Unlocked") == true else i <= unlockedCount
        local item = bySlot[i] or (isUnlocked and table.remove(unslotted, 1)) or nil
        if item then
            slots[i] = {
                number = i,
                state = "placed",
                image = item.image,
                name = item.name,
                income = money(item.income or 0) .. "/s",
            }
        elseif isUnlocked then
            slots[i] = { number = i, state = "empty" }
        else
            local price = slot and slot:GetAttribute("UnlockPrice")
            slots[i] = {
                number = i,
                state = "locked",
                price = price and money(price) or "LOCKED",
                onActivate = i == nextSlot and unlockNextSlot or nil,
            }
        end
    end

    -- right column: temple, incubator speed (lowest-level incubator), add incubator
    local incubatorCount = chambers and #chambers:GetChildren() or 0
    local function chamberLevel(i)
        local chamber = chambers and chambers:FindFirstChild("Chamber" .. i)
        return chamber and (chamber:GetAttribute("UpgradeLevel") or 1)
    end
    local speedIndex, speedLevel
    for i = 1, 3 do
        local chamberLv = chamberLevel(i)
        if chamberLv and chamberLv < 3 and (not speedLevel or chamberLv < speedLevel) then
            speedIndex, speedLevel = i, chamberLv
        end
    end
    local templeMaxed = level >= 3
    local upgrades = {
        {
            name = "TempleUpgrades", -- FirstHatchTutorial step 11
            title = "TEMPLE EXPANSION",
            subtitle = templeMaxed and "Max level"
                or data.canUpgrade and ("Lv. " .. level .. " → " .. (level + 1) .. " · +12 slots")
                or "Unlock every slot first",
            price = templeMaxed and "MAX" or money(UpgradePrices.Temple[level + 1]),
            enabled = not templeMaxed and data.canUpgrade == true,
            onActivate = function()
                if templeMaxed then
                    showToast("Already maxed")
                elseif not data.canUpgrade then
                    showToast("Unlock all " .. slotCap .. " slots first")
                else
                    runAction("UpgradeTemple")
                end
            end,
        },
        {
            name = "IncubatorSpeed",
            title = "INCUBATOR SPEED",
            subtitle = speedIndex
                    and ("Incubator " .. speedIndex .. " · Lv. " .. speedLevel .. " → " .. (speedLevel + 1))
                or "Max level",
            price = speedIndex and money(UpgradePrices.IncubatorLevel[speedLevel + 1]) or "MAX",
            enabled = speedIndex ~= nil,
            onActivate = function()
                if speedIndex then
                    runAction("UpgradeIncubator", { index = speedIndex })
                else
                    showToast("Already maxed")
                end
            end,
        },
        {
            name = "IncubatorUpgrades", -- FirstHatchTutorial step 12
            title = "ADD INCUBATOR",
            subtitle = incubatorCount >= 3 and "All 3 built"
                or (incubatorCount .. " → " .. (incubatorCount + 1) .. " · hatch more at once"),
            price = incubatorCount >= 3 and "MAX" or money(UpgradePrices.AddIncubator[incubatorCount + 1]),
            enabled = incubatorCount < 3,
            onActivate = function()
                if incubatorCount < 3 then
                    runAction("AddIncubator")
                else
                    showToast("Already maxed")
                end
            end,
        },
    }

    -- Upgrades tab: one row per incubator
    local incubators = {}
    for i = 1, 3 do
        local chamberLv = chamberLevel(i)
        if chamberLv then
            incubators[i] = {
                title = "INCUBATOR " .. i,
                subtitle = chamberLv >= 3 and "Max level · fastest hatching"
                    or ("Lv. " .. chamberLv .. " → " .. (chamberLv + 1) .. " · hatch eggs faster"),
                progress = chamberLv / 3,
                price = chamberLv >= 3 and "MAX" or money(UpgradePrices.IncubatorLevel[chamberLv + 1]),
                enabled = chamberLv < 3,
                onActivate = function()
                    if chamberLv < 3 then
                        runAction("UpgradeIncubator", { index = i })
                    else
                        showToast("Already maxed")
                    end
                end,
            }
        else
            local isNext = i == incubatorCount + 1
            incubators[i] = {
                title = "INCUBATOR " .. i,
                subtitle = "Not built yet · hatch more at once",
                progress = 0,
                price = isNext and money(UpgradePrices.AddIncubator[i]) or "LOCKED",
                enabled = isNext,
                onActivate = function()
                    if isNext then
                        runAction("AddIncubator")
                    else
                        showToast("Build incubator " .. (i - 1) .. " first")
                    end
                end,
            }
        end
    end

    -- footer milestone: next slot, then the temple upgrade, then done
    local milestone
    if nextSlot then
        local price = slotAt(nextSlot):GetAttribute("UnlockPrice")
        milestone = {
            text = "UNLOCK SLOT " .. nextSlot .. (price and (" · " .. money(price)) or ""),
            enabled = true,
            onActivate = unlockNextSlot,
        }
    elseif data.canUpgrade and not templeMaxed then
        milestone = {
            text = "UPGRADE TEMPLE · " .. money(UpgradePrices.Temple[level + 1]),
            enabled = true,
            onActivate = function()
                runAction("UpgradeTemple")
            end,
        }
    else
        milestone = { text = "ALL SLOTS UNLOCKED", enabled = false }
    end

    plotView = PlotComponent.new(panel, layer, {
        tab = plotTab,
        scrollY = plotScrollY[plotTab],
        stats = {
            { "TOTAL INCOME", money(income) .. " / sec" },
            { "TEMPLE LEVEL", tostring(level) },
            { "INCUBATORS", incubatorCount .. " / 3" },
        },
        slots = slots,
        slotsText = unlockedCount .. " / " .. slotCap .. " slots unlocked",
        slotsProgress = unlockedCount / math.max(slotCap, 1),
        upgrades = upgrades,
        incubators = incubators,
        milestone = milestone,
        onTab = function(tab)
            plotTab = tab
            refresh()
        end,
        -- EQUIP BEST: the server (GameMenu action EquipBest -> InventoryService PlaceBest) places the
        -- highest-income characters on the unlocked slots and replies with the toast message.
        onEquipBest = function()
            runAction("EquipBest")
        end,
        onScroll = function(y)
            plotScrollY[plotTab] = y
        end,
    })
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

for _, panelName in { "Plot", "Index", "Quests", "VipShop" } do
    gui:WaitForChild(panelName):WaitForChild("Close").Activated:Connect(closeMenu)
end

-- Left menu buttons -> the existing actions (same sounds as the old side buttons)
do
    local goHomeRemote = ReplicatedStorage:WaitForChild("GoHome", 10)
    local function toggleSettings()
        -- MusicSettings owns the Settings panel; its Toggle bindable runs its own open/close
        local settingsGui = player.PlayerGui:FindFirstChild("MusicSettingsUI")
        local toggle = settingsGui and settingsGui:FindFirstChild("Toggle")
        if toggle then
            toggle:Fire()
        end
    end
    for _, menuButton in leftMenu.Buttons do
        menuButton.MouseEnter:Connect(function()
            UISound.Play("Hover")
        end)
    end
    for _, entry in LeftMenuConfig.Grid do
        local menuButton = leftMenu.Buttons[entry.Key]
        if entry.Key == "Settings" then
            menuButton.Activated:Connect(toggleSettings)
        elseif entry.Key == "Daily" then
            -- opens the shop on its DAILY tab (switches tab if the shop is already open), never closes it
            local panel = gui:WaitForChild(entry.Panel)
            menuButton.Activated:Connect(function()
                UISound.Play("Click")
                shopTab = "DAILY"
                if openPanel ~= panel then
                    showPanel(panel)
                else
                    refresh()
                end
            end)
        else
            local panel = gui:WaitForChild(entry.Panel)
            menuButton.Activated:Connect(function()
                UISound.Play("Click")
                if entry.Key == "Shop" and openPanel ~= panel then
                    shopTab = "FEATURED"
                end
                showPanel(panel)
            end)
        end
    end
    -- Home: the same GoHome remote as GameHUD's H key (GameHUD shows the server's reply)
    leftMenu.Buttons.Home.Activated:Connect(function()
        UISound.Play("Click")
        if goHomeRemote then
            goHomeRemote:FireServer()
        end
    end)
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
