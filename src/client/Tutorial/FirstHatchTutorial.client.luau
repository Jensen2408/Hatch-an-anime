--[[ FirstHatchTutorial (LocalScript, StarterPlayerScripts)
A local first-hatch guide. No client requests can grant progress or rewards.

Steps 1..8 (world guide): ReplicatedStorage.FirstHatchGuide.Resolve(player) picks the step and target part;
this script shows the top card, a highlight, a destination sign and a beam toward the target.
Steps 9..12 (UI tour of Plot -> Upgrades): server-driven via Player.TutorialTourStage. The client only reports
what it saw through ReplicatedStorage.FirstHatchTutorialAction (RemoteEvent, action string:
PlotOpened / UpgradesOpened / TempleSeen / IncubatorsSeen); TutorialProgress (server) validates the stage and
advances it. Step 13 / Player.TutorialCompleted ends the guide.

Reads player attributes TutorialDataReady, TutorialCompleted, JoinArrivalStarted / JoinArrivalFinished.
Depends on instance names owned by other scripts (see the GameHUD / MenuLogic headers):
  PlayerGui.GameHUD.EggBag, GameMenus.Dim / .Plot (attribute Page, child Live with UpgradesTab,
  TempleUpgrades, IncubatorUpgrades) / .SideButtons.PlotButton, MusicSettingsUI.Panel, CharacterInventory,
  OwnerPanel, StolenEggBanner.Frame, CinematicHatchUI (attribute Active), PromptCard billboards,
  HatchLoading / LaunchLoadingScreen.
]]

-- ===== 1. Services and dependencies =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local _PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local guideModule = ReplicatedStorage:WaitForChild("FirstHatchGuide")
local Guide = require(guideModule)
local tourRemote = ReplicatedStorage:WaitForChild("FirstHatchTutorialAction")
-- Same temple palette as the inventory and leaderboard (shrine redesign).
local Theme = require(ReplicatedStorage:WaitForChild("CharacterInventory"):WaitForChild("InventoryConfig")).Theme
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== 2. Helpers and style constants =====
local function create(class, props, parent)
    local instance = Instance.new(class)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local BLACK = Color3.new(0, 0, 0)
local DISPLAY_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local function addStroke(parent, thickness)
    return create("UIStroke", {
        Color = BLACK,
        Thickness = thickness or 2.5,
        LineJoinMode = Enum.LineJoinMode.Miter,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end
-- Card (house style): plate + orange strip + black outline. Big step number, bold objective,
-- the full instruction under it, a slim progress bar and a distance hint.
-- ===== 3. Guide card (steps 1..8) =====
local CARD_WIDTH, CARD_HEIGHT = 380, 112
local PLATE_COLOR = Color3.fromRGB(38, 56, 68)
local ACCENT_ORANGE = Color3.fromRGB(255, 150, 30)
local gui = create("ScreenGui", {
    Name = "FirstHatchTutorial",
    ResetOnSpawn = false,
    DisplayOrder = 55,
    Enabled = false,
    ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
}, playerGui)
local card = create("Frame", {
    Name = "GuideCard",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 72),
    Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT),
    BackgroundColor3 = PLATE_COLOR,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    Active = false,
}, gui)
addStroke(card, 4)
create("ImageLabel", {
    Name = "Studs",
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Image = "rbxassetid://132561191216691",
    ScaleType = Enum.ScaleType.Tile,
    TileSize = UDim2.fromOffset(26, 26),
    ImageTransparency = 0.92,
}, card)
create(
    "Frame",
    { Name = "Strip", Size = UDim2.new(1, 0, 0, 6), BackgroundColor3 = ACCENT_ORANGE, BorderSizePixel = 0, ZIndex = 2 },
    card
)
local cardScale = create("UIScale", {}, card)
local stepTag = create("Frame", {
    Name = "StepTag",
    Position = UDim2.fromOffset(14, 20),
    Size = UDim2.fromOffset(60, 60),
    BackgroundColor3 = Color3.fromRGB(255, 176, 40),
    BorderSizePixel = 0,
    ZIndex = 2,
}, card)
addStroke(stepTag, 3)
create("ImageLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Image = "rbxassetid://132561191216691",
    ScaleType = Enum.ScaleType.Tile,
    TileSize = UDim2.fromOffset(20, 20),
    ImageTransparency = 0.2,
    ZIndex = 2,
}, stepTag)
local stepLabel = create("TextLabel", {
    Name = "Progress",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "",
    FontFace = DISPLAY_FONT,
    TextSize = 34,
    TextColor3 = Color3.new(1, 1, 1),
    ZIndex = 3,
}, stepTag)
create("UIStroke", { Color = BLACK, Thickness = 3 }, stepLabel)
local objectiveLabel = create("TextLabel", {
    Name = "Objective",
    Position = UDim2.fromOffset(88, 16),
    Size = UDim2.new(1, -100, 0, 28),
    BackgroundTransparency = 1,
    Text = "",
    FontFace = DISPLAY_FONT,
    TextSize = 24,
    TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 2,
}, card)
create("UIStroke", { Color = BLACK, Thickness = 2.5 }, objectiveLabel)
local instructionLabel = create("TextLabel", {
    Name = "Instruction",
    Position = UDim2.fromOffset(88, 44),
    Size = UDim2.new(1, -100, 0, 36),
    BackgroundTransparency = 1,
    Text = "",
    FontFace = BODY_FONT,
    TextSize = 14,
    TextColor3 = Color3.fromRGB(215, 228, 236),
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 2,
}, card)
local progressTrack = create("Frame", {
    Name = "Track",
    Position = UDim2.new(0, 14, 1, -20),
    Size = UDim2.new(0.55, 0, 0, 8),
    BackgroundColor3 = Color3.fromRGB(16, 24, 30),
    BorderSizePixel = 0,
    ZIndex = 2,
}, card)
addStroke(progressTrack, 2)
local progressFill = create(
    "Frame",
    { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = ACCENT_ORANGE, BorderSizePixel = 0, ZIndex = 3 },
    progressTrack
)
local distanceLabel = create("TextLabel", {
    Name = "Distance",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -14, 1, -27),
    Size = UDim2.new(0.4, -14, 0, 20),
    BackgroundTransparency = 1,
    Text = "",
    FontFace = DISPLAY_FONT,
    TextSize = 14,
    TextColor3 = Color3.fromRGB(255, 206, 60),
    TextXAlignment = Enum.TextXAlignment.Right,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 2,
}, card)
create("UIStroke", { Color = BLACK, Thickness = 2 }, distanceLabel)
-- applyLayout is a no-op hook kept for the phone "squeezed" layout; fitToScreen still tracks the state.
local squeezed = false
local function applyLayout() end
local function setProgress(stepNumber)
    local fraction = math.clamp(((stepNumber or 1) - 1) / #Guide.Steps, 0, 1)
    TweenService:Create(
        progressFill,
        TweenInfo.new(0.35, Enum.EasingStyle.Quad),
        { Size = UDim2.fromScale(math.max(fraction, 0.03), 1) }
    ):Play()
end
-- The card steps aside while a menu panel (shop, egg bag, inventory, settings) is open.
local function isGuiShown(guiName, childName)
    local screenGui = playerGui:FindFirstChild(guiName)
    if not (screenGui and screenGui:IsA("ScreenGui") and screenGui.Enabled) then
        return false
    end
    if not childName then
        for _, child in screenGui:GetChildren() do
            if child:IsA("GuiObject") and child.Visible then
                return true
            end
        end
        return false
    end
    local child = screenGui:FindFirstChild(childName)
    return child ~= nil and child:IsA("GuiObject") and child.Visible
end
local function isMenuOpen()
    return isGuiShown("GameHUD", "EggBag")
        or isGuiShown("GameMenus", "Dim")
        or isGuiShown("MusicSettingsUI", "Panel")
        or isGuiShown("CharacterInventory")
        or isGuiShown("OwnerPanel")
end
-- Scales the card for the viewport and moves it below the egg banner; snaps on first placement, tweens after.
local cardTop, cardTween = nil, nil
local function fitToScreen()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local viewportSize = camera.ViewportSize
    local isPhone = viewportSize.Y < 500 or (game:GetService("UserInputService").TouchEnabled and viewportSize.X < 1100)
    local useCompactScale = isPhone
    -- Phones get a smaller card that sits just under the top bar instead of over the play area.
    cardScale.Scale = useCompactScale and 0.5 or 0.8
    local targetTop = isPhone and 2 or 30
    -- Slide below the stolen/returning egg banner while it is showing (title row only on phones).
    local banner = playerGui:FindFirstChild("StolenEggBanner")
    local bannerFrame = banner and banner:IsA("ScreenGui") and banner.Enabled and banner:FindFirstChild("Frame")
    local isBannerShowing = false
    if bannerFrame and bannerFrame:IsA("GuiObject") and bannerFrame.Visible then
        local bannerBottom = bannerFrame.AbsolutePosition.Y + bannerFrame.AbsoluteSize.Y
        if bannerBottom > 0 then
            targetTop = math.max(targetTop, math.floor(bannerBottom + 6))
            isBannerShowing = true
        end
    end
    local shouldSqueeze = isPhone and isBannerShowing
    if shouldSqueeze ~= squeezed then
        squeezed = shouldSqueeze
        applyLayout()
    end
    if targetTop ~= cardTop then
        local isFirstPlacement = cardTop == nil
        cardTop = targetTop
        if cardTween then
            cardTween:Cancel()
        end
        if isFirstPlacement then
            card.Position = UDim2.new(0.5, 0, 0, targetTop)
        else
            cardTween = TweenService:Create(
                card,
                TweenInfo.new(0.25, Enum.EasingStyle.Quad),
                { Position = UDim2.new(0.5, 0, 0, targetTop) }
            )
            cardTween:Play()
        end
    end
end

-- ===== 4. World guide: highlight, destination sign, beam =====
local worldFolder = create("Folder", { Name = "TutorialGroundTrail" }, workspace)
local objectiveHighlight = create("Highlight", {
    Name = "TutorialObjective",
    FillTransparency = 1,
    OutlineTransparency = 0.45,
    OutlineColor = Theme.GoldHi,
    DepthMode = Enum.HighlightDepthMode.Occluded,
    Enabled = false,
}, worldFolder)
-- Destination sign: a cream plate with a gold sill and a pointer, like the prompt cards.
local destinationMarker = create("BillboardGui", {
    Name = "Destination",
    Size = UDim2.fromOffset(160, 36),
    StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0),
    AlwaysOnTop = true,
    MaxDistance = 180,
    Enabled = false,
    LightInfluence = 0,
}, gui)
local markerPointer = create("Frame", {
    Name = "Tip",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0, 26),
    Size = UDim2.fromOffset(9, 9),
    Rotation = 45,
    BackgroundColor3 = Theme.Gold,
    BorderSizePixel = 0,
}, destinationMarker)
addStroke(markerPointer, 2)
local markerPlate = create("Frame", {
    Name = "Plate",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 2),
    Size = UDim2.fromOffset(0, 24),
    AutomaticSize = Enum.AutomaticSize.X,
    BackgroundColor3 = Theme.Card,
    BackgroundTransparency = 0.25,
    BorderSizePixel = 0,
    ZIndex = 2,
}, destinationMarker)
addStroke(markerPlate, 2.5)
local markerCaption = create("TextLabel", {
    Name = "Caption",
    Size = UDim2.new(0, 0, 1, -4),
    AutomaticSize = Enum.AutomaticSize.X,
    BackgroundTransparency = 1,
    Text = "",
    FontFace = DISPLAY_FONT,
    TextSize = 13,
    TextColor3 = Theme.Ink,
    ZIndex = 3,
}, markerPlate)
create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, markerCaption)
create("Frame", {
    Name = "Sill",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.fromScale(0, 1),
    Size = UDim2.new(1, 0, 0, 3),
    BackgroundColor3 = Theme.Gold,
    BorderSizePixel = 0,
    ZIndex = 3,
}, markerPlate)

-- In-world guide: one straight Beam from an Attachment on the player to an Attachment on the
-- objective. No pathfinding and no animation. The arrow texture points toward Attachment0, so
-- Attachment0 sits on the target and Attachment1 on the player.
local ARROW_TEXTURE = "rbxassetid://86109313256799"
local guideBeam = create("Beam", {
    Name = "GuideBeam",
    Enabled = false,
    FaceCamera = true,
    Width0 = 1.5,
    Width1 = 1.5,
    Color = ColorSequence.new(Theme.GoldHi),
    Transparency = NumberSequence.new(0.45),
    LightEmission = 0.4,
    LightInfluence = 0,
    Segments = 1,
    Texture = ARROW_TEXTURE,
    TextureMode = Enum.TextureMode.Static,
    TextureLength = 3,
    TextureSpeed = 0,
}, worldFolder)
local goalAttachment -- Attachment on the current target part
local footAttachment -- Attachment on the local character
local currentStep, currentTarget
-- ===== 5. State and target helpers =====
local stopped = false
-- true once the guide was visible at least once; finish() only shows the "ready" card then.
local hasShownGuide = false
local connections = {}
local function hideTrail()
    guideBeam.Enabled = false
end
local function clearTarget()
    hideTrail()
    if goalAttachment then
        goalAttachment:Destroy()
        goalAttachment = nil
    end
    objectiveHighlight.Enabled = false
    objectiveHighlight.Adornee = nil
    destinationMarker.Enabled = false
    destinationMarker.Adornee = nil
end
-- Destination labels yield to the real interaction card at the same anchor.
local function hasInteractionCard(part)
    for _, billboard in playerGui:GetChildren() do
        if billboard:IsA("BillboardGui") and billboard.Name == "PromptCard" and billboard.Enabled then
            local adornee = billboard.Adornee
            if adornee == part or (adornee and adornee:IsDescendantOf(part)) then
                return true
            end
        end
    end
    return false
end
local function hatchCameraActive()
    local cinematicGui = playerGui:FindFirstChild("CinematicHatchUI")
    return cinematicGui and cinematicGui:GetAttribute("Active") == true
end
-- Hide immediately at camera takeover rather than waiting for the next guide update.
local function watchHatchUI(cinematicGui)
    if cinematicGui.Name ~= "CinematicHatchUI" then
        return
    end
    local function onActiveChanged()
        if cinematicGui:GetAttribute("Active") == true then
            gui.Enabled = false
            clearTarget()
        end
    end
    table.insert(connections, cinematicGui:GetAttributeChangedSignal("Active"):Connect(onActiveChanged))
    onActiveChanged()
end
local existingCinematic = playerGui:FindFirstChild("CinematicHatchUI")
if existingCinematic then
    watchHatchUI(existingCinematic)
end
table.insert(connections, playerGui.ChildAdded:Connect(watchHatchUI))
local function ensureFoot(rootPart)
    if footAttachment and footAttachment.Parent == rootPart then
        return
    end
    if footAttachment then
        footAttachment:Destroy()
    end
    footAttachment = create("Attachment", { Name = "TutorialGuideFoot", Position = Vector3.new(0, -1.5, 0) }, rootPart)
    guideBeam.Attachment1 = footAttachment
end
local function ensureGoal(part)
    if goalAttachment and goalAttachment.Parent == part then
        return
    end
    if goalAttachment then
        goalAttachment:Destroy()
    end
    goalAttachment = create("Attachment", { Name = "TutorialGuideGoal" }, part)
    guideBeam.Attachment0 = goalAttachment
end

-- ===== 6. UI tour (steps 9..12) =====
-- Final UI tour. Keep the existing world guide and compact card unchanged.
local tourCanvas = create(
    "Frame",
    { Name = "UpgradeTour", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false },
    gui
)
local focusFrame = create(
    "Frame",
    { Name = "Focus", BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 20 },
    tourCanvas
)
create("UIStroke", { Color = Theme.GoldHi, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, focusFrame)
local coachCard = create("Frame", {
    Name = "Coach",
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -8),
    Size = UDim2.fromOffset(340, 116),
    BackgroundColor3 = Theme.Screen,
    BorderSizePixel = 0,
    ZIndex = 30,
}, tourCanvas)
addStroke(coachCard, 2)
local coachTitle = create("TextLabel", {
    Name = "Title",
    Position = UDim2.fromOffset(12, 7),
    Size = UDim2.new(1, -24, 0, 22),
    BackgroundTransparency = 1,
    FontFace = DISPLAY_FONT,
    TextSize = 16,
    TextColor3 = Theme.GoldHi,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 31,
}, coachCard)
local coachBody = create("TextLabel", {
    Name = "Body",
    Position = UDim2.fromOffset(12, 31),
    Size = UDim2.new(1, -24, 0, 48),
    BackgroundTransparency = 1,
    FontFace = BODY_FONT,
    TextSize = 13,
    TextColor3 = Theme.PageText,
    TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 31,
}, coachCard)
local coachHint = create("TextLabel", {
    Name = "Hint",
    Position = UDim2.new(0, 12, 1, -30),
    Size = UDim2.new(1, -132, 0, 22),
    BackgroundTransparency = 1,
    FontFace = BODY_FONT,
    TextSize = 11,
    TextColor3 = Theme.GoldHi,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 31,
}, coachCard)
local nextButton = create("TextButton", {
    Name = "Next",
    AnchorPoint = Vector2.new(1, 1),
    Position = UDim2.new(1, -10, 1, -8),
    Size = UDim2.fromOffset(100, 27),
    BackgroundColor3 = Theme.Gold,
    TextColor3 = Theme.Ink,
    FontFace = DISPLAY_FONT,
    TextSize = 14,
    Text = "NEXT",
    BorderSizePixel = 0,
    ZIndex = 32,
}, coachCard)
addStroke(nextButton, 2)
local tourPanel, originalPanelPosition = nil, nil
local panelLift = 0
local function restoreTourPanel()
    if tourPanel and tourPanel.Parent and originalPanelPosition then
        tourPanel.Position = originalPanelPosition
    end
    tourPanel = nil
    originalPanelPosition = nil
    panelLift = 0
end
local nextAction = nil
local lastAckAt, lastAckStep = -math.huge, nil
local viewedTarget, viewedSince = nil, 0
local function isUiVisible(guiObject)
    if
        not guiObject
        or not guiObject:IsA("GuiObject")
        or guiObject.AbsoluteSize.X <= 0
        or guiObject.AbsoluteSize.Y <= 0
    then
        return false
    end
    local ancestor = guiObject
    while ancestor and ancestor ~= playerGui do
        if ancestor:IsA("GuiObject") and not ancestor.Visible then
            return false
        end
        if ancestor:IsA("ScreenGui") and not ancestor.Enabled then
            return false
        end
        ancestor = ancestor.Parent
    end
    return ancestor == playerGui
end
-- Reports a tour action to the server, at most once per second per step (the server ignores
-- anything that does not match the current TutorialTourStage).
local function acknowledge(action)
    if lastAckStep == currentStep and os.clock() - lastAckAt < 1 then
        return
    end
    lastAckAt = os.clock()
    lastAckStep = currentStep
    tourRemote:FireServer(action)
end
table.insert(
    connections,
    nextButton.Activated:Connect(function()
        if nextAction and nextButton.Interactable and isUiVisible(viewedTarget) then
            acknowledge(nextAction)
        end
    end)
)
-- Step 9: open Plot (auto-acknowledged once open). Step 10: open the Upgrades page (auto-acknowledged).
-- Steps 11/12: look at Temple / Incubator upgrades, then press NEXT / GOT IT (enabled after 0.8 s of viewing).
-- Until the right panel is open, the focus frame points at the button that opens it.
local function updateTour()
    clearTarget()
    card.Visible = false
    tourCanvas.Visible = true
    gui.Enabled = true
    hasShownGuide = true
    local gameMenus = playerGui:FindFirstChild("GameMenus")
    gui.DisplayOrder = math.max(65, gameMenus and gameMenus.DisplayOrder + 2 or 65)
    local isCompact = tourCanvas.AbsoluteSize.Y < 500
    coachCard.Size =
        UDim2.fromOffset(math.min(340, math.max(220, tourCanvas.AbsoluteSize.X - 20)), isCompact and 112 or 116)
    coachCard.Position = UDim2.new(0.5, 0, 1, isCompact and -4 or -8)
    coachBody.Size = isCompact and UDim2.new(1, -132, 0, 58) or UDim2.new(1, -24, 0, 48)
    coachBody.TextSize = isCompact and 12 or 13
    coachHint.Position = UDim2.new(0, 12, 1, isCompact and -18 or -30)
    coachHint.Size = UDim2.new(1, -132, 0, isCompact and 14 or 22)
    nextButton.Size = UDim2.fromOffset(100, isCompact and 44 or 27)
    local plotPanel = gameMenus and gameMenus:FindFirstChild("Plot")
    local isPlotOpen = isUiVisible(plotPanel)
    local currentPage = isPlotOpen and plotPanel:GetAttribute("Page")
    local livePanel = plotPanel and plotPanel:FindFirstChild("Live")
    local wantedTarget
    local stepInfo = Guide.Steps[currentStep]
    coachTitle.Text = currentStep .. "/" .. #Guide.Steps .. "  " .. stepInfo.title
    coachBody.Text = stepInfo.body
    coachHint.Text = "Use the highlighted button"
    nextButton.Visible = false
    nextAction = nil
    if not isPlotOpen then
        local sideButtons = gameMenus and gameMenus:FindFirstChild("SideButtons")
        wantedTarget = sideButtons and sideButtons:FindFirstChild("PlotButton")
        coachBody.Text = "You can add more upgrades to your plot. Press Plot to find them."
    elseif currentStep == 9 then
        acknowledge("PlotOpened")
    elseif currentPage ~= "upgrades" and currentPage ~= "figma" then
        -- Only the legacy tabbed Plot panel has an Upgrades tab; the current "figma" layout shows the
        -- upgrade rows on the same page, so it counts as the Upgrades page already being open.
        wantedTarget = livePanel and livePanel:FindFirstChild("UpgradesTab", true)
        coachBody.Text = "Press Upgrades to see your temple and incubator upgrades."
    elseif currentStep == 10 then
        acknowledge("UpgradesOpened")
    else
        wantedTarget = livePanel
            and livePanel:FindFirstChild(currentStep == 11 and "TempleUpgrades" or "IncubatorUpgrades", true)
        nextAction = currentStep == 11 and "TempleSeen" or "IncubatorsSeen"
        nextButton.Text = currentStep == 11 and "NEXT" or "GOT IT!"
        nextButton.Visible = isUiVisible(wantedTarget)
        coachHint.Text = "No purchase needed"
    end
    if wantedTarget ~= viewedTarget then
        viewedTarget = wantedTarget
        viewedSince = os.clock()
    end
    nextButton.Interactable = nextButton.Visible and os.clock() - viewedSince >= 0.8
    nextButton.AutoButtonColor = nextButton.Interactable
    focusFrame.Visible = isUiVisible(wantedTarget)
    -- On short screens, lift the menu only enough to keep the highlighted row above the coach.
    if isPlotOpen then
        if tourPanel ~= plotPanel then
            restoreTourPanel()
            tourPanel = plotPanel
            originalPanelPosition = plotPanel.Position
        end
        local lift = 0
        if isCompact and focusFrame.Visible and wantedTarget:IsDescendantOf(plotPanel) then
            local rowBottom = wantedTarget.AbsolutePosition.Y + wantedTarget.AbsoluteSize.Y + panelLift
            local topRoom = math.max(0, plotPanel.AbsolutePosition.Y + panelLift - tourCanvas.AbsolutePosition.Y - 4)
            lift = math.clamp(rowBottom - coachCard.AbsolutePosition.Y + 10, 0, topRoom)
        end
        panelLift = lift
        plotPanel.Position = originalPanelPosition + UDim2.fromOffset(0, -lift)
    else
        restoreTourPanel()
    end
    if focusFrame.Visible then
        local offset = wantedTarget.AbsolutePosition - tourCanvas.AbsolutePosition
        focusFrame.Position = UDim2.fromOffset(offset.X - 3, offset.Y - 3)
        focusFrame.Size = UDim2.fromOffset(wantedTarget.AbsoluteSize.X + 6, wantedTarget.AbsoluteSize.Y + 6)
    end
end

-- ===== 7. Finish and update loop =====
-- Runs once: tears down the world guide and shows a 4 s "ready" card (only if the guide was ever shown).
local function finish()
    if stopped then
        return
    end
    stopped = true
    clearTarget()
    worldFolder:Destroy()
    tourCanvas.Visible = false
    gui.DisplayOrder = 55
    restoreTourPanel()
    if footAttachment then
        footAttachment:Destroy()
        footAttachment = nil
    end
    if goalAttachment then
        goalAttachment:Destroy()
        goalAttachment = nil
    end
    for _, connection in connections do
        connection:Disconnect()
    end
    if hasShownGuide then
        gui.Enabled = true
        card.Visible = true
        stepLabel.Text = "✓"
        objectiveLabel.Text = "You’re ready to grow!"
        setProgress(#Guide.Steps + 1)
        instructionLabel.Text = "Collect more eggs, hatch stronger characters, and unlock more podiums."
        distanceLabel.Text = "Find upgrades in Plot → Upgrades"
        task.delay(4, function()
            gui:Destroy()
        end)
    else
        gui:Destroy()
    end
end
-- Guide update, throttled to every 0.2 s.
local elapsed = 0
table.insert(
    connections,
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.2 then
            return
        end
        elapsed = 0
        if player:GetAttribute("TutorialCompleted") == true then
            finish()
            return
        end
        local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        local loadingScreen = playerGui:FindFirstChild("HatchLoading")
            or playerGui:FindFirstChild("LaunchLoadingScreen")
        local isArriving = player:GetAttribute("JoinArrivalStarted") and not player:GetAttribute("JoinArrivalFinished")
        local isReady = player:GetAttribute("TutorialDataReady")
            and rootPart
            and humanoid
            and humanoid.Health > 0
            and not loadingScreen
            and not isArriving
        if not isReady then
            gui.Enabled = false
            tourCanvas.Visible = false
            restoreTourPanel()
            clearTarget()
            return
        end
        -- isRevealing: Guide reports the hatch reveal is playing; the guide stays hidden meanwhile.
        local newStep, newTarget, note, isRevealing = Guide.Resolve(player)
        if newStep > #Guide.Steps then
            finish()
            return
        end
        if newStep ~= currentStep or newTarget ~= currentTarget then
            clearTarget()
            currentStep = newStep
            currentTarget = newTarget
        end
        gui:SetAttribute("Step", currentStep)
        if currentStep >= 9 then
            updateTour()
            return
        end
        tourCanvas.Visible = false
        gui.DisplayOrder = 55
        gui.Enabled = not isRevealing and not hatchCameraActive()
        objectiveHighlight.Enabled = false
        destinationMarker.Enabled = false
        if isRevealing or hatchCameraActive() then
            hideTrail()
            return
        end
        hasShownGuide = true
        local stepInfo = Guide.Steps[currentStep]
        stepLabel.Text = tostring(currentStep)
        objectiveLabel.Text = stepInfo.title
        instructionLabel.Text = note or stepInfo.body
        setProgress(currentStep)
        card.Visible = not isMenuOpen()
        fitToScreen()
        if isMenuOpen() then
            hideTrail()
            return
        end
        if not currentTarget or not currentTarget.Parent then
            distanceLabel.Text = "Finding your next goal…"
            hideTrail()
            return
        end
        objectiveHighlight.Adornee = currentTarget
        objectiveHighlight.Enabled = true
        destinationMarker.Adornee = currentTarget
        markerCaption.Text = stepInfo.marker
        local distanceToTarget = (currentTarget.Position - rootPart.Position).Magnitude
        destinationMarker.Enabled = distanceToTarget > 7 and not hasInteractionCard(currentTarget)
        distanceLabel.Text = distanceToTarget > 7 and ("→ " .. math.floor(distanceToTarget) .. " studs")
            or (currentStep == 4 and "Incubating…" or "You're here • use the prompt")
        if distanceToTarget <= 7 then
            hideTrail()
            return
        end
        ensureFoot(rootPart)
        ensureGoal(currentTarget)
        guideBeam.Enabled = true
    end)
)
table.insert(
    connections,
    player:GetAttributeChangedSignal("TutorialCompleted"):Connect(function()
        if player:GetAttribute("TutorialCompleted") then
            finish()
        end
    end)
)
-- ===== 8. Cleanup =====
gui.Destroying:Connect(function()
    restoreTourPanel()
    stopped = true
    for _, connection in connections do
        connection:Disconnect()
    end
    if worldFolder.Parent then
        worldFolder:Destroy()
    end
    if footAttachment then
        footAttachment:Destroy()
        footAttachment = nil
    end
    if goalAttachment then
        goalAttachment:Destroy()
        goalAttachment = nil
    end
end)
