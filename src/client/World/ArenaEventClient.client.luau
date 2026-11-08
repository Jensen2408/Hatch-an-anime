--[[ StarterPlayerScripts.ArenaEventClient  (LocalScript)
Client side of the Arena Brawl PvP event (ServerScriptService.ArenaEventService).
  * PORTAL: while the lobby is open the server publishes where THIS player's portal stands (Player attribute
    ArenaPortalCFrame, outside their own plot). This script builds it locally (client-created parts are never replicated,
    so nobody else sees it) and fires ArenaEvent.Join when the character walks into it. The server re-checks the
    player is really at their portal, then teleports them onto the platform. The portal fades away once they have joined,
    when the lobby closes, or if they are locked out (knocked out earlier this round).
  * PODIUM LOADOUT UI: when the player enters their portal into the Arena Brawl, a Podium Character Loadout modal opens
    allowing them to equip up to 3 characters from their plot podiums. Each character grants character-specific battle
    attributes (Knockback, Swing Speed, Bat Reach, Move Speed, Stability, Recovery).
  * HUD: a minute before a scheduled brawl "ARENA BRAWL IN 0:48"; then lobby, countdown, fight (fighters left, your
    knockouts, next ring drop) and the winner banner; toasts for Fx events: Notice, Knockout, Out, Result, LoadoutState.
Reads workspace attributes ArenaPhase / ArenaEndsAt / ArenaRegistered / ArenaFighters / ArenaTotal / ArenaShrinkAt /
ArenaWinner / ArenaNextAt and Player attributes ArenaPortalCFrame / ArenaIn / ArenaKOs / ArenaLocked. Nothing here is
trusted by the server.
]]
-- ===== 1. Services, modules =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("ArenaEvent")
local Config = require(folder:WaitForChild("ArenaConfig"))
local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local joinEvent = folder:WaitForChild("Join")
local equipEvent = folder:WaitForChild("EquipLoadout")
local fxEvent = folder:WaitForChild("Fx")
local UISound = ReplicatedStorage:FindFirstChild("UISound") and require(ReplicatedStorage.UISound)

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local FONT_BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local THEME = {
    lacquer = Color3.fromRGB(98, 70, 56),
    lacquerDark = Color3.fromRGB(62, 44, 35),
    lacquerDeep = Color3.fromRGB(44, 30, 24),
    post = Color3.fromRGB(74, 54, 44),
    card = Color3.fromRGB(84, 59, 47),
    cardEquipped = Color3.fromRGB(112, 82, 54),
    well = Color3.fromRGB(52, 36, 28),
    cream = Color3.fromRGB(244, 231, 204),
    muted = Color3.fromRGB(212, 188, 148),
    gold = Color3.fromRGB(224, 184, 96),
    goldBright = Color3.fromRGB(255, 224, 130),
    green = Color3.fromRGB(82, 196, 118),
    greenDark = Color3.fromRGB(42, 118, 66),
    red = Color3.fromRGB(214, 84, 72),
}

local RARITY_COLORS = {
    Common = Color3.fromRGB(215, 222, 235),
    Uncommon = Color3.fromRGB(108, 228, 146),
    Rare = Color3.fromRGB(98, 184, 255),
    Epic = Color3.fromRGB(204, 132, 255),
    Legendary = Color3.fromRGB(255, 204, 84),
    Mythic = Color3.fromRGB(255, 96, 172),
    Cosmic = Color3.fromRGB(104, 240, 218),
    Limited = Color3.fromRGB(255, 88, 112),
}

local MUTATION_COLORS = {
    Silver = Color3.fromRGB(210, 225, 245),
    Gold = Color3.fromRGB(255, 212, 84),
    Diamond = Color3.fromRGB(116, 232, 255),
    Rainbow = Color3.fromRGB(255, 148, 228),
}

local function playClick()
    if UISound and UISound.Play then
        pcall(UISound.Play, "Click")
    end
end

local function formatTime(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return string.format("%d:%02d", seconds // 60, seconds % 60)
end
local function formatCash(amount)
    local text = tostring(math.floor(amount))
    while true do
        local replaced, n = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        text = replaced
        if n == 0 then
            break
        end
    end
    return text
end

-- ===== 2. HUD =====
local gui = Instance.new("ScreenGui")
gui.Name = "ArenaEventHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 45
gui.Parent = player:WaitForChild("PlayerGui")

local function make(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local function label(parent, props)
    local base = {
        BackgroundTransparency = 1,
        FontFace = FONT,
        TextColor3 = THEME.cream,
        TextXAlignment = Enum.TextXAlignment.Left,
    }
    for key, value in props do
        base[key] = value
    end
    return make("TextLabel", base, parent)
end

local panel = make("Frame", {
    Name = "Panel",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 6),
    Size = UDim2.new(0.92, 0, 0, 78),
    BackgroundColor3 = THEME.lacquer,
    Visible = false,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(520, 120) }, panel)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, panel)
make("UIStroke", { Color = THEME.gold, Thickness = 2 }, panel)
make("UIPadding", {
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 12),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
}, panel)
local titleLabel = label(panel, {
    Size = UDim2.new(1, -80, 0, 24),
    Text = "ARENA BRAWL",
    TextSize = 22,
    TextColor3 = THEME.gold,
    TextTruncate = Enum.TextTruncate.AtEnd,
})
make("UIStroke", { Color = THEME.post, Thickness = 1.5 }, titleLabel)
local timerLabel = label(panel, {
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0, 80, 0, 24),
    TextSize = 20,
    TextXAlignment = Enum.TextXAlignment.Right,
})
local infoLabel = label(panel, {
    Position = UDim2.new(0, 0, 0, 28),
    Size = UDim2.new(1, 0, 0, 18),
    TextSize = 14,
    TextTruncate = Enum.TextTruncate.AtEnd,
})
local detailLabel = label(panel, {
    Position = UDim2.new(0, 0, 0, 48),
    Size = UDim2.new(1, 0, 0, 18),
    TextSize = 14,
    TextColor3 = THEME.gold,
    TextTruncate = Enum.TextTruncate.AtEnd,
})

local toast = label(gui, {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.24, 0),
    Size = UDim2.new(0, 480, 0, 50),
    TextSize = 30,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextTransparency = 1,
    TextWrapped = true,
    ZIndex = 30,
})
local toastStroke = make("UIStroke", { Color = THEME.post, Thickness = 3, Transparency = 1 }, toast)
local toastToken = 0
local function showToast(text, color, seconds)
    toastToken += 1
    local token = toastToken
    toast.Text = text
    toast.TextColor3 = color or THEME.cream
    toast.TextTransparency = 0
    toastStroke.Transparency = 0
    task.delay(seconds or 2.5, function()
        if token == toastToken then
            TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
            TweenService:Create(toastStroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
        end
    end)
end

-- ===== 2b. Podium Character Loadout UI (Active Buffs Strip + 3-Character Selector Modal) =====
local loadoutState = {
    available = {}, -- array of podium character entries
    equipped = {}, -- array of up to 3 uid strings
    combined = Config.CombineBuffs({}),
    modalOpen = false,
}

-- Compact strip directly under the Arena HUD panel showing equipped podium characters & active buffs + toggle button
local buffsBar = make("Frame", {
    Name = "BuffsBar",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 90),
    Size = UDim2.new(0.92, 0, 0, 34),
    BackgroundColor3 = THEME.lacquerDark,
    BackgroundTransparency = 0.06,
    Visible = false,
    ZIndex = 10,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(520, 38) }, buffsBar)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, buffsBar)
make("UIStroke", { Color = THEME.gold, Thickness = 1.5, Transparency = 0.25 }, buffsBar)
make("UIPadding", {
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 8),
    PaddingTop = UDim.new(0, 4),
    PaddingBottom = UDim.new(0, 4),
}, buffsBar)

local buffsSummaryLabel = label(buffsBar, {
    Name = "BuffsSummary",
    Size = UDim2.new(1, -132, 1, 0),
    Text = "PODIUM TEAM: None Equipped",
    TextSize = 13,
    TextColor3 = THEME.cream,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 11,
})
make("UIStroke", { Color = THEME.lacquerDeep, Thickness = 1.2 }, buffsSummaryLabel)

local toggleLoadoutBtn = make("TextButton", {
    Name = "ToggleLoadoutButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, 0, 0.5, 0),
    Size = UDim2.new(0, 128, 0, 24),
    BackgroundColor3 = THEME.gold,
    FontFace = FONT,
    Text = "PODIUM TEAM (0/3)",
    TextSize = 12,
    TextColor3 = THEME.lacquerDeep,
    AutoButtonColor = true,
    ZIndex = 12,
}, buffsBar)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, toggleLoadoutBtn)
make("UIStroke", {
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Color = THEME.lacquerDeep,
    Thickness = 1.5,
}, toggleLoadoutBtn)

-- Full 3-Character Podium Loadout Modal
local loadoutModal = make("Frame", {
    Name = "PodiumLoadoutModal",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.56, 0),
    Size = UDim2.new(0.92, 0, 0.74, 0),
    BackgroundColor3 = THEME.lacquer,
    Visible = false,
    Active = true,
    ZIndex = 20,
}, gui)
make("UISizeConstraint", { MaxSize = Vector2.new(736, 452), MinSize = Vector2.new(340, 320) }, loadoutModal)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, loadoutModal)
make("UIStroke", { Color = THEME.gold, Thickness = 2.5 }, loadoutModal)

-- Gold top bevel
make("Frame", {
    Name = "Bevel",
    Position = UDim2.new(0, 12, 0, 3),
    Size = UDim2.new(1, -24, 0, 2),
    BackgroundColor3 = THEME.goldBright,
    BackgroundTransparency = 0.35,
    BorderSizePixel = 0,
    ZIndex = 21,
}, loadoutModal)

-- Dark-wood inner page
local modalPage = make("Frame", {
    Name = "Page",
    Position = UDim2.new(0, 8, 0, 8),
    Size = UDim2.new(1, -16, 1, -16),
    BackgroundColor3 = THEME.lacquerDark,
    BorderSizePixel = 0,
    ZIndex = 21,
}, loadoutModal)
make("UICorner", { CornerRadius = UDim.new(0, 9) }, modalPage)
make("UIStroke", { Color = THEME.gold, Thickness = 1, Transparency = 0.45 }, modalPage)
make("UIPadding", {
    PaddingLeft = UDim.new(0, 12),
    PaddingRight = UDim.new(0, 12),
    PaddingTop = UDim.new(0, 10),
    PaddingBottom = UDim.new(0, 10),
}, modalPage)

-- Header row
local headerFrame = make("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 42),
    BackgroundTransparency = 1,
    ZIndex = 22,
}, modalPage)

local modalTitle = label(headerFrame, {
    Size = UDim2.new(1, -210, 0, 24),
    Text = "ARENA PODIUM LOADOUT",
    TextSize = 22,
    TextColor3 = THEME.goldBright,
    ZIndex = 22,
})
make("UIStroke", { Color = THEME.lacquerDeep, Thickness = 2 }, modalTitle)

local modalSubtitle = label(headerFrame, {
    Position = UDim2.new(0, 0, 0, 24),
    Size = UDim2.new(1, -210, 0, 16),
    FontFace = FONT_BODY,
    Text = "Equip up to 3 characters from your plot podiums to gain their battle attributes!",
    TextSize = 12,
    TextColor3 = THEME.muted,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 22,
})

local equipBestBtn = make("TextButton", {
    Name = "EquipBestButton",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -40, 0, 4),
    Size = UDim2.new(0, 110, 0, 30),
    BackgroundColor3 = THEME.gold,
    FontFace = FONT,
    Text = "EQUIP BEST 3",
    TextSize = 13,
    TextColor3 = THEME.lacquerDeep,
    ZIndex = 23,
}, headerFrame)
make("UICorner", { CornerRadius = UDim.new(0, 7) }, equipBestBtn)
make("UIStroke", {
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Color = THEME.lacquerDeep,
    Thickness = 1.5,
}, equipBestBtn)

local closeBtn = make("TextButton", {
    Name = "CloseButton",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 4),
    Size = UDim2.new(0, 32, 0, 30),
    BackgroundColor3 = THEME.red,
    FontFace = FONT,
    Text = "X",
    TextSize = 16,
    TextColor3 = THEME.cream,
    ZIndex = 23,
}, headerFrame)
make("UICorner", { CornerRadius = UDim.new(0, 7) }, closeBtn)
make("UIStroke", {
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Color = THEME.lacquerDeep,
    Thickness = 1.5,
}, closeBtn)

-- Top row: 3 Equipped Character Slots (left 62%) + Combined Attributes Box (right 36%)
local topSection = make("Frame", {
    Name = "TopSection",
    Position = UDim2.new(0, 0, 0, 48),
    Size = UDim2.new(1, 0, 0, 126),
    BackgroundTransparency = 1,
    ZIndex = 22,
}, modalPage)

local equippedSlotsContainer = make("Frame", {
    Name = "EquippedSlots",
    Size = UDim2.new(0.63, -6, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 22,
}, topSection)

local slotsLayout = make("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0.02, 0),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, equippedSlotsContainer)
local _ = slotsLayout

local statsSummaryBox = make("Frame", {
    Name = "StatsSummaryBox",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, 0, 0, 0),
    Size = UDim2.new(0.37, -4, 1, 0),
    BackgroundColor3 = THEME.well,
    ZIndex = 22,
}, topSection)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, statsSummaryBox)
make("UIStroke", { Color = THEME.gold, Thickness = 1.2, Transparency = 0.35 }, statsSummaryBox)
make("UIPadding", {
    PaddingLeft = UDim.new(0, 10),
    PaddingRight = UDim.new(0, 10),
    PaddingTop = UDim.new(0, 6),
    PaddingBottom = UDim.new(0, 6),
}, statsSummaryBox)

local summaryTitle = label(statsSummaryBox, {
    Size = UDim2.new(1, 0, 0, 18),
    Text = "ACTIVE TEAM ATTRIBUTES",
    TextSize = 13,
    TextColor3 = THEME.goldBright,
    TextXAlignment = Enum.TextXAlignment.Center,
    ZIndex = 23,
})
make("UIStroke", { Color = THEME.lacquerDeep, Thickness = 1.2 }, summaryTitle)

local summaryListFrame = make("Frame", {
    Name = "SummaryList",
    Position = UDim2.new(0, 0, 0, 22),
    Size = UDim2.new(1, 0, 1, -22),
    BackgroundTransparency = 1,
    ZIndex = 23,
}, statsSummaryBox)
make("UIGridLayout", {
    CellSize = UDim2.new(0.5, -3, 0, 22),
    CellPadding = UDim2.new(0, 6, 0, 4),
    FillDirection = Enum.FillDirection.Horizontal,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, summaryListFrame)

-- Middle section header
local gridHeader = label(modalPage, {
    Position = UDim2.new(0, 0, 0, 180),
    Size = UDim2.new(1, 0, 0, 18),
    Text = "YOUR PLOT PODIUM CHARACTERS (CLICK TO EQUIP UP TO 3)",
    TextSize = 13,
    TextColor3 = THEME.gold,
    ZIndex = 22,
})
make("UIStroke", { Color = THEME.lacquerDeep, Thickness = 1.2 }, gridHeader)

-- Scrolling grid of podium characters
local gridScroll = make("ScrollingFrame", {
    Name = "PodiumGrid",
    Position = UDim2.new(0, 0, 0, 202),
    Size = UDim2.new(1, 0, 1, -246),
    BackgroundColor3 = THEME.well,
    BorderSizePixel = 0,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = THEME.gold,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ZIndex = 22,
}, modalPage)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, gridScroll)
make("UIStroke", { Color = THEME.post, Thickness = 1 }, gridScroll)
make("UIPadding", {
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
    PaddingTop = UDim.new(0, 8),
    PaddingBottom = UDim.new(0, 8),
}, gridScroll)

local gridLayout = make("UIGridLayout", {
    CellSize = UDim2.new(0, 162, 0, 142),
    CellPadding = UDim2.new(0, 8, 0, 8),
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, gridScroll)
local _ = gridLayout

local emptyGridLabel = label(gridScroll, {
    Name = "EmptyNotice",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0.88, 0, 0, 64),
    FontFace = FONT_BODY,
    Text = "No characters found on your plot podiums!\nHatch eggs and place characters on your temple podiums to equip their Arena attributes.",
    TextSize = 14,
    TextColor3 = THEME.muted,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextWrapped = true,
    Visible = false,
    ZIndex = 23,
})

-- Footer row
local footerFrame = make("Frame", {
    Name = "Footer",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, 36),
    BackgroundTransparency = 1,
    ZIndex = 22,
}, modalPage)

local footerStatus = label(footerFrame, {
    Size = UDim2.new(1, -170, 1, 0),
    FontFace = FONT_BODY,
    Text = "Select up to 3 podium characters for this brawl.",
    TextSize = 13,
    TextColor3 = THEME.cream,
    TextTruncate = Enum.TextTruncate.AtEnd,
    ZIndex = 23,
})

local readyBtn = make("TextButton", {
    Name = "ReadyButton",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, 0, 0.5, 0),
    Size = UDim2.new(0, 156, 0, 32),
    BackgroundColor3 = THEME.green,
    FontFace = FONT,
    Text = "LOCK IN TEAM",
    TextSize = 16,
    TextColor3 = THEME.cream,
    ZIndex = 23,
}, footerFrame)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, readyBtn)
make("UIStroke", {
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Color = THEME.greenDark,
    Thickness = 2,
}, readyBtn)

-- Helper: renders a 3D character model inside a ViewportFrame using ReplicatedStorage.CharacterInventory.Portraits
local function framePortrait(viewport, characterId, golden)
    for _, child in viewport:GetChildren() do
        if child:IsA("Model") then
            child:Destroy()
        end
    end
    if not characterId then
        return
    end
    local invFolder = ReplicatedStorage:FindFirstChild("CharacterInventory")
    local portraits = invFolder and invFolder:FindFirstChild("Portraits")
    if not portraits then
        return
    end
    local template = (golden and portraits:FindFirstChild(characterId .. "_Golden"))
        or portraits:FindFirstChild(characterId)
    if not template then
        return
    end
    local copy = template:Clone()
    copy.Parent = viewport
    local camera = viewport.CurrentCamera
    if not camera then
        camera = Instance.new("Camera")
        camera.FieldOfView = 30
        camera.Parent = viewport
        viewport.CurrentCamera = camera
    end
    local boxCFrame, size = copy:GetBoundingBox()
    local radius = math.max(size.X, size.Y * 1.05, size.Z) * 0.5
    local distance = radius / math.tan(math.rad(camera.FieldOfView * 0.5)) * 1.08
    local facing = (copy:GetPivot().Rotation * CFrame.Angles(0, math.rad(20), 0)).LookVector
    facing = Vector3.new(facing.X, 0, facing.Z)
    facing = facing.Magnitude > 0.01 and facing.Unit or Vector3.zAxis
    camera.CFrame = CFrame.lookAt(
        boxCFrame.Position + facing * distance + Vector3.new(0, size.Y * 0.08, 0),
        boxCFrame.Position
    )
end

local function isUidEquipped(uid)
    for index, eqUid in ipairs(loadoutState.equipped) do
        if eqUid == uid then
            return true, index
        end
    end
    return false, nil
end

local renderLoadoutUI

local function pushEquippedToServer(newEquipped)
    loadoutState.equipped = newEquipped
    -- Optimistically compute combined buffs on the client so the UI responds instantly
    local byUid = {}
    for _, item in ipairs(loadoutState.available) do
        byUid[item.uid] = item
    end
    local equippedItems = {}
    for _, uid in ipairs(newEquipped) do
        if byUid[uid] then
            table.insert(equippedItems, byUid[uid])
        end
    end
    loadoutState.combined = Config.CombineBuffs(equippedItems)
    renderLoadoutUI()
    equipEvent:FireServer(newEquipped)
end

local function toggleCharacterUid(uid)
    playClick()
    local current = table.clone(loadoutState.equipped)
    local equipped, idx = isUidEquipped(uid)
    if equipped and idx then
        table.remove(current, idx)
    else
        if #current >= Config.MaxEquippedCharacters then
            -- Replace the 3rd slot so one-click swapping is effortless
            current[Config.MaxEquippedCharacters] = uid
        else
            table.insert(current, uid)
        end
    end
    pushEquippedToServer(current)
end

renderLoadoutUI = function()
    local byUid = {}
    for _, item in ipairs(loadoutState.available) do
        byUid[item.uid] = item
    end

    -- 1. Update top HUD buffs bar text & button
    local eqNames = {}
    for _, uid in ipairs(loadoutState.equipped) do
        local item = byUid[uid]
        if item then
            table.insert(eqNames, item.name)
        end
    end
    local summary = loadoutState.combined and loadoutState.combined.summary or {}
    local statSnippets = {}
    for _, entry in ipairs(summary) do
        table.insert(statSnippets, entry.shortText)
    end
    if #eqNames > 0 then
        buffsSummaryLabel.Text = table.concat(eqNames, " + ")
            .. (#statSnippets > 0 and ("  •  " .. table.concat(statSnippets, "  ")) or "")
    else
        buffsSummaryLabel.Text = "No Podium Characters Equipped — Click PODIUM TEAM to equip up to 3!"
    end
    toggleLoadoutBtn.Text = string.format("PODIUM TEAM (%d/%d)", #loadoutState.equipped, Config.MaxEquippedCharacters)

    -- 2. Render the 3 Equipped Slots
    for _, child in equippedSlotsContainer:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    for slotIdx = 1, Config.MaxEquippedCharacters do
        local uid = loadoutState.equipped[slotIdx]
        local item = uid and byUid[uid]
        local rarityColor = (item and RARITY_COLORS[item.rarity]) or THEME.gold
        local slotCard = make("TextButton", {
            Name = "EquippedSlot" .. slotIdx,
            LayoutOrder = slotIdx,
            Size = UDim2.new(0.32, 0, 1, 0),
            BackgroundColor3 = item and THEME.cardEquipped or THEME.well,
            AutoButtonColor = true,
            Text = "",
            ZIndex = 23,
        }, equippedSlotsContainer)
        make("UICorner", { CornerRadius = UDim.new(0, 8) }, slotCard)
        make("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = item and rarityColor or THEME.post,
            Thickness = item and 2 or 1.2,
        }, slotCard)

        local badge = label(slotCard, {
            Position = UDim2.new(0, 6, 0, 4),
            Size = UDim2.new(1, -12, 0, 14),
            Text = item and ("SLOT " .. slotIdx .. " • " .. (item.source or "PODIUM")) or ("SLOT " .. slotIdx .. " (EMPTY)"),
            TextSize = 10,
            TextColor3 = item and THEME.goldBright or THEME.muted,
            ZIndex = 24,
        })
        local _ = badge

        if item then
            local vp = make("ViewportFrame", {
                Name = "Portrait",
                Position = UDim2.new(0, 4, 0, 18),
                Size = UDim2.new(0, 52, 0, 52),
                BackgroundColor3 = THEME.well,
                Ambient = Color3.fromRGB(175, 175, 190),
                LightColor = Color3.fromRGB(255, 248, 235),
                LightDirection = Vector3.new(-0.5, -1, -0.6),
                ZIndex = 24,
            }, slotCard)
            make("UICorner", { CornerRadius = UDim.new(0, 6) }, vp)
            framePortrait(vp, item.characterId, item.golden)

            local nameLbl = label(slotCard, {
                Position = UDim2.new(0, 60, 0, 18),
                Size = UDim2.new(1, -64, 0, 18),
                Text = item.name,
                TextSize = 14,
                TextColor3 = rarityColor,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 24,
            })
            make("UIStroke", { Color = THEME.lacquerDeep, Thickness = 1.2 }, nameLbl)

            label(slotCard, {
                Position = UDim2.new(0, 60, 0, 36),
                Size = UDim2.new(1, -64, 0, 14),
                FontFace = FONT_BODY,
                Text = item.title or "Battle Spirit",
                TextSize = 10,
                TextColor3 = THEME.cream,
                TextTruncate = Enum.TextTruncate.AtEnd,
                ZIndex = 24,
            })

            if item.mutation then
                label(slotCard, {
                    Position = UDim2.new(0, 60, 0, 50),
                    Size = UDim2.new(1, -64, 0, 14),
                    Text = string.upper(item.mutation) .. " BOOST",
                    TextSize = 10,
                    TextColor3 = MUTATION_COLORS[item.mutation] or THEME.goldBright,
                    ZIndex = 24,
                })
            end

            local statText = table.concat(item.lines or {}, "\n")
            label(slotCard, {
                Position = UDim2.new(0, 6, 0, 72),
                Size = UDim2.new(1, -12, 0, 34),
                FontFace = FONT_BODY,
                Text = statText,
                TextSize = 11,
                TextColor3 = THEME.green,
                TextWrapped = true,
                TextYAlignment = Enum.TextYAlignment.Top,
                ZIndex = 24,
            })

            label(slotCard, {
                AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.new(1, -6, 1, -3),
                Size = UDim2.new(0, 66, 0, 12),
                FontFace = FONT_BODY,
                Text = "Click to remove",
                TextSize = 9,
                TextColor3 = THEME.muted,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 24,
            })

            slotCard.Activated:Connect(function()
                toggleCharacterUid(item.uid)
            end)
        else
            label(slotCard, {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.56, 0),
                Size = UDim2.new(0.86, 0, 0, 44),
                FontFace = FONT_BODY,
                Text = "Click a character below to equip",
                TextSize = 11,
                TextColor3 = THEME.muted,
                TextXAlignment = Enum.TextXAlignment.Center,
                TextWrapped = true,
                ZIndex = 24,
            })
        end
    end

    -- 3. Render Combined Attributes Summary Box
    for _, child in summaryListFrame:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    if #summary == 0 then
        local noneChip = make("Frame", {
            Size = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            ZIndex = 24,
        }, summaryListFrame)
        label(noneChip, {
            Size = UDim2.new(1, 0, 1, 0),
            FontFace = FONT_BODY,
            Text = "Equip characters to activate buffs!",
            TextSize = 11,
            TextColor3 = THEME.muted,
            ZIndex = 24,
        })
    else
        for idx, statEntry in ipairs(summary) do
            local pill = make("Frame", {
                LayoutOrder = idx,
                BackgroundColor3 = THEME.lacquer,
                ZIndex = 24,
            }, summaryListFrame)
            make("UICorner", { CornerRadius = UDim.new(0, 5) }, pill)
            make("UIStroke", { Color = statEntry.color, Thickness = 1, Transparency = 0.25 }, pill)
            local pillLbl = label(pill, {
                Position = UDim2.new(0, 5, 0, 0),
                Size = UDim2.new(1, -10, 1, 0),
                FontFace = FONT_BODY,
                Text = statEntry.text,
                TextSize = 10,
                TextScaled = true,
                TextColor3 = statEntry.color,
                ZIndex = 25,
            })
            make("UITextSizeConstraint", { MaxTextSize = 11, MinTextSize = 8 }, pillLbl)
        end
    end

    -- 4. Render Podium Characters Grid
    for _, child in gridScroll:GetChildren() do
        if child:IsA("GuiObject") and child ~= emptyGridLabel then
            child:Destroy()
        end
    end
    emptyGridLabel.Visible = #loadoutState.available == 0

    for idx, item in ipairs(loadoutState.available) do
        local equipped, slotNumber = isUidEquipped(item.uid)
        local rarityColor = RARITY_COLORS[item.rarity] or THEME.cream
        local card = make("TextButton", {
            Name = "PodiumChar_" .. idx,
            LayoutOrder = idx,
            BackgroundColor3 = equipped and THEME.cardEquipped or THEME.card,
            AutoButtonColor = true,
            Text = "",
            ZIndex = 23,
        }, gridScroll)
        make("UICorner", { CornerRadius = UDim.new(0, 8) }, card)
        make("UIStroke", {
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Color = equipped and THEME.goldBright or rarityColor,
            Thickness = equipped and 2.5 or 1.2,
            Transparency = equipped and 0 or 0.25,
        }, card)

        -- Top row: Podium slot tag + Rarity/Mutation tag
        label(card, {
            Position = UDim2.new(0, 7, 0, 4),
            Size = UDim2.new(0.55, 0, 0, 14),
            Text = item.source or "PODIUM",
            TextSize = 10,
            TextColor3 = THEME.gold,
            ZIndex = 24,
        })

        local rightTag = item.mutation and string.upper(item.mutation) or string.upper(item.rarity or "COMMON")
        local rightColor = (item.mutation and MUTATION_COLORS[item.mutation]) or rarityColor
        label(card, {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -7, 0, 4),
            Size = UDim2.new(0.45, -4, 0, 14),
            Text = rightTag,
            TextSize = 10,
            TextColor3 = rightColor,
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 24,
        })

        -- 3D Portrait Viewport
        local vp = make("ViewportFrame", {
            Name = "Portrait",
            Position = UDim2.new(0, 7, 0, 20),
            Size = UDim2.new(0, 50, 0, 50),
            BackgroundColor3 = THEME.well,
            Ambient = Color3.fromRGB(175, 175, 190),
            LightColor = Color3.fromRGB(255, 248, 235),
            LightDirection = Vector3.new(-0.5, -1, -0.6),
            ZIndex = 24,
        }, card)
        make("UICorner", { CornerRadius = UDim.new(0, 6) }, vp)
        framePortrait(vp, item.characterId, item.golden)

        -- Name + Passive Title
        local nameLbl = label(card, {
            Position = UDim2.new(0, 62, 0, 20),
            Size = UDim2.new(1, -68, 0, 18),
            Text = item.name,
            TextSize = 14,
            TextColor3 = rarityColor,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 24,
        })
        make("UIStroke", { Color = THEME.lacquerDeep, Thickness = 1.2 }, nameLbl)

        label(card, {
            Position = UDim2.new(0, 62, 0, 38),
            Size = UDim2.new(1, -68, 0, 14),
            FontFace = FONT_BODY,
            Text = item.title or "Fighter Spirit",
            TextSize = 10,
            TextColor3 = THEME.cream,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 24,
        })

        -- Attribute lines
        local buffLines = table.concat(item.lines or {}, "\n")
        label(card, {
            Position = UDim2.new(0, 7, 0, 73),
            Size = UDim2.new(1, -14, 0, 34),
            FontFace = FONT_BODY,
            Text = buffLines,
            TextSize = 11,
            TextColor3 = THEME.green,
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 24,
        })

        -- Action pill at bottom of card
        local actionPill = make("Frame", {
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, -6),
            Size = UDim2.new(1, -14, 0, 22),
            BackgroundColor3 = equipped and THEME.green or THEME.lacquerDeep,
            ZIndex = 24,
        }, card)
        make("UICorner", { CornerRadius = UDim.new(0, 5) }, actionPill)
        label(actionPill, {
            Size = UDim2.new(1, 0, 1, 0),
            Text = equipped and ("EQUIPPED (SLOT " .. tostring(slotNumber) .. ")") or "CLICK TO EQUIP",
            TextSize = 11,
            TextColor3 = equipped and THEME.cream or THEME.goldBright,
            TextXAlignment = Enum.TextXAlignment.Center,
            ZIndex = 25,
        })

        card.Activated:Connect(function()
            toggleCharacterUid(item.uid)
        end)
    end

    -- 5. Footer status
    footerStatus.Text = string.format(
        "%d / %d Podium Characters Equipped — Attributes apply to your bat & movement in the Arena!",
        #loadoutState.equipped,
        Config.MaxEquippedCharacters
    )
end

local function setLoadoutModalOpen(open)
    loadoutState.modalOpen = open == true
    loadoutModal.Visible = loadoutState.modalOpen
    if loadoutState.modalOpen then
        renderLoadoutUI()
    end
end

toggleLoadoutBtn.Activated:Connect(function()
    playClick()
    setLoadoutModalOpen(not loadoutState.modalOpen)
end)

closeBtn.Activated:Connect(function()
    playClick()
    setLoadoutModalOpen(false)
end)

readyBtn.Activated:Connect(function()
    playClick()
    setLoadoutModalOpen(false)
    showToast("PODIUM TEAM LOCKED IN!", THEME.goldBright, 2)
end)

equipBestBtn.Activated:Connect(function()
    playClick()
    local ranked = table.clone(loadoutState.available)
    table.sort(ranked, function(a, b)
        if (a.rarityRank or 1) ~= (b.rarityRank or 1) then
            return (a.rarityRank or 1) > (b.rarityRank or 1)
        end
        return (a.power or 0) > (b.power or 0)
    end)
    local best = {}
    for i = 1, math.min(Config.MaxEquippedCharacters, #ranked) do
        table.insert(best, ranked[i].uid)
    end
    pushEquippedToServer(best)
end)

local function setPanel(height, titleText, timerText, infoText, detailText)
    panel.Visible = true
    panel.Size = UDim2.new(0.92, 0, 0, height)
    titleLabel.Text = titleText
    timerLabel.Text = timerText or ""
    infoLabel.Text = infoText or ""
    infoLabel.Visible = infoText ~= nil
    detailLabel.Text = detailText or ""
    detailLabel.Visible = detailText ~= nil
    -- sit under the river boss panel when both are showing
    local bossHud = player.PlayerGui:FindFirstChild("BossEventHUD")
    local bossPanel = bossHud and bossHud:FindFirstChild("Panel")
    local topY = (bossPanel and bossPanel.Visible) and (bossPanel.AbsoluteSize.Y + 14) or 6
    panel.Position = UDim2.new(0.5, 0, 0, topY)
    buffsBar.Position = UDim2.new(0.5, 0, 0, topY + height + 6)
end

-- ===== 3. The personal portal (built here, on this client only) =====
local PORTAL_PURPLE = Color3.fromRGB(150, 90, 255)
local PORTAL_CYAN = Color3.fromRGB(110, 230, 255)
local STUD_VARIANT = "Incubator One Stud Cavity"
local portal -- { cframe, folder, parts = { {part, transparency} }, bars, membrane, timerLabel, joined }

local function portalPart(parent, name, size, localCFrame, root, color, neon)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Color = color
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    if neon then
        part.Material = Enum.Material.Neon
    else
        part.Material = Enum.Material.Plastic
        part.MaterialVariant = STUD_VARIANT
    end
    part.CFrame = root * localCFrame
    part.Parent = parent
    return part
end

local function buildPortal(cframe)
    local built = Instance.new("Folder")
    built.Name = "ArenaPortalLocal"
    local parts, bars = {}, {}
    local function add(part, bar)
        table.insert(parts, { part = part, transparency = part.Transparency })
        if bar then
            table.insert(bars, bar)
        end
        return part
    end
    -- gate: two lacquered posts, a gold lintel, neon studs up the posts (the opening faces the plot)
    add(portalPart(built, "PostL", Vector3.new(2, 13, 2), CFrame.new(-5.5, 6.5, 0), cframe, THEME.lacquer, false))
    add(portalPart(built, "PostR", Vector3.new(2, 13, 2), CFrame.new(5.5, 6.5, 0), cframe, THEME.lacquer, false))
    add(portalPart(built, "Lintel", Vector3.new(14, 2, 3), CFrame.new(0, 14, 0), cframe, THEME.gold, false))
    add(portalPart(built, "Cap", Vector3.new(10, 1, 2), CFrame.new(0, 15.5, 0), cframe, THEME.post, false))
    for _, x in { -5.5, 5.5 } do
        for y = 2, 12, 2.5 do
            add(
                portalPart(
                    built,
                    "Stud",
                    Vector3.new(0.75, 0.75, 0.75),
                    CFrame.new(x, y, -1.2),
                    cframe,
                    PORTAL_CYAN,
                    true
                )
            )
        end
    end
    -- the swirling membrane: a glowing sheet and spinning bars
    local membrane = add(
        portalPart(built, "Membrane", Vector3.new(9, 12, 0.3), CFrame.new(0, 6.2, 0), cframe, PORTAL_PURPLE, true)
    )
    membrane.Transparency = 0.45
    parts[#parts].transparency = 0.45
    for i = 1, 3 do
        local bar = add(
            portalPart(built, "Swirl", Vector3.new(0.5, 9, 0.25), CFrame.new(0, 6.2, -0.3), cframe, PORTAL_CYAN, true)
        )
        bar.Transparency = 0.2
        parts[#parts].transparency = 0.2
        table.insert(bars, { part = bar, offset = (i - 1) * math.pi / 3 })
    end
    local emitter = Instance.new("ParticleEmitter")
    emitter.Rate = 30
    emitter.Lifetime = NumberRange.new(1, 1.8)
    emitter.Speed = NumberRange.new(2, 5)
    emitter.SpreadAngle = Vector2.new(180, 180)
    emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
    emitter.Color = ColorSequence.new(PORTAL_CYAN, PORTAL_PURPLE)
    emitter.LightEmission = 1
    emitter.Parent = membrane
    local light = Instance.new("PointLight")
    light.Color = PORTAL_PURPLE
    light.Range = 26
    light.Brightness = 3
    light.Parent = membrane
    -- floating label
    local billboard = make("BillboardGui", {
        Adornee = parts[1].part,
        Size = UDim2.new(0, 260, 0, 66),
        StudsOffsetWorldSpace = Vector3.new(0, 11, 0),
        AlwaysOnTop = false,
        MaxDistance = 220,
        LightInfluence = 0,
    }, built)
    local title = label(billboard, {
        Size = UDim2.new(1, 0, 0, 36),
        Text = "ARENA BRAWL",
        TextSize = 30,
        TextColor3 = THEME.gold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    make("UIStroke", { Color = THEME.post, Thickness = 2.5 }, title)
    local timer = label(billboard, {
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(1, 0, 0, 26),
        Text = "Walk in to join!",
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    make("UIStroke", { Color = THEME.post, Thickness = 2 }, timer)
    -- pop in
    for _, entry in parts do
        entry.part.Transparency = 1
        TweenService:Create(entry.part, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Transparency = entry.transparency })
            :Play()
    end
    built.Parent = workspace
    return { cframe = cframe, folder = built, parts = parts, bars = bars, timerLabel = timer, joinedAt = nil }
end

local function closePortal(current)
    if not current then
        return
    end
    for _, entry in current.parts do
        if entry.part.Parent then
            TweenService:Create(entry.part, TweenInfo.new(0.4), { Transparency = 1 }):Play()
        end
    end
    task.delay(0.5, function()
        current.folder:Destroy()
    end)
end

local lastJoinFire = 0
local function updatePortal(now)
    local wantedCFrame = player:GetAttribute("ArenaPortalCFrame")
    local want = workspace:GetAttribute("ArenaPhase") == "Lobby" and typeof(wantedCFrame) == "CFrame"
    if want and portal and portal.cframe ~= wantedCFrame then
        closePortal(portal)
        portal = nil
    end
    if want and not portal then
        portal = buildPortal(wantedCFrame)
    elseif not want and portal then
        closePortal(portal)
        portal = nil
    end
    if not portal then
        return
    end
    local t = os.clock()
    for _, bar in portal.bars do
        if bar.part then
            local angle = t * 2.2 + bar.offset
            bar.part.CFrame = portal.cframe * CFrame.new(0, 6.2, -0.3) * CFrame.Angles(0, 0, angle)
        end
    end
    portal.timerLabel.Text = formatTime((workspace:GetAttribute("ArenaEndsAt") or now) - now)
        .. " left - walk in to join!"
    -- walking in: inside the gate's opening
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    if root and os.clock() - lastJoinFire > 1 then
        local rel = portal.cframe:PointToObjectSpace(root.Position)
        if math.abs(rel.X) < 5 and rel.Y > -1 and rel.Y < 14 and math.abs(rel.Z) < 4 then
            lastJoinFire = os.clock()
            joinEvent:FireServer()
        end
    end
end

-- ===== 3b. Volcano atmosphere (this player only: client-side Lighting effects, only while inside the zone) =====
local Lighting = game:GetService("Lighting")
local volcanoTint = Instance.new("ColorCorrectionEffect")
volcanoTint.Name = "ArenaVolcanoTint"
volcanoTint.TintColor = Color3.fromRGB(255, 190, 150)
volcanoTint.Contrast = 0.2
volcanoTint.Saturation = 0.15
volcanoTint.Brightness = -0.12
volcanoTint.Enabled = false
volcanoTint.Parent = Lighting
local volcanoBloom = Instance.new("BloomEffect")
volcanoBloom.Name = "ArenaVolcanoBloom"
volcanoBloom.Intensity = 0.25
volcanoBloom.Size = 24
volcanoBloom.Threshold = 0.95
volcanoBloom.Enabled = false
volcanoBloom.Parent = Lighting
local hazeBefore = nil
local function setHaze(inside)
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        return
    end
    if inside and not hazeBefore then
        hazeBefore = {
            Density = atmosphere.Density,
            Color = atmosphere.Color,
            Decay = atmosphere.Decay,
            Haze = atmosphere.Haze,
            Glare = atmosphere.Glare,
            Offset = atmosphere.Offset,
        }
        atmosphere.Density = 0.36
        atmosphere.Color = Color3.fromRGB(255, 120, 60)
        atmosphere.Decay = Color3.fromRGB(150, 45, 20)
        atmosphere.Haze = 2.2
        atmosphere.Glare = 0
        atmosphere.Offset = 0.15
    elseif not inside and hazeBefore then
        for property, value in hazeBefore do
            atmosphere[property] = value
        end
        hazeBefore = nil
    end
end
local lastZoneCheck = 0
local function updateAtmosphere()
    if os.clock() - lastZoneCheck < 0.4 then
        return
    end
    lastZoneCheck = os.clock()
    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local inside = false
    if root then
        local offset = root.Position - Config.Center
        inside = Vector3.new(offset.X, 0, offset.Z).Magnitude < Config.ZoneRadius and math.abs(offset.Y) < 260
    end
    volcanoTint.Enabled = inside
    volcanoBloom.Enabled = inside
    setHaze(inside)
end

-- ===== 4. State -> HUD =====
local wasInArena = false
local lastPhase = "Idle"
local function refresh()
    local now = workspace:GetServerTimeNow()
    local phase = workspace:GetAttribute("ArenaPhase") or "Idle"
    local endsAt = workspace:GetAttribute("ArenaEndsAt") or now
    local inArena = player:GetAttribute("ArenaIn") == true
    local locked = player:GetAttribute("ArenaLocked") == true
    updatePortal(now)
    updateAtmosphere()

    -- Show the active podium buffs strip whenever the player is inside the Arena Brawl (and modal is collapsed)
    buffsBar.Visible = inArena
        and not loadoutState.modalOpen
        and (phase == "Lobby" or phase == "Countdown" or phase == "Fight")
    if not inArena and wasInArena then
        setLoadoutModalOpen(false)
    elseif inArena and phase == "Fight" and lastPhase ~= "Fight" then
        -- Auto-collapse the large selector modal when the fight begins so it doesn't block combat view
        setLoadoutModalOpen(false)
    end
    wasInArena = inArena
    lastPhase = phase

    if phase == "Lobby" then
        local joined = workspace:GetAttribute("ArenaRegistered") or 0
        local info, detail
        if inArena then
            info = "You're in! The fight starts when the timer ends - " .. joined .. " joined"
            detail = "Equip up to 3 Podium Characters for battle attributes while you wait!"
        elseif locked then
            info = "You're out of this brawl - no rejoining. " .. joined .. " joined"
            detail = nil
        else
            info = "Walk into the glowing portal outside your plot to join! " .. joined .. " joined"
            detail = "Knockout pay: $"
                .. formatCash(Config.KnockoutCash)
                .. " each - winner $"
                .. formatCash(Config.WinnerCash)
        end
        setPanel(detail and 78 or 58, "ARENA BRAWL - PORTAL OPEN!", formatTime(endsAt - now), info, detail)
    elseif phase == "Countdown" then
        setPanel(
            58,
            inArena and "GET READY!" or "ARENA BRAWL STARTING",
            formatTime(endsAt - now),
            inArena and "Equip your bat - your Podium Team buffs are active!" or "The portals have closed.",
            nil
        )
    elseif phase == "Fight" then
        local fighters = workspace:GetAttribute("ArenaFighters") or 0
        local shrinkAt = workspace:GetAttribute("ArenaShrinkAt")
        local info = inArena
                and ("Fighters left: " .. fighters .. "  -  Your knockouts: " .. (player:GetAttribute("ArenaKOs") or 0))
            or ("Spectating  -  Fighters left: " .. fighters)
        local detail = shrinkAt and ("The outer ring crumbles in " .. formatTime(shrinkAt - now))
            or "Final platform - no more ring drops!"
        setPanel(78, "ARENA BRAWL", formatTime(endsAt - now), info, detail)
    elseif phase == "Ended" then
        local winner = workspace:GetAttribute("ArenaWinner")
        setPanel(58, winner and ("WINNER: " .. winner) or "ARENA BRAWL OVER", nil, "Heading back to the map...", nil)
    else
        local nextAt = workspace:GetAttribute("ArenaNextAt")
        if nextAt and nextAt - now <= 60 and nextAt - now > 0 then
            setPanel(38, "ARENA BRAWL IN", formatTime(nextAt - now), nil, nil)
        else
            panel.Visible = false
        end
    end
end
RunService.Heartbeat:Connect(refresh)

-- ===== 5. Server events =====
fxEvent.OnClientEvent:Connect(function(kind, data)
    if kind == "LoadoutState" and type(data) == "table" then
        loadoutState.available = data.available or {}
        loadoutState.equipped = data.equipped or {}
        loadoutState.combined = data.combined or Config.CombineBuffs({})
        renderLoadoutUI()
        if data.openUI then
            setLoadoutModalOpen(true)
        end
    elseif kind == "Notice" then
        showToast(tostring(data.text), THEME.cream, 4)
    elseif kind == "Knockout" then
        showToast("KNOCKOUT! " .. tostring(data.name), THEME.gold, 2)
    elseif kind == "Out" then
        local place = data.place or 0
        showToast("YOU'RE OUT! #" .. place .. " of " .. (data.total or 0), Color3.fromRGB(240, 150, 60), 3)
    elseif kind == "Result" then
        local cash = data.cash or 0
        if data.won then
            showToast("YOU WIN!" .. (cash > 0 and ("  +$" .. formatCash(cash)) or ""), THEME.gold, 4)
        elseif cash > 0 then
            showToast("#" .. (data.place or 0) .. "  +$" .. formatCash(cash), THEME.cream, 3.5)
        end
    end
end)
