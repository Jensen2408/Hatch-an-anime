--[[ StarterPlayerScripts.FigmaSkin (LocalScript)
Restyles the code-built menu content to the Figma "Hatch an Anime – Game UI" design.
Menu panels: only colours/decoration change (no layout, no click logic): dark teal rows -> night purple studded
blocks with a white edge, bars -> ink, scroll bars -> purple. Covers Plot / Index / Quests / Shop, the egg bag
and settings. The HUD sections (4-7) go further: they swap buttons for Figma art, move / resize HUD pieces and
build two new things (GameMenus.SmallButtons row, QuestTrackerUI ScreenGui).

Table of contents (section banners below are "-- ===== N. ... =====")
  1. Services, palette, colour helpers
  2. Menu panel skin (dark rows -> night purple; light settings panel -> night purple)
  3. HUD pieces (art buttons, money pill, night banner) + the per-ScreenGui hook
  4. Left menu grid: Figma art for Plot / Index / Quests / Shop buttons
  5. Imported Figma art: HOME bar, FEEDBACK button, money panel
  6. FIGMA HUD LAYOUT: night banner top-centre, Settings row under the grid (Backpack left of the hotbar on desktop), quest tracker + daily button
  7. Size + smoothness pass (grid cell size, hover/press tweens)

Instance-name contracts (looked up by name; renaming them in the owning script breaks the skin silently):
  GameMenus (MenuLogic)      panels Plot / Index / Quests / VipShop; SideButtons > UIGridLayout, PlotButton,
                             IndexButton, QuestsButton, VipShopButton (child "Outer" hidden); OpenMenu (Bindable,
                             fired with "VipShop" by the daily button)
  GameHUD (GameHUD)          EggBag, RightButtons > BagButton (re-parented into GameMenus.SmallButtons; its
                             non-"BACKPACK" TextLabel is renamed "Badge"), HomeButton > Shadow, Button
  MusicSettingsUI            Panel (light skin); the gear holder Frame (re-parented into SmallButtons)
  MoneyDisplay (MoneyLogic)  Money (ImageLabel) > Amount, CoinBox, Face > Amount, Income, Shine, IncomeGlow
  NightBar (GameHUD)         its last Frame child is the banner
  FeedbackUI (FeedbackClient) FeedbackButton
  Skipped by name: CleanBase, Accent, RarityBar frames; anything under SideButtons or named / inside "Close".
Attributes: "FS" = already skinned (written + read here), "NoSkin" = opt-out on an instance or its parent,
  "Smooth" = hover tweens already attached. Workspace "NighttimeActive" sizes the night banner.
Remotes: ReplicatedStorage.GameMenu.Remotes.GetState (RF, InvokeServer("quests") -> { list = { quest } } or
  { error }), Changed (RE, refreshes the tracker 0.3 s later). The tracker also polls every 8 s.
Created: GameMenus.SmallButtons (Frame), PlayerGui.QuestTrackerUI (ScreenGui: Quests, Daily), "Studs" /
  "FigmaArt" / "FigmaPill" / "FigmaShadow" decorations.
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
-- ===== 3. HUD pieces (figma buttons, currency pill, night banner) =====
local BTN_ART = {
    bag = "rbxthumb://type=Asset&id=134923907419001&w=420&h=420",
    gear = "rbxthumb://type=Asset&id=106364506867782&w=420&h=420",
}
local function addStudsImage(parent, tileSize, transparency, zIndex)
    local studs = Instance.new("ImageLabel")
    studs.Name = "Studs"
    studs.BackgroundTransparency = 1
    studs.Size = UDim2.fromScale(1, 1)
    studs.Image = STUDS
    studs.ScaleType = Enum.ScaleType.Tile
    studs.TileSize = UDim2.fromOffset(tileSize, tileSize)
    studs.ImageTransparency = transparency
    studs.ZIndex = zIndex or parent.ZIndex
    local corner = parent:FindFirstChildOfClass("UICorner")
    if corner then
        corner:Clone().Parent = studs
    end
    studs.Parent = parent
    return studs
end
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
-- purple pill behind the cash amount (section 5 later hides FigmaPill / FigmaShadow and uses Figma art instead)
local function skinMoney(gui)
    local money = gui:WaitForChild("Money", 15)
    if not money or money:GetAttribute("FS") then
        return
    end
    money:SetAttribute("FS", true)
    money.ImageTransparency = 1
    local pill = Instance.new("Frame")
    pill.Name = "FigmaPill"
    pill.ZIndex = 0
    pill.Position = UDim2.fromScale(0.13, 0.22)
    pill.Size = UDim2.fromScale(0.84, 0.56)
    pill.BackgroundColor3 = Color3.new(1, 1, 1)
    pill.BorderSizePixel = 0
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new(Color3.fromRGB(47, 35, 87), Color3.fromRGB(20, 13, 43))
    gradient.Parent = pill
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = pill
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.new(1, 1, 1)
    stroke.Thickness = 4
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = pill
    pill.Parent = money
    addStudsImage(pill, 22, 0.6, 0)
    local shadow = Instance.new("Frame")
    shadow.Name = "FigmaShadow"
    shadow.ZIndex = -1
    shadow.BorderSizePixel = 0
    shadow.BackgroundColor3 = Color3.new(0, 0, 0)
    shadow.Position = pill.Position + UDim2.fromOffset(0, 6)
    shadow.Size = pill.Size
    local shadowCorner = corner:Clone()
    shadowCorner.Parent = shadow
    shadow.Parent = money
    local amount = money:FindFirstChild("Amount", true)
    if amount then
        amount.TextColor3 = Color3.fromRGB(125, 255, 107)
    end
end
local function skinNight(gui)
    local banner
    for _, child in gui:GetChildren() do
        if child:IsA("Frame") then
            banner = child
        end
    end
    if not banner or banner:GetAttribute("FS") then
        return
    end
    banner:SetAttribute("FS", true)
    banner.BackgroundColor3 = Color3.new(1, 1, 1)
    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new(Color3.fromRGB(168, 102, 255), Color3.fromRGB(74, 21, 166))
    gradient.Parent = banner
    for _, stroke in banner:GetChildren() do
        if stroke:IsA("UIStroke") then
            stroke.Color = Color3.new(1, 1, 1)
            stroke.Thickness = 4
        end
    end
    local corner = banner:FindFirstChildOfClass("UICorner")
    if corner then
        corner.CornerRadius = UDim.new(0, 12)
    end
    -- figma night banner art behind the live text
    banner.BackgroundTransparency = 1
    gradient:Destroy()
    for _, stroke in banner:GetChildren() do
        if stroke:IsA("UIStroke") then
            stroke.Enabled = false
        end
    end
    local function pinSize()
        local compact = math.min(gui.AbsoluteSize.X, gui.AbsoluteSize.Y) < 600
        local night = workspace:GetAttribute("NighttimeActive") == true
        local wantedSize = UDim2.fromOffset(290, compact and 52 or (night and 124 or 90))
        if banner.Size ~= wantedSize then
            banner.Size = wantedSize
        end
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(pinSize)
    workspace:GetAttributeChangedSignal("NighttimeActive"):Connect(pinSize)
    pinSize()
    banner:GetPropertyChangedSignal("Size"):Connect(pinSize)
    local art = Instance.new("ImageLabel")
    art.Name = "FigmaArt"
    art.BackgroundTransparency = 1
    art.Image = "rbxassetid://130685995376691"
    art.Size = UDim2.fromScale(1, 1)
    art.ScaleType = Enum.ScaleType.Stretch
    art.ZIndex = banner.ZIndex
    art.Parent = banner
    for _, label in banner:GetChildren() do
        if label:IsA("TextLabel") then
            label.ZIndex = banner.ZIndex + 1
            if not label:FindFirstChildOfClass("UIStroke") then
                local labelStroke = Instance.new("UIStroke")
                labelStroke.Thickness = 2.2
                labelStroke.Color = INK
                labelStroke.Parent = label
            end
        end
    end
end

-- runs once per PlayerGui child (task.spawn: the WaitForChild calls below yield)
local function skinScreenGui(gui)
    if gui.Name == "MoneyDisplay" then
        task.spawn(skinMoney, gui)
    end
    if gui.Name == "NightBar" then
        task.defer(skinNight, gui)
    end
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

-- ===== 4. Left menu: all 6 figma buttons (Plot, Index, Quest, Shop, Backpack, Settings) in one compact grid =====
local function _thumb(assetId)
    return "rbxthumb://type=Asset&id=" .. assetId .. "&w=420&h=420"
end
local MENU_ART = {
    PlotButton = "rbxassetid://108526178271956",
    IndexButton = "rbxassetid://136158818877449",
    QuestsButton = "rbxassetid://137388884677460",
    VipShopButton = "rbxassetid://90922644817150",
    BagButton = "rbxassetid://122727444829967",
    Settings = "rbxassetid://101549876931377",
}
local function setFigmaArt(button, art, keepNames)
    button:SetAttribute("FS", nil)
    local oldArt = button:FindFirstChild("FigmaArt")
    if oldArt then
        oldArt:Destroy()
    end
    applyFigmaArt(button, art, keepNames)
end
task.spawn(function()
    local gameMenus = playerGui:WaitForChild("GameMenus")
    local sideButtons = gameMenus:WaitForChild("SideButtons")
    local gridLayout = sideButtons:WaitForChild("UIGridLayout")
    for _, buttonName in { "PlotButton", "IndexButton", "QuestsButton", "VipShopButton" } do
        local button = sideButtons:WaitForChild(buttonName, 10)
        if button then
            local outer = button:FindFirstChild("Outer")
            if outer then
                outer.Visible = false
            end
            setFigmaArt(button, MENU_ART[buttonName])
        end
    end
    local layoutOrders = { PlotButton = 1, IndexButton = 2, QuestsButton = 3, VipShopButton = 4 }
    for buttonName, layoutOrder in layoutOrders do
        local button = sideButtons:FindFirstChild(buttonName)
        if button then
            button.LayoutOrder = layoutOrder
        end
    end
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    -- backpack (GameHUD) and settings gear (MusicSettingsUI) move into the same grid
    -- bag/gear: see FIGMA HUD LAYOUT
end)

-- ===== 5. Imported figma art: HOME bar, FEEDBACK button, money panel (live text stays on top) =====
local IMPORTED_ART = {
    home = "rbxassetid://131819403885000",
    feedback = "rbxassetid://71511803471484",
    money = "rbxassetid://83828471664405",
}
task.spawn(function()
    local hud = playerGui:WaitForChild("GameHUD")
    local holder = hud:WaitForChild("HomeButton", 30)
    if not holder then
        return
    end
    local shadow = holder:FindFirstChild("Shadow")
    if shadow then
        shadow.Visible = false
    end
    local homeButton = holder:WaitForChild("Button")
    homeButton.Size = UDim2.fromScale(1, 1)
    applyFigmaArt(homeButton, IMPORTED_ART.home)
end)
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
task.spawn(function()
    local moneyDisplay = playerGui:WaitForChild("MoneyDisplay")
    local money = moneyDisplay:WaitForChild("Money", 30)
    if not money then
        return
    end
    task.wait(0.5) -- gives skinMoney (section 3) time to build its pill, which is hidden right below
    for _, childName in { "FigmaPill", "FigmaShadow", "CoinBox" } do
        local child = money:FindFirstChild(childName)
        if child then
            child.Visible = false
        end
    end
    money.Image = IMPORTED_ART.money
    money.ImageTransparency = 0
    money.ScaleType = Enum.ScaleType.Fit
    money.Size = UDim2.fromOffset(320, 112) -- (position: see FIGMA HUD LAYOUT)
    local face = money:FindFirstChild("Face")
    if face then
        face.Position = UDim2.fromScale(0.2, 0.04)
        face.Size = UDim2.fromScale(0.76, 0.84)
        for _, childName in { "Shine", "IncomeGlow" } do
            local child = face:FindFirstChild(childName)
            if child then
                child.Visible = false
            end
        end
        local amount = face:FindFirstChild("Amount")
        if amount then
            amount.Position = UDim2.fromScale(0.03, 0.02)
            amount.Size = UDim2.fromScale(0.94, 0.56)
            amount.TextColor3 = Color3.fromRGB(125, 255, 107)
        end
        local income = face:FindFirstChild("Income")
        if income then
            income.BackgroundTransparency = 1
            for _, child in income:GetChildren() do
                if child:IsA("UIStroke") or child:IsA("UIGradient") then
                    child:Destroy()
                elseif child:IsA("Frame") then
                    child.Visible = false
                end
            end
            income.AnchorPoint = Vector2.new(0.5, 0)
            income.Position = UDim2.fromScale(0.5, 0.66)
            income.Size = UDim2.fromScale(0.68, 0.3)
        end
    end
end)

-- ===== 6. FIGMA HUD LAYOUT =====
-- night top-centre, money bottom-left (MoneyLogic), Settings under the grid, Backpack left of the hotbar, quests + daily on the right
local IMG_DAILY, IMG_QUEST = "rbxassetid://77807427401832", "rbxassetid://76790067314566"
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local function createLabel(parent, text, size, color, props)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.FontFace = FONT
    label.Text = text
    label.TextSize = size
    label.TextColor3 = color or Color3.new(1, 1, 1)
    label.TextXAlignment = Enum.TextXAlignment.Left
    for key, value in props or {} do
        label[key] = value
    end
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = INK
    stroke.Parent = label
    label.Parent = parent
    return label
end
-- night banner -> top-centre (keep its own up/down animation)
task.spawn(function()
    local nightBar = playerGui:WaitForChild("NightBar")
    task.wait(1)
    local banner
    for _, child in nightBar:GetChildren() do
        if child:IsA("Frame") then
            banner = child
        end
    end
    if not banner then
        return
    end
    local function pinX()
        local compact = math.min(nightBar.AbsoluteSize.X, nightBar.AbsoluteSize.Y) < 600
        nightBar.ScreenInsets = compact and Enum.ScreenInsets.CoreUISafeInsets or Enum.ScreenInsets.None
        -- horizontally centred (the banner's AnchorPoint X is 0.5); Y keeps the banner's own up/down animation
        local wantedPosition = compact and UDim2.new(0.5, 0, 0, banner.AbsoluteSize.Y)
            or UDim2.new(0.5, 0, banner.Position.Y.Scale, banner.Position.Y.Offset)
        if banner.Position ~= wantedPosition then
            banner.Position = wantedPosition
        end
    end
    nightBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(pinX)
    banner:GetPropertyChangedSignal("AbsoluteSize"):Connect(pinX)
    pinX()
    banner:GetPropertyChangedSignal("Position"):Connect(pinX)
end)
-- MoneyLogic owns cash positioning so the skin cannot fight safe-area layout.
-- small Backpack + Settings row under the 2x2 grid; on desktop the Backpack button moves next to the hotbar
task.spawn(function()
    local gameMenus = playerGui:WaitForChild("GameMenus")
    local sideButtons = gameMenus:WaitForChild("SideButtons")
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
        local sidePosition, sideSize = sideButtons.AbsolutePosition, sideButtons.AbsoluteSize
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
        -- the row (Settings, plus Backpack on phones) stays under the 2x2 grid
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
    sideButtons:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeRow)
    sideButtons:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeRow)
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
    local musicSettings = playerGui:WaitForChild("MusicSettingsUI")
    for _, hold in musicSettings:GetChildren() do
        if hold:IsA("Frame") and hold.Name ~= "Panel" and hold:FindFirstChildWhichIsA("TextButton") then
            hold.Parent = row
            hold.LayoutOrder = 2
            hold.Size = UDim2.fromOffset(62, 65)
            local face = hold:FindFirstChildWhichIsA("TextButton")
            for _, child in hold:GetChildren() do
                if child:IsA("GuiObject") and child ~= face then
                    child.Visible = false
                end
            end
            face.Size = UDim2.fromScale(1, 1)
            face.Position = UDim2.new()
            setFigmaArt(hold:FindFirstChildWhichIsA("TextButton"), MENU_ART.Settings)
            break
        end
    end
end)
-- right side: live quest tracker + daily button
task.spawn(function()
    local gui = Instance.new("ScreenGui")
    gui.Name = "QuestTrackerUI"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 40
    gui.Parent = playerGui
    local panel = Instance.new("ImageLabel")
    panel.Name = "Quests"
    panel.BackgroundTransparency = 1
    panel.Image = IMG_QUEST
    panel.AnchorPoint = Vector2.new(1, 0.5)
    panel.Position = UDim2.new(1, -16, 0.5, -40)
    panel.Size = UDim2.fromOffset(300, 198)
    panel.Parent = gui
    Instance.new("UIScale", panel).Scale = 0.82
    createLabel(panel, "QUESTS", 26, nil, { Position = UDim2.fromOffset(16, 8), Size = UDim2.fromOffset(200, 32) })
    local BAR_COLORS = { Color3.fromRGB(67, 220, 78), Color3.fromRGB(255, 201, 63), Color3.fromRGB(59, 120, 255) }
    local rows = {}
    for i = 1, 3 do
        local rowY = 44 + (i - 1) * 48
        local nameLabel =
            createLabel(panel, "", 15, nil, { Position = UDim2.fromOffset(16, rowY), Size = UDim2.fromOffset(260, 18) })
        local track = Instance.new("Frame")
        track.BackgroundColor3 = Color3.fromRGB(13, 10, 20)
        track.BackgroundTransparency = 0
        local trackStroke = Instance.new("UIStroke")
        trackStroke.Color = Color3.fromRGB(110, 95, 160)
        trackStroke.Thickness = 1.5
        trackStroke.Parent = track
        track.BorderSizePixel = 0
        track.Position = UDim2.fromOffset(16, rowY + 21)
        track.Size = UDim2.fromOffset(196, 12)
        track.Parent = panel
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = track
        local fill = Instance.new("Frame")
        fill.BackgroundColor3 = BAR_COLORS[i]
        fill.BorderSizePixel = 0
        fill.Size = UDim2.fromScale(0, 1)
        fill.Parent = track
        corner:Clone().Parent = fill
        local valueLabel = createLabel(panel, "", 15, Color3.fromRGB(255, 227, 107), {
            Position = UDim2.fromOffset(220, rowY + 16),
            Size = UDim2.fromOffset(66, 20),
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        rows[i] = { name = nameLabel, fill = fill, val = valueLabel }
    end
    local function formatShort(amount)
        for _, unit in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
            if amount >= unit[1] then
                return string.format("%g", math.floor(amount / unit[1] * 10) / 10) .. unit[2]
            end
        end
        return tostring(math.floor(amount))
    end
    local remotes = game:GetService("ReplicatedStorage"):WaitForChild("GameMenu"):WaitForChild("Remotes")
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
        local openQuests = {}
        for _, quest in data.list or {} do
            if not quest.claimed then
                table.insert(openQuests, quest)
            end
        end
        table.sort(openQuests, function(a, b)
            return (a.progress / math.max(a.target, 1)) > (b.progress / math.max(b.target, 1))
        end)
        for i, row in rows do
            local quest = openQuests[i]
            row.name.Text = quest and quest.title or ""
            row.val.Text = quest
                    and (formatShort(math.min(quest.progress, quest.target)) .. "/" .. formatShort(quest.target))
                or ""
            row.fill.Size =
                UDim2.fromScale(quest and math.clamp(quest.progress / math.max(quest.target, 1), 0, 1) or 0, 1)
            row.fill.Parent.Visible = quest ~= nil
        end
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
    -- daily button -> opens the shop (daily rewards live there)
    local dailyButton = Instance.new("ImageButton")
    dailyButton.Name = "Daily"
    dailyButton.BackgroundTransparency = 1
    dailyButton.Image = IMG_DAILY
    dailyButton.AnchorPoint = Vector2.new(1, 0)
    dailyButton.Position = UDim2.new(1, -16, 0.5, 50)
    dailyButton.Size = UDim2.fromOffset(90, 94)
    dailyButton.Parent = gui
    local dailyScale = Instance.new("UIScale")
    dailyScale.Parent = dailyButton
    local function layoutTracker()
        local viewport = gui.AbsoluteSize
        local compact = math.min(viewport.X, viewport.Y) < 600
        local landscape = viewport.X >= viewport.Y
        panel.Visible = not compact or (landscape and viewport.X >= 600)
        panel.AnchorPoint = compact and Vector2.new(1, 0) or Vector2.new(1, 0.5)
        panel.Position = compact and UDim2.new(1, -10, 0, 62) or UDim2.new(1, -16, 0.5, -40)
        panel:FindFirstChildOfClass("UIScale").Scale = compact and 0.55 or 0.82
        dailyButton.Size = compact and UDim2.fromOffset(48, 50) or UDim2.fromOffset(90, 94)
        dailyButton.Position = compact and UDim2.new(1, -118, 0, landscape and 6 or 146) or UDim2.new(1, -16, 0.5, 50)
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTracker)
    layoutTracker()
    local TweenService = game:GetService("TweenService")
    dailyButton.MouseEnter:Connect(function()
        TweenService:Create(dailyScale, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
    end)
    dailyButton.MouseLeave:Connect(function()
        TweenService:Create(dailyScale, TweenInfo.new(0.12), { Scale = 1 }):Play()
    end)
    dailyButton.Activated:Connect(function()
        local openMenu = playerGui.GameMenus:FindFirstChild("OpenMenu")
        if openMenu then
            openMenu:Fire("VipShop")
        end
    end)
end)

-- ===== 7. Size + smoothness pass =====
task.spawn(function()
    local TweenService = game:GetService("TweenService")
    local gameMenus = playerGui:WaitForChild("GameMenus")
    local sideButtons = gameMenus:WaitForChild("SideButtons")
    local gridLayout = sideButtons:WaitForChild("UIGridLayout")
    gridLayout.CellSize = UDim2.fromOffset(92, 92)
    gridLayout.CellPadding = UDim2.fromOffset(6, 6)
    sideButtons.Size = UDim2.fromOffset(190, 190)
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
    local homeButton = playerGui:FindFirstChild("GameHUD") and playerGui.GameHUD:FindFirstChild("HomeButton")
    if homeButton then
        for _, descendant in homeButton:GetDescendants() do
            addSmoothHover(descendant)
        end
    end
end)
