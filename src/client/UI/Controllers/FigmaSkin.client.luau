--[[ StarterPlayerScripts.FigmaSkin (LocalScript)
Restyles the code-built menu content to the Figma "Hatch an Anime – Game UI" design.
Menu panels: only colours/decoration change (no layout, no click logic): dark teal rows -> night purple studded
blocks with a white edge, bars -> ink, scroll bars -> purple. Covers Plot / Index / Quests / Shop, the egg bag
and settings. The HUD sections (4-7) go further: they swap buttons for Figma art, move / resize HUD pieces and
build two new things (GameMenus.SmallButtons row, QuestTrackerUI ScreenGui).

Table of contents (section banners below are "-- ===== N. ... =====")
  1. Services, palette, colour helpers
  2. Menu panel skin (dark rows -> night purple; light settings panel -> night purple)
  3. HUD pieces (art buttons) + the per-ScreenGui hook
  4. Backpack art (the left menu is GameMenus.LeftMenuComponent, the cash panel MoneyDisplay.CashComponent)
  5. Imported Figma art: FEEDBACK button
  6. FIGMA HUD LAYOUT: Backpack next to the hotbar (phones: row under the left menu), quest tracker
     (ReplicatedStorage.QuestsHUD component, fed here from GameMenu GetState "quests")
  7. Smoothness pass (hover / press tweens on the Backpack row)

Instance-name contracts (looked up by name; renaming them in the owning script breaks the skin silently):
  GameMenus (MenuLogic)      panels Plot / Index / Quests / VipShop; LeftMenu (the Backpack row sits under it)
  GameHUD (GameHUD)          EggBag, RightButtons > BagButton (re-parented into GameMenus.SmallButtons; its
                             non-"BACKPACK" TextLabel is renamed "Badge"), Hotbar
  MusicSettingsUI            Panel (light skin)
  FeedbackUI (FeedbackClient) FeedbackButton
  Skipped by name: CleanBase, Accent, RarityBar frames; anything under SideButtons or named / inside "Close".
Attributes: "FS" = already skinned (written + read here), "NoSkin" = opt-out on an instance or its parent,
  "Smooth" = hover tweens already attached.
Remotes: ReplicatedStorage.GameMenu.Remotes.GetState (RF, InvokeServer("quests") -> { list = { quest } } or
  { error }), Changed (RE, refreshes the tracker 0.3 s later). The tracker also polls every 8 s.
Created: GameMenus.SmallButtons (Frame), PlayerGui.QuestTrackerUI (ScreenGui: QuestsHUD), "Studs" /
  "FigmaArt" decorations.
]]

-- ===== 1. Services, palette, colour helpers =====
local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local STUDS = "rbxassetid://132561191216691"
local NIGHT, NIGHT2, INK = Color3.fromRGB(42, 31, 74), Color3.fromRGB(53, 40, 98), Color3.fromRGB(13, 10, 20)

local function luminance(color)
    return 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
end
-- the old teal/slate family: dark, and blue >= red (purple from Figma is left alone because it's already styled)
local function isOldDark(color)
    return luminance(color) < 0.42
        and color.B >= color.R
        and color.G >= color.R * 0.9
        and not (color.R > color.G and color.B > color.G)
end

-- ===== 2. Menu panel skin =====
-- isLight = called from the light (settings) skin: big frames -> NIGHT, others NIGHT2
local function decorateFrame(frame, isLight)
    if frame:GetAttribute("FS") then
        return
    end
    frame:SetAttribute("FS", true)
    local size = frame.AbsoluteSize
    local color = frame.BackgroundColor3
    if size.Y <= 30 and size.X > size.Y * 3 then -- progress tracks / thin bars
        frame.BackgroundColor3 = INK
        return
    end
    frame.BackgroundColor3 = isLight and ((size.X > 250 and size.Y > 200) and NIGHT or NIGHT2)
        or (luminance(color) < 0.16 and NIGHT or NIGHT2)
    if size.X < 50 or size.Y < 36 then
        return
    end
    if not frame:FindFirstChildOfClass("UIGradient") then
        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 90
        gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 165, 190))
        gradient.Parent = frame
    end
    if not frame:FindFirstChild("Studs") and not frame:IsA("ScrollingFrame") then
        local studs = Instance.new("ImageLabel")
        studs.Name = "Studs"
        studs.BackgroundTransparency = 1
        studs.Size = UDim2.fromScale(1, 1)
        studs.Image = STUDS
        studs.ScaleType = Enum.ScaleType.Tile
        studs.TileSize = UDim2.fromOffset(22, 22)
        studs.ImageTransparency = 0.74
        studs.ZIndex = frame.ZIndex
        studs.Active = false
        local corner = frame:FindFirstChildOfClass("UICorner")
        if corner then
            corner:Clone().Parent = studs
        end
        studs.Parent = frame
    end
    local stroke = frame:FindFirstChildOfClass("UIStroke")
    if stroke and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
        stroke.Color = Color3.new(1, 1, 1)
        stroke.Transparency = 0.2
    end
end

local function studButton(button)
    if button:GetAttribute("FS") then
        return
    end
    local size = button.AbsoluteSize
    if size.X < 40 or size.Y < 22 or button.BackgroundTransparency > 0.4 then
        return
    end
    if button:FindFirstAncestor("SideButtons") or button.Name == "Close" or button:FindFirstAncestor("Close") then
        return
    end
    button:SetAttribute("FS", true)
    if isOldDark(button.BackgroundColor3) then
        button.BackgroundColor3 = NIGHT2
    end
    if not button:FindFirstChild("Studs") then
        local studs = Instance.new("ImageLabel")
        studs.Name = "Studs"
        studs.BackgroundTransparency = 1
        studs.Size = UDim2.fromScale(1, 1)
        studs.Image = STUDS
        studs.ScaleType = Enum.ScaleType.Tile
        studs.TileSize = UDim2.fromOffset(20, 20)
        studs.ImageTransparency = 0.55
        studs.ZIndex = button.ZIndex
        studs.Active = false
        local corner = button:FindFirstChildOfClass("UICorner")
        if corner then
            corner:Clone().Parent = studs
        end
        studs.Parent = button
    end
    if not button:FindFirstChildOfClass("UIGradient") then
        local gradient = Instance.new("UIGradient")
        gradient.Rotation = 90
        gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(185, 185, 185))
        gradient.Parent = button
    end
    local hasBorder = false
    for _, stroke in button:GetChildren() do
        if stroke:IsA("UIStroke") and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
            hasBorder = true
            stroke.Color = Color3.new(0, 0, 0)
            stroke.Thickness = math.max(stroke.Thickness, 3)
        end
    end
    if not hasBorder then
        local stroke = Instance.new("UIStroke")
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Thickness = 3
        stroke.LineJoinMode = Enum.LineJoinMode.Miter
        stroke.Parent = button
    end
end

local function skinMenuDescendant(descendant)
    if descendant:GetAttribute("NoSkin") or (descendant.Parent and descendant.Parent:GetAttribute("NoSkin")) then
        return
    end
    if descendant:IsA("TextButton") or descendant:IsA("ImageButton") then
        task.defer(function()
            if descendant.Parent then
                studButton(descendant)
            end
        end)
        return
    end
    if
        descendant:IsA("TextLabel")
        and descendant.BackgroundTransparency < 0.5
        and isOldDark(descendant.BackgroundColor3)
    then
        descendant.BackgroundColor3 = NIGHT2
    end
    if descendant:IsA("ScrollingFrame") then
        descendant.ScrollBarImageColor3 = Color3.fromRGB(168, 102, 255)
    end
    if
        (descendant:IsA("Frame") or descendant:IsA("ScrollingFrame"))
        and descendant.BackgroundTransparency < 0.5
        and descendant.Name ~= "CleanBase"
        and descendant.Name ~= "Accent"
        and descendant.Name ~= "RarityBar"
    then
        if isOldDark(descendant.BackgroundColor3) then
            task.defer(function()
                if descendant.Parent then
                    decorateFrame(descendant)
                end
            end)
        end
    end
end
-- Settings panel is the old cream style: light fills -> night purple, dark text -> white with outline
local function skinLightDescendant(descendant)
    if descendant:GetAttribute("NoSkin") or (descendant.Parent and descendant.Parent:GetAttribute("NoSkin")) then
        return
    end
    if
        descendant:IsA("GuiObject")
        and not descendant:IsA("ImageLabel")
        and descendant.BackgroundTransparency < 0.5
        and luminance(descendant.BackgroundColor3) > 0.7
        and (function(color)
            return math.max(color.R, color.G, color.B) - math.min(color.R, color.G, color.B) < 0.3
        end)(descendant.BackgroundColor3)
        and not (descendant:IsA("TextButton") and descendant.Text == "X")
    then
        if descendant:IsA("Frame") then
            task.defer(function()
                if descendant.Parent then
                    decorateFrame(descendant, true)
                end
            end)
        else
            descendant.BackgroundColor3 = NIGHT2
        end
    end
    if
        (descendant:IsA("TextLabel") or descendant:IsA("TextButton"))
        and luminance(descendant.TextColor3) < 0.4
        and not (descendant:IsA("TextButton") and descendant.Text == "X")
    then
        local isMuted = descendant.TextSize > 0 and descendant.TextSize < 15
        descendant.TextColor3 = isMuted and Color3.fromRGB(195, 180, 230) or Color3.new(1, 1, 1)
        if not isMuted and not descendant:FindFirstChildOfClass("UIStroke") then
            local stroke = Instance.new("UIStroke")
            stroke.Thickness = 1.6
            stroke.Color = INK
            stroke.Parent = descendant
        end
    end
end
local function watchLightPanel(panel)
    for _, descendant in panel:GetDescendants() do
        skinLightDescendant(descendant)
    end
    panel.DescendantAdded:Connect(skinLightDescendant)
end
local function watchPanel(panel)
    for _, descendant in panel:GetDescendants() do
        skinMenuDescendant(descendant)
    end
    panel.DescendantAdded:Connect(skinMenuDescendant)
end
-- ===== 3. HUD pieces (figma buttons) =====
local BTN_ART = {
    bag = "rbxthumb://type=Asset&id=134923907419001&w=420&h=420",
    gear = "rbxthumb://type=Asset&id=106364506867782&w=420&h=420",
}
-- swap a code-drawn button for the figma art, keeping the button (clicks) and named extras (badge)
local function applyFigmaArt(button, art, keepNames)
    if button:GetAttribute("FS") then
        return
    end
    button:SetAttribute("FS", true)
    for _, child in button:GetChildren() do
        if child:IsA("GuiObject") and not (keepNames and keepNames[child.Name]) then
            child.Visible = false
        elseif child:IsA("UIStroke") then
            child.Enabled = false
        end
    end
    button.BackgroundTransparency = 1
    local artImage = Instance.new("ImageLabel")
    artImage.Name = "FigmaArt"
    artImage.BackgroundTransparency = 1
    artImage.Image = art
    artImage.Size = UDim2.fromScale(1, 1)
    artImage.ScaleType = Enum.ScaleType.Fit
    artImage.ResampleMode = Enum.ResamplerMode.Default
    artImage.ZIndex = button.ZIndex
    artImage.Active = false
    artImage.Parent = button
    for name in keepNames or {} do
        local kept = button:FindFirstChild(name)
        if kept and kept:IsA("GuiObject") then
            kept.ZIndex = button.ZIndex + 2
        end
    end
end
local function _skinBag(gui)
    local rightButtons = gui:WaitForChild("RightButtons", 15)
    local bag = rightButtons and rightButtons:WaitForChild("BagButton", 15)
    if not bag then
        return
    end
    bag.Size = UDim2.fromOffset(74, 77)
    local badge
    for _, child in bag:GetChildren() do
        if child:IsA("TextLabel") and child.Text ~= "BACKPACK" then
            badge = child
        end
    end
    if badge then
        badge.Name = "Badge"
    end
    applyFigmaArt(bag, BTN_ART.bag, { Badge = true })
end
local function _skinGear(gui)
    for _, hold in gui:GetChildren() do
        if hold:IsA("Frame") and hold.Name ~= "Panel" then
            local face = hold:FindFirstChildWhichIsA("TextButton")
            if not face then
                continue
            end
            hold.Size = UDim2.fromOffset(74, 77)
            for _, child in hold:GetChildren() do
                if child ~= face and child:IsA("GuiObject") then
                    child.Visible = false
                end
            end
            face.Size = UDim2.fromScale(1, 1)
            applyFigmaArt(face, BTN_ART.gear)
        end
    end
end

-- runs once per PlayerGui child (task.spawn: the WaitForChild calls below yield)
local function skinScreenGui(gui)
    -- bag now lives in the left grid
    -- gear now lives in the left grid
    if gui.Name == "GameMenus" then
        for _, panelName in { "Plot", "Index", "Quests", "VipShop" } do
            local panel = gui:WaitForChild(panelName, 10)
            if panel then
                watchPanel(panel)
            end
        end
    elseif gui.Name == "GameHUD" then
        local bag = gui:WaitForChild("EggBag", 10)
        if bag then
            watchPanel(bag)
        end
    elseif gui.Name == "MusicSettingsUI" then
        local panel = gui:WaitForChild("Panel", 10)
        if panel then
            watchPanel(panel)
            watchLightPanel(panel)
        end
    end
end
for _, gui in playerGui:GetChildren() do
    task.spawn(skinScreenGui, gui)
end
playerGui.ChildAdded:Connect(function(gui)
    task.spawn(skinScreenGui, gui)
end)

-- ===== 4. Backpack art (the left menu itself is GameMenus.LeftMenuComponent) =====
local MENU_ART = {
    BagButton = "rbxassetid://122727444829967",
}
local function setFigmaArt(button, art, keepNames)
    button:SetAttribute("FS", nil)
    local oldArt = button:FindFirstChild("FigmaArt")
    if oldArt then
        oldArt:Destroy()
    end
    applyFigmaArt(button, art, keepNames)
end

-- ===== 5. Imported figma art: FEEDBACK button (live text stays on top) =====
local IMPORTED_ART = {
    feedback = "rbxassetid://71511803471484",
}
task.spawn(function()
    local feedbackGui = playerGui:WaitForChild("FeedbackUI")
    local feedbackButton = feedbackGui:WaitForChild("FeedbackButton", 30)
    if not feedbackButton then
        return
    end
    for _, child in feedbackButton:GetChildren() do
        if child:IsA("GuiObject") then
            child.Visible = false
        end
    end
    feedbackButton.BackgroundTransparency = 1
    for _, child in feedbackButton:GetDescendants() do
        if child:IsA("UIStroke") then
            child.Enabled = false
        end
    end
    local _face = feedbackButton:IsA("GuiButton") and feedbackButton
        or feedbackButton:FindFirstChildWhichIsA("GuiButton", true)
    local artImage = Instance.new("ImageLabel")
    artImage.Name = "FigmaArt"
    artImage.BackgroundTransparency = 1
    artImage.Image = IMPORTED_ART.feedback
    artImage.Size = UDim2.fromScale(1, 1)
    artImage.ScaleType = Enum.ScaleType.Fit
    artImage.ZIndex = feedbackButton.ZIndex + 5
    artImage.Active = false
    artImage.Parent = feedbackButton
end)
-- ===== 6. FIGMA HUD LAYOUT =====
-- money bottom-left (MoneyLogic), time HUD top-centre (GameHUD), left menu (MenuLogic), Backpack left of the hotbar
-- (phones: under the left menu), quest tracker on the right
-- MoneyLogic owns cash positioning so the skin cannot fight safe-area layout.
-- phones: small Backpack row under the left menu (GameMenus.LeftMenu); desktop: the Backpack button sits next to
-- the hotbar
task.spawn(function()
    local gameMenus = playerGui:WaitForChild("GameMenus")
    local leftMenu = gameMenus:WaitForChild("LeftMenu")
    local row = Instance.new("Frame")
    row.Name = "SmallButtons"
    row.BackgroundTransparency = 1
    row.Size = UDim2.fromOffset(140, 65)
    row.Parent = gameMenus
    local rowLayout = Instance.new("UIListLayout")
    rowLayout.FillDirection = Enum.FillDirection.Horizontal
    rowLayout.Padding = UDim.new(0, 10)
    rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
    rowLayout.Parent = row
    local rowScale = Instance.new("UIScale")
    rowScale.Name = "ResponsiveScale"
    rowScale.Parent = row
    local gameHud = playerGui:WaitForChild("GameHUD")
    -- Desktop only: the Backpack button sits in its own slot just left of the hotbar (bottoms lined up with
    -- the hotbar slots; the hotbar has 8 px bottom padding and grows with the item count). On phones it stays
    -- in the row under the grid, because the bottom of the screen belongs to the thumbstick / hotbar.
    local bagSlot = Instance.new("Frame")
    bagSlot.Name = "HotbarBagSlot"
    bagSlot.BackgroundTransparency = 1
    bagSlot.Size = UDim2.fromOffset(62, 65)
    bagSlot.Parent = gameMenus
    local bag -- GameHUD.RightButtons.BagButton once it has been found (below)
    local function placeRow()
        local compact = math.min(gameMenus.AbsoluteSize.X, gameMenus.AbsoluteSize.Y) < 600
        local sidePosition, sideSize = leftMenu.AbsolutePosition, leftMenu.AbsoluteSize
        local hotbar = gameHud:FindFirstChild("Hotbar")
        local bagNextToHotbar = not compact and hotbar ~= nil
        if bag then
            local wantedParent = bagNextToHotbar and bagSlot or row
            if bag.Parent ~= wantedParent then
                bag.Parent = wantedParent
            end
        end
        if bagNextToHotbar then
            local hotbarPosition, hotbarSize = hotbar.AbsolutePosition, hotbar.AbsoluteSize
            bagSlot.Position = UDim2.fromOffset(
                hotbarPosition.X - gameMenus.AbsolutePosition.X - 62 - 12,
                hotbarPosition.Y - gameMenus.AbsolutePosition.Y + hotbarSize.Y - 8 - 65
            )
            if bag then
                bag.Size = UDim2.fromOffset(62, 65)
            end
        end
        -- the row (Backpack on phones) stays under the left menu
        row.Position = UDim2.fromOffset(
            sidePosition.X - gameMenus.AbsolutePosition.X,
            sidePosition.Y - gameMenus.AbsolutePosition.Y + sideSize.Y + (compact and 6 or 10)
        )
        row.Size = compact and UDim2.fromOffset(190, 92) or UDim2.fromOffset(140, 65)
        rowScale.Scale = compact and sideSize.X / 190 or 1
        rowLayout.Padding = UDim.new(0, compact and 6 or 10)
        for _, child in row:GetChildren() do
            if child:IsA("GuiObject") then
                child.Size = compact and UDim2.fromOffset(92, 92) or UDim2.fromOffset(62, 65)
                local phone = child:FindFirstChild("PhoneScale")
                if phone then
                    phone.Scale = 1
                end
            end
        end
    end
    row.ChildAdded:Connect(function()
        task.defer(placeRow)
    end)
    gameMenus:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeRow)
    leftMenu:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeRow)
    leftMenu:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeRow)
    placeRow()
    task.spawn(function()
        local hotbar = gameHud:WaitForChild("Hotbar", 30)
        if hotbar then
            hotbar:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeRow)
            hotbar:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeRow)
            placeRow()
        end
    end)
    local bagButton = playerGui:WaitForChild("GameHUD"):WaitForChild("RightButtons"):WaitForChild("BagButton", 15)
    if bagButton then
        bagButton.Parent = row
        bagButton.LayoutOrder = 1
        bagButton.Size = UDim2.fromOffset(62, 65)
        setFigmaArt(bagButton, MENU_ART.BagButton, { Badge = true })
        for _, child in bagButton:GetChildren() do
            if child:IsA("TextLabel") and child.Text ~= "BACKPACK" then
                child.Name = "Badge"
                child.ZIndex = 30
                child.Visible = child.Visible
            end
        end
        bagButton.ZIndex = 20
        bag = bagButton
        placeRow() -- desktop: move it next to the hotbar
    end
end)
-- right side: live quest tracker (ReplicatedStorage.QuestsHUD; the Daily button is in the left menu)
task.spawn(function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local QuestsHUD = ReplicatedStorage:WaitForChild("QuestsHUD")
    local QuestsConfig = require(QuestsHUD:WaitForChild("QuestsConfig"))
    local tracker = require(QuestsHUD:WaitForChild("QuestsComponent")).new(nil)
    local gui = Instance.new("ScreenGui")
    gui.Name = "QuestTrackerUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 40
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- QuestsComponent orders its layers per sibling
    tracker.Root.Parent = gui
    gui.Parent = playerGui
    local remotes = ReplicatedStorage:WaitForChild("GameMenu"):WaitForChild("Remotes")
    local getStateRemote, changedRemote = remotes:WaitForChild("GetState"), remotes:WaitForChild("Changed")
    -- refreshes requested while a fetch is in flight are dropped (the 8 s poll catches up)
    local isFetching = false
    local function refreshQuests()
        if isFetching then
            return
        end
        isFetching = true
        local ok, data = pcall(function()
            return getStateRemote:InvokeServer("quests")
        end)
        isFetching = false
        if not ok or type(data) ~= "table" or data.error then
            return
        end
        -- the open (unclaimed) quests closest to done; progress and targets come from the server
        local openQuests = {}
        for _, quest in data.list or {} do
            if not quest.claimed then
                table.insert(openQuests, {
                    id = quest.id,
                    title = quest.title,
                    progress = math.min(quest.progress, quest.target),
                    target = quest.target,
                })
            end
        end
        table.sort(openQuests, function(a, b)
            return (a.progress / math.max(a.target, 1)) > (b.progress / math.max(b.target, 1))
        end)
        tracker:SetQuests(openQuests)
    end
    changedRemote.OnClientEvent:Connect(function()
        task.delay(0.3, refreshQuests)
    end)
    task.spawn(function()
        while gui.Parent do
            refreshQuests()
            task.wait(8)
        end
    end)
    -- desktop: right edge, top where the old panel's top was; phones (landscape only): top-right, smaller.
    -- Anchored at the top so collapsing never moves the header.
    local function layoutTracker()
        local viewport = gui.AbsoluteSize
        local compact = math.min(viewport.X, viewport.Y) < QuestsConfig.CompactBreakpoint
        local landscape = viewport.X >= viewport.Y
        tracker:SetVisible(not compact or (landscape and viewport.X >= 600))
        local layout = compact and QuestsConfig.Compact or QuestsConfig.Desktop
        tracker.Scale.Scale = layout.Width / (QuestsConfig.Width * QuestsConfig.Unit)
        tracker.Root.AnchorPoint = Vector2.new(1, 0)
        tracker.Root.Position = compact and UDim2.new(1, -layout.Margin, 0, layout.Top)
            or UDim2.new(1, -layout.Margin, 0.5, layout.TopFromCentre)
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTracker)
    layoutTracker()
end)

-- ===== 7. Smoothness pass (hover / press on the small Backpack row) =====
task.spawn(function()
    local TweenService = game:GetService("TweenService")
    local gameMenus = playerGui:WaitForChild("GameMenus")
    local function addSmoothHover(button)
        if not button:IsA("GuiButton") or button:GetAttribute("Smooth") then
            return
        end
        button:SetAttribute("Smooth", true)
        local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", button)
        local fastTween = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        button.MouseEnter:Connect(function()
            TweenService:Create(scale, fastTween, { Scale = 1.06 }):Play()
        end)
        button.MouseLeave:Connect(function()
            TweenService:Create(scale, fastTween, { Scale = 1 }):Play()
        end)
        button.MouseButton1Down:Connect(function()
            TweenService:Create(scale, TweenInfo.new(0.07), { Scale = 0.93 }):Play()
        end)
        button.MouseButton1Up:Connect(function()
            TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1.06 }):Play()
        end)
    end
    task.wait(3)
    local row = gameMenus:FindFirstChild("SmallButtons")
    if row then
        for _, descendant in row:GetDescendants() do
            addSmoothHover(descendant)
        end
    end
end)
