--[[ StarterPlayerScripts.GameHUD (LocalScript)
Main in-game HUD. Builds two ScreenGuis in PlayerGui:
  GameHUD   custom hotbar (Roblox's backpack stays hidden - ReplicatedFirst.CustomInventoryBootstrap), the
            Backpack button, the Inventory panel above the hotbar and the hotbar hover tooltip
  NightBar  top-centre Day / Night event HUD (ReplicatedStorage.TimeHUD) + the big 5..1 countdown before night
and disables the legacy NighttimeHUD / NighttimeStatus ScreenGuis (now and whenever they are re-added).

Table of contents (section banners below are "-- ===== N. ... =====")
  1. Services, modules, palette, UI primitives (create / addCorner / addStroke / tween / formatMoney)
  2. Tool preview (catalog portrait, mutation aura, 3D viewport) and tool description
  3. Hotbar: tray, tool order, egg stacking, renderBar, number keys 1-9
  4. Drag items onto the hotbar (and tap-to-hold)
  5. Legacy sell bag ("EggBag"), Backpack button, quotes and selling. The bag panel itself is retired
     (setBagOpen forwards to the Inventory panel), but it is still built and its helpers are shared.
  6. Inventory panel (tabs, rarity/mutation filters, search, SELL mode; Backpack button or the ` key)
  7. Hotbar hover tooltip
  8. Backpack/character change watchers + the hotbar refresh loop
  9. Night timer (NightBar)
 10. Away-earnings popup (disabled - OfflineEarningsUI replaced it)
 11. Go home: key H + server reply popup (the HOME button is GameMenus.LeftMenu)

Remotes (ReplicatedStorage):
  SellEgg                              (RF, WaitForChild 10 s)  "Quote", tool -> number | other
                                                                 "Sell", tool -> ok, cashOrMessage
                                                                 "SellAll" -> ok, cashOrMessage, count
  CharacterInventory.InventoryRequest  (RF)  "Fetch" -> { ok, snapshot }
                                             "SellBackpack", { id } / "SellBackpackAll", { ids }
                                               -> { ok, message (JSON { cash, count } on success), snapshot? }
  CharacterInventory.InventoryEvent    (RE)  server -> "Snapshot", snapshot ({ items = { { id, sellValue, power,
                                             income, ... } } })
  GoHome                               (RE, WaitForChild 10 s)  FireServer(); server replies with a message string
Modules: CharacterCatalog (ById: Name, Rarity, Id, image), UISound (Play), PixelIcon (builds the "bag" icons),
  TimeHUD.TimeComponent / TimeConfig (the time HUD).
Attributes read:
  Tool: CharacterId / BrainrotId, EggType, Mutation, Rarity, UnknownEgg, GoldVariant, DesignName, ItemId, Power,
        IncomePerSecond; tool parts: CarryOriginalTransparency
  workspace: NighttimeActive, NighttimeEndsAt, NighttimeNextAt (server time), NightBonusCash,
             NightBonusHatchSpeed, NightBonusRiverLuck
  player: OfflineEarnings (changed signal only), OfflineSeconds
Attributes written: hotbar slot "Sig" / "ToolRef", slot button "EdgeColor", bag card "ItemId" / "Category".
  Instance names (GameHUD, NightBar, RightButtons.BagButton, EggBag, Inventory, Hotbar, ...) are looked up by
  FigmaSkin, SharpUI and FirstHatchTutorial.
Input: keys 1-9 (equip hotbar slot), ` (Inventory), H (go home).

Init order (top level, in file order - WaitForChild calls yield):
  PlayerGui -> CharacterCatalog, UISound -> GameHUD ScreenGui -> catalog image map -> hotbar -> 1-9 keys ->
  SellEgg (10 s), CharacterInventory remotes -> right buttons (PixelIcon) -> legacy bag -> Inventory panel ->
  tooltip -> change watchers + refresh loop -> NightBar -> away earnings -> go home (GoHome, 10 s).
]]

-- ===== 1. Services, modules, palette, UI primitives =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local CharacterCatalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local INK = Color3.fromRGB(29, 20, 32)
local CREAM = Color3.fromRGB(255, 243, 220)
local GOLD = Color3.fromRGB(255, 200, 80)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local RARITY_COLORS = {
    Common = Color3.fromRGB(190, 195, 205),
    Uncommon = Color3.fromRGB(109, 225, 132),
    Rare = Color3.fromRGB(98, 172, 255),
    Epic = Color3.fromRGB(197, 126, 255),
    Legendary = Color3.fromRGB(255, 207, 92),
    Limited = Color3.fromRGB(255, 60, 90),
}
-- Instance builder: sets every prop, then parents last (property writes happen before it enters the tree).
local function create(className, props, parent)
    local instance = Instance.new(className)
    for key, value in props do
        instance[key] = value
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end
local function addCorner(target, radius)
    return create("UICorner", { CornerRadius = radius or UDim.new(0, 12) }, target)
end
local function addStroke(target, thickness, color)
    return create(
        "UIStroke",
        { Thickness = thickness or 3, Color = color or INK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
        target
    )
end
local function tween(target, duration, goals, style, direction)
    local tweenObject = TweenService:Create(
        target,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
        goals
    )
    tweenObject:Play()
    return tweenObject
end
-- 1234 -> "$1.2K", 150000 -> "$150K" (a trailing ".0" is dropped), below 1000 -> "$123".
local function formatMoney(n)
    local suffixes = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
    for _, suffix in suffixes do
        if n >= suffix[1] then
            local scaled = n / suffix[1]
            local text = scaled >= 100 and string.format("%d", scaled) or string.format("%.1f", scaled)
            return "$" .. text:gsub("%.0$", "") .. suffix[2]
        end
    end
    return "$" .. math.floor(n)
end

local gui = create(
    "ScreenGui",
    { Name = "GameHUD", ResetOnSpawn = false, DisplayOrder = 40, ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets },
    playerGui
)

-- ReplicatedFirst.CustomInventoryBootstrap keeps Roblox's backpack hidden from startup.

-- ===== 2. Tool preview (3D icon) and tool description =====
-- Weak-keyed by tool: the cleaned preview model is built once per tool and cloned for every later preview.
local PREVIEW_CACHE = setmetatable({}, { __mode = "k" })
local CATALOG_IMAGES
do
    local ok, catalogModule = pcall(require, game:GetService("ReplicatedStorage"):WaitForChild("CharacterCatalog"))
    CATALOG_IMAGES = {}
    if ok then
        for id, entry in catalogModule.ById do
            CATALOG_IMAGES[id] = entry.image
        end
    end
end
-- Animated aura behind a mutated character portrait: a tinted, spinning gradient disc that pulses, plus a
-- shine sweep. Re-parents the portrait so it draws above the aura. The loop ends once the portrait is unparented.
local function addMutationAura(portrait, parent, mutation)
    local mutationGradients = {
        Silver = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 180, 200)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 155, 185)),
        }),
        Gold = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 30)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 240, 140)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 130, 20)),
        }),
        Diamond = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 190, 255)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 250, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 140, 255)),
        }),
    }
    local auraColors = mutationGradients[mutation]
        or ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 90)),
            ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 70)),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 230, 120)),
            ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 150, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
        })
    local aura = create("Frame", {
        Name = "RainbowAura",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.95, 0.95),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = parent.ZIndex,
    }, parent)
    create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, aura)
    local auraGradient = create("UIGradient", {
        Color = auraColors,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.35),
            NumberSequenceKeypoint.new(0.5, 0.55),
            NumberSequenceKeypoint.new(1, 0.35),
        }),
    }, aura)
    local core = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.62, 0.62),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = parent.ZIndex,
    }, aura)
    create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, core)
    portrait.Parent = nil
    portrait.Parent = parent
    portrait.ZIndex = parent.ZIndex + 1
    local shineClip = create("Frame", {
        Name = "ShineClip",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.8, 0.8),
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        ZIndex = parent.ZIndex + 2,
    }, parent)
    local shine = create("Frame", {
        Name = "Shine",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0.18, 0, 2, 0),
        Rotation = 25,
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.55,
        BorderSizePixel = 0,
        ZIndex = parent.ZIndex + 2,
    }, shineClip)
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.5, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, shine)
    task.spawn(function()
        local startTime = os.clock()
        while portrait.Parent do
            local elapsed = os.clock() - startTime
            auraGradient.Rotation = (elapsed * 90) % 360
            local pulse = 1 + 0.06 * math.sin(elapsed * 3)
            aura.Size = UDim2.fromScale(0.95 * pulse, 0.95 * pulse)
            local phase = (elapsed / 2.2) % 1
            shine.Position = UDim2.fromScale(-0.4 + phase * 1.8, 0.5)
            shine.Visible = phase < 0.6
            task.wait(0.03)
        end
    end)
end
-- Cache miss in buildPreview: a Model holding anchored, cleaned clones of the tool's visible parts, positioned in
-- the egg's/tool's own upright frame (falls back to the Handle). Caches a copy in PREVIEW_CACHE if non-empty.
local function buildPreviewModel(tool)
    local model = Instance.new("Model")
    local egg = tool:FindFirstChild("Egg")
    local sourceModel = egg and egg:IsA("Model") and egg or tool
    -- the egg Model's WorldPivot goes stale once its parts move with the welded Handle, so frame from the Handle
    -- (eggs are built with Handle and egg both at the origin, so Handle space = the egg's upright template space)
    local handle = tool:FindFirstChild("Handle")
    local pivot = (egg and handle and handle:IsA("BasePart")) and handle.CFrame
        or (sourceModel:IsA("Model") and sourceModel:GetPivot() or CFrame.new())
    -- invisible helper parts (aura/particle holders) stay out: viewports can't draw particles, so they'd show as grey blocks
    local function isFxHelper(part)
        if part:GetAttribute("CarryOriginalTransparency") ~= nil or part.Transparency < 1 then
            return false
        end
        if part:IsA("MeshPart") or part:FindFirstChildWhichIsA("DataModelMesh") then
            return part:FindFirstChildWhichIsA("ParticleEmitter", true) ~= nil
                and not (part:IsA("MeshPart") and part.TextureID ~= "")
                and not part:FindFirstChildWhichIsA("SurfaceAppearance")
        end
        return true
    end
    for _, descendant in sourceModel:GetDescendants() do
        if descendant:IsA("BasePart") and descendant.Name ~= "Handle" and not isFxHelper(descendant) then
            local partClone = descendant:Clone()
            for _, child in partClone:GetChildren() do
                if
                    not (
                        child:IsA("DataModelMesh")
                        or child:IsA("Decal")
                        or child:IsA("SurfaceAppearance")
                        or child:IsA("Texture")
                    )
                then
                    child:Destroy()
                end
            end
            partClone.Transparency = descendant:GetAttribute("CarryOriginalTransparency")
                or (descendant.Transparency >= 1 and 0 or descendant.Transparency)
            partClone.LocalTransparencyModifier = 0
            partClone.Anchored = true
            partClone.CFrame = pivot:ToObjectSpace(descendant.CFrame)
            partClone.Parent = model
        end
    end -- back into the egg's own upright frame
    if #model:GetChildren() == 0 then
        local fallbackHandle = tool:FindFirstChild("Handle")
        if fallbackHandle then
            local handleClone = fallbackHandle:Clone()
            for _, child in handleClone:GetChildren() do
                if not (child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance")) then
                    child:Destroy()
                end
            end
            handleClone.Transparency = 0
            handleClone.Anchored = true
            handleClone.CFrame = CFrame.new()
            handleClone.Parent = model
        end
    end
    if #model:GetChildren() > 0 then
        PREVIEW_CACHE[tool] = model:Clone()
    end
    return model
end
-- Fills `parent` with the tool's icon and returns it: catalog portrait for characters (with an animated aura
-- for mutations), the tool's TextureId if set, else a ViewportFrame with a slowly turning copy of its parts.
-- The spawned animation loops end on their own once the icon is unparented.
local function buildPreview(tool, parent)
    -- characters: clean 2D portrait from the catalog (same art as the Index)
    local characterId = tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")
    if characterId and CATALOG_IMAGES[characterId] then
        local portrait = create("ImageLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.46),
            Size = UDim2.fromScale(1.25, 1.25),
            BackgroundTransparency = 1,
            Image = CATALOG_IMAGES[characterId],
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = parent.ZIndex,
        }, parent)
        local mutation = tool:GetAttribute("Mutation")
        if mutation == "Gold" then
            portrait.ImageColor3 = Color3.fromRGB(255, 215, 110)
        elseif mutation == "Diamond" then
            portrait.ImageColor3 = Color3.fromRGB(150, 235, 255)
        elseif mutation == "Silver" then
            portrait.ImageColor3 = Color3.fromRGB(220, 225, 235)
        end
        if mutation then
            addMutationAura(portrait, parent, mutation)
        end
        -- disabled rainbow tint (dead code, kept as-is)
        if false then
            local rainbowGradient = create("UIGradient", {
                Rotation = 45,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 140)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 240, 140)),
                    ColorSequenceKeypoint.new(0.66, Color3.fromRGB(150, 255, 170)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 190, 255)),
                }),
            }, portrait)
            task.spawn(function()
                while portrait.Parent do
                    rainbowGradient.Rotation = (rainbowGradient.Rotation + 2) % 360
                    task.wait(0.03)
                end
            end)
        end
        return portrait
    end
    if tool.TextureId ~= "" then
        return create("ImageLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
            Image = tool.TextureId,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = parent.ZIndex,
        }, parent)
    end
    local viewport = create("ViewportFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        ZIndex = parent.ZIndex,
        LightColor = Color3.new(1, 1, 1),
        Ambient = Color3.fromRGB(235, 235, 240),
        LightDirection = Vector3.new(-0.3, -0.6, -1),
    }, parent)
    local model
    if PREVIEW_CACHE[tool] then
        model = PREVIEW_CACHE[tool]:Clone()
    else
        model = buildPreviewModel(tool)
    end
    model.Parent = viewport
    local boxCFrame, boxSize = model:GetBoundingBox()
    local camera = create("Camera", { FieldOfView = 20 }, viewport)
    viewport.CurrentCamera = camera
    local center = boxCFrame.Position
    local distance = math.max(boxSize.X, boxSize.Y, boxSize.Z) / 2 / math.tan(math.rad(10)) * 1.05
    local front = tool:GetAttribute("EggType") and Vector3.new(0, 0, -1) or Vector3.new(0.5, 0.2, -1).Unit
    camera.CFrame = CFrame.lookAt(center + front * distance + Vector3.new(0, boxSize.Y * 0.05, 0), center)
    -- slow turn so 3D eggs feel alive
    task.spawn(function()
        local angle = 0
        while viewport.Parent do
            angle += 0.012
            local direction = CFrame.Angles(0, math.sin(angle) * 0.35, 0):VectorToWorldSpace(front)
            camera.CFrame = CFrame.lookAt(center + direction * distance + Vector3.new(0, boxSize.Y * 0.05, 0), center)
            task.wait(0.03)
        end
    end)
    return viewport
end
-- "Characters" | "Eggs" | nil (any other tool is ignored by the bag and the Inventory panel)
local function getCategory(tool)
    if tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId") then
        return "Characters"
    end
    if tool:GetAttribute("EggType") then
        return "Eggs"
    end
end
-- Returns displayName, rarity, isEgg.
local function describeTool(tool)
    local kind = getCategory(tool)
    local id = tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId") or tool:GetAttribute("EggType")
    local entry = id and CharacterCatalog.ById[id]
    local rarity = tool:GetAttribute("Rarity") or (entry and entry.Rarity)
    local name = tool.Name
    if kind == "Eggs" then
        name = tool:GetAttribute("UnknownEgg") and "Unknown Egg" or ((entry and entry.Id or id) .. " Egg")
    elseif kind == "Characters" then
        name = (tool:GetAttribute("GoldVariant") and "Golden " or "")
            .. (entry and entry.Name or tool:GetAttribute("DesignName") or tool.Name)
    end
    return name, rarity, kind == "Eggs"
end

-- ===== 3. Hotbar =====
local BLACK = Color3.new(0, 0, 0)
local PLATE = Color3.fromRGB(38, 56, 68)
local function addStuds(parent, tileSize, transparency)
    return create("ImageLabel", {
        Name = "Studs",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Image = "rbxassetid://132561191216691",
        ScaleType = Enum.ScaleType.Tile,
        TileSize = UDim2.fromOffset(tileSize, tileSize),
        ImageTransparency = transparency,
        ZIndex = parent.ZIndex,
    }, parent)
end
local trayShadow = create("Frame", {
    Name = "HotbarShadow",
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 6, 1, -6),
    Size = UDim2.fromOffset(0, 0),
    BackgroundColor3 = BLACK,
    BorderSizePixel = 0,
    Visible = false,
}, gui)
local hotbar = create("Frame", {
    Name = "Hotbar",
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -12),
    Size = UDim2.fromOffset(0, 96),
    AutomaticSize = Enum.AutomaticSize.X,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 3,
}, gui)
-- backing layer (outside the bar so its UIListLayout only arranges slots)
local traySkin = create("Frame", {
    Name = "HotbarSkin",
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -12),
    Size = UDim2.fromOffset(0, 0),
    BackgroundColor3 = PLATE,
    BorderSizePixel = 0,
    ZIndex = 2,
    Visible = false,
}, gui)
addStuds(traySkin, 24, 0.82)
create("Frame", {
    Name = "TopStrip",
    Size = UDim2.new(1, 0, 0, 5),
    BackgroundColor3 = Color3.fromRGB(255, 150, 30),
    BorderSizePixel = 0,
    ZIndex = 2,
}, traySkin)
create("UIStroke", { Color = BLACK, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Miter }, hotbar)
create("UIPadding", {
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
    PaddingTop = UDim.new(0, 10),
    PaddingBottom = UDim.new(0, 8),
}, hotbar)
create("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 8),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, hotbar)
hotbar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    local barSize = UDim2.fromOffset(hotbar.AbsoluteSize.X, hotbar.AbsoluteSize.Y)
    trayShadow.Size = barSize
    traySkin.Size = barSize
end)
-- phones: shrink fixed-pixel HUD pieces (hotbar, night timer) on short screens; desktop stays 1
local function phoneScale()
    local camera = workspace.CurrentCamera
    local viewportSize = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local shortSide = math.min(viewportSize.X, viewportSize.Y)
    return shortSide < 600 and math.clamp(shortSide / 720, 0.6, 1) or 1
end
local hotbarScale = create("UIScale", { Scale = phoneScale() }, hotbar)
local bagOpen = false
local MAX_SLOTS = 9
local slots = {}
local function visibleSlotCount()
    local screenSize = gui.AbsoluteSize
    return math.min(screenSize.X, screenSize.Y) < 600 and math.clamp(math.floor((screenSize.X - 240) / 60), 2, 5)
        or MAX_SLOTS
end
local function getBackpack()
    return player:FindFirstChildOfClass("Backpack")
end
local function getEquippedTool()
    local character = player.Character
    return character and character:FindFirstChildOfClass("Tool")
end
local toolOrder = {} -- stable order of tools
-- Backpack tools + the held tool in a stable order: toolOrder keeps its order across calls, drops tools that
-- are gone and appends new ones. Returns the shared toolOrder table itself.
local function allTools()
    local list = {}
    local backpackInstance = getBackpack()
    if backpackInstance then
        for _, tool in backpackInstance:GetChildren() do
            if tool:IsA("Tool") then
                table.insert(list, tool)
            end
        end
    end
    local equippedTool = getEquippedTool()
    if equippedTool then
        table.insert(list, equippedTool)
    end
    for i = #toolOrder, 1, -1 do
        if not table.find(list, toolOrder[i]) then
            table.remove(toolOrder, i)
        end
    end
    for _, tool in list do
        if not table.find(toolOrder, tool) then
            table.insert(toolOrder, tool)
        end
    end
    return toolOrder
end
local function toggleEquip(tool)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        return
    end
    if getEquippedTool() == tool then
        humanoid:UnequipTools()
    else
        humanoid:EquipTool(tool)
    end
end
local USE_DEFAULT_BACKPACK = false -- false = this custom hotbar + the Inventory panel above it (Roblox's backpack stays hidden)
local barGroups = {} -- [slot] = { tools = {...} } ; identical eggs stack into one slot ("x3"), like Roblox's hotbar
local function stackKey(tool)
    if tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId") then
        return tool
    end -- every character is unique (own power)
    local eggType = tool:GetAttribute("EggType")
    if not eggType then
        return tool
    end
    return eggType
        .. "|"
        .. tostring(tool:GetAttribute("Mutation") or "")
        .. "|"
        .. tostring(tool:GetAttribute("GoldVariant") or "")
        .. "|"
        .. tostring(tool:GetAttribute("UnknownEgg") or "")
end
local function buildGroups()
    local groups, byKey = {}, {}
    for _, tool in allTools() do
        local key = stackKey(tool)
        local group = byKey[key]
        if group then
            table.insert(group.tools, tool)
        else
            group = { tools = { tool } }
            byKey[key] = group
            table.insert(groups, group)
        end
    end
    -- the equipped tool shows first in its stack
    local equippedTool = getEquippedTool()
    if equippedTool then
        for _, group in groups do
            local index = table.find(group.tools, equippedTool)
            if index and index > 1 then
                table.remove(group.tools, index)
                table.insert(group.tools, 1, equippedTool)
            end
        end
    end
    return groups
end
local function groupHas(group, tool)
    return table.find(group.tools, tool) ~= nil
end
local MUTATION_COLORS = {
    Silver = Color3.fromRGB(200, 210, 225),
    Gold = Color3.fromRGB(255, 196, 60),
    Diamond = Color3.fromRGB(90, 220, 255),
    Rainbow = Color3.fromRGB(255, 90, 200),
}
local SLOT_SIZE = 62
-- renderBar's cheap path: same slots, only re-highlight the one whose stack holds the equipped tool.
local function restyleHeldSlots(groups)
    for i, holder in slots do
        local isHeld = groupHas(groups[i], getEquippedTool())
        local button = holder:FindFirstChild("Button")
        if button then
            local edge = button:FindFirstChild("Edge")
            if edge then
                edge.Color = isHeld and Color3.fromRGB(255, 255, 255)
                    or (button:GetAttribute("EdgeColor") or Color3.fromRGB(0, 0, 0))
                edge.Thickness = isHeld and 2.5 or 1.5
            end
            button.BackgroundTransparency = isHeld and 0.15 or 0.35
        end
    end
end
-- One hotbar slot: holder + button, mutation edge/tag, icon, slot number and stack count, equip/hover handlers.
local function buildSlot(slotIndex, group, signatures)
    local tool = group.tools[1]
    local _name, _rarity = describeTool(tool)
    local isHeld = groupHas(group, getEquippedTool())
    local mutation = tool:GetAttribute("Mutation")
    local holder = create("Frame", {
        LayoutOrder = slotIndex,
        Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
        BackgroundTransparency = 1,
        ZIndex = 6,
    }, hotbar)
    local button = create("TextButton", {
        Name = "Button",
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.fromRGB(20, 20, 24),
        BackgroundTransparency = isHeld and 0.15 or 0.35,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 6,
    }, holder)
    create("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
    local edgeColor = mutation and (MUTATION_COLORS[mutation] or Color3.new(1, 1, 1)) or Color3.fromRGB(0, 0, 0)
    button:SetAttribute("EdgeColor", edgeColor)
    local edge = create("UIStroke", {
        Name = "Edge",
        Color = isHeld and Color3.new(1, 1, 1) or edgeColor,
        Thickness = isHeld and 2.5 or 1.5,
        Transparency = 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, button)
    if mutation == "Rainbow" then
        create("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
                ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 60)),
                ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 230, 120)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 150, 255)),
            }),
        }, edge)
    end
    local icon = create("Frame", {
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.new(1, -12, 1, -12),
        BackgroundTransparency = 1,
        ZIndex = 7,
    }, button)
    local previewImage = buildPreview(tool, icon)
    if previewImage then
        previewImage.ZIndex = 7
    end
    -- slot number (top-left) and stack count (bottom-right), white with a thin outline like Roblox
    local slotNumberLabel = create("TextLabel", {
        Position = UDim2.fromOffset(4, 1),
        Size = UDim2.fromOffset(14, 14),
        BackgroundTransparency = 1,
        Text = tostring(slotIndex),
        Font = Enum.Font.GothamBold,
        TextSize = 12,
        TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 9,
    }, button)
    create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.3 }, slotNumberLabel)
    if #group.tools > 1 then
        local stackCountLabel = create("TextLabel", {
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -3, 1, -1),
            Size = UDim2.fromOffset(30, 16),
            BackgroundTransparency = 1,
            Text = "x" .. #group.tools,
            Font = Enum.Font.GothamBold,
            TextSize = 13,
            TextColor3 = Color3.new(1, 1, 1),
            TextXAlignment = Enum.TextXAlignment.Right,
            ZIndex = 9,
        }, button)
        create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.2, Transparency = 0.2 }, stackCountLabel)
    end
    if mutation then
        local mutationTag = create("TextLabel", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0, 0),
            Size = UDim2.fromOffset(0, 11),
            AutomaticSize = Enum.AutomaticSize.X,
            BackgroundColor3 = MUTATION_COLORS[mutation] or Color3.new(1, 1, 1),
            Text = " " .. string.upper(mutation) .. " ",
            Font = Enum.Font.GothamBold,
            TextSize = 8,
            TextColor3 = Color3.new(0, 0, 0),
            ZIndex = 10,
        }, button)
        create("UICorner", { CornerRadius = UDim.new(0, 3) }, mutationTag)
        if mutation == "Rainbow" then
            create("UIGradient", {
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 60)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 150, 255)),
                }),
            }, mutationTag)
        end
        local edgeGradient = edge:FindFirstChildOfClass("UIGradient")
        if edgeGradient then
            task.spawn(function()
                local startTime = os.clock()
                while button.Parent do
                    edgeGradient.Rotation = ((os.clock() - startTime) * 120) % 360
                    task.wait(0.03)
                end
            end)
        end
    end
    button.Activated:Connect(function()
        toggleEquip(group.tools[1])
    end)
    button.MouseEnter:Connect(function()
        tween(button, 0.08, { BackgroundTransparency = 0.1 })
    end)
    button.MouseLeave:Connect(function()
        tween(button, 0.08, { BackgroundTransparency = groupHas(group, getEquippedTool()) and 0.15 or 0.35 })
    end)
    holder:SetAttribute("ToolRef", tostring(tool))
    holder:SetAttribute("Sig", signatures[slotIndex])
    table.insert(slots, holder)
end
-- Rebuilds the hotbar slots from buildGroups(). If the slot signatures (first tool + stack size) are unchanged,
-- it only restyles which slot is held instead of rebuilding (cheap path, runs on every refresh tick).
local function renderBar()
    if USE_DEFAULT_BACKPACK then
        hotbar.Visible = false
        for _, slot in slots do
            slot:Destroy()
        end
        table.clear(slots)
        return
    end
    local groups = buildGroups()
    local slotCount = math.min(#groups, visibleSlotCount())
    -- reuse the slots when nothing changed except which one is held
    local signatures = {}
    for i = 1, slotCount do
        local group = groups[i]
        signatures[i] = tostring(group.tools[1]) .. ":" .. #group.tools
    end
    local canReuse = #slots == slotCount
    if canReuse then
        for i, holder in slots do
            if holder:GetAttribute("Sig") ~= signatures[i] then
                canReuse = false
                break
            end
        end
    end
    barGroups = groups
    if canReuse then
        restyleHeldSlots(groups)
        hotbar.Visible = slotCount > 0
        return
    end
    for _, slot in slots do
        slot:Destroy()
    end
    table.clear(slots)
    hotbar.Visible = slotCount > 0
    trayShadow.Visible = false
    traySkin.Visible = false
    for _, child in hotbar:GetChildren() do
        if child:IsA("UIStroke") then
            child.Enabled = false
        end
    end -- no frame around the whole bar (Roblox style)
    for i = 1, slotCount do
        buildSlot(i, groups[i], signatures)
    end
end
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed or USE_DEFAULT_BACKPACK then
        return
    end
    local slotIndex = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
    if slotIndex >= 1 and slotIndex <= MAX_SLOTS then
        local group = buildGroups()[slotIndex]
        if group then
            toggleEquip(group.tools[1])
        end
    end
end)

-- ===== 4. Drag items onto the hotbar =====
-- Backpack cards (and hotbar slots) can be dragged onto a hotbar slot: the item takes that slot (others shift).
-- A tap without dragging equips the item, so an egg can go straight into an incubator.
local function slotIndexAt(position)
    -- input positions and AbsolutePosition share the same space (below the top-bar inset); a little slack makes drops easy
    for i, holder in slots do
        local absPosition, absSize = holder.AbsolutePosition, holder.AbsoluteSize
        if
            position.X >= absPosition.X - 6
            and position.X <= absPosition.X + absSize.X + 6
            and position.Y >= absPosition.Y - 12
            and position.Y <= absPosition.Y + absSize.Y + 12
        then
            return i
        end
    end
end
local function placeInSlot(tool, slotIndex)
    allTools()
    local currentIndex = table.find(toolOrder, tool)
    if currentIndex then
        table.remove(toolOrder, currentIndex)
    end
    -- slots are stacks now: put the item just before the first item of the stack in slot i
    local stackHead = barGroups[slotIndex] and barGroups[slotIndex].tools[1]
    local insertAt = stackHead and table.find(toolOrder, stackHead) or (#toolOrder + 1)
    table.insert(toolOrder, math.clamp(insertAt, 1, #toolOrder + 1), tool)
    for _, slot in slots do
        slot:SetAttribute("ToolRef", "")
    end -- force a rebuild
    renderBar()
end
local activeDrag = nil
-- Only one drag at a time (activeDrag). The ghost appears after 8 px of movement; releasing over a slot calls
-- placeInSlot, releasing without having moved calls onTap.
local function startDrag(tool, input, onTap)
    if activeDrag then
        return
    end
    local startPos = Vector2.new(input.Position.X, input.Position.Y)
    local ghost, moved
    activeDrag = { tool = tool }
    local function toGuiOffset(screenPosition)
        return UDim2.fromOffset(screenPosition.X - gui.AbsolutePosition.X, screenPosition.Y - gui.AbsolutePosition.Y)
    end
    local moveConn, endConn
    moveConn = UserInputService.InputChanged:Connect(function(moveInput)
        if
            moveInput.UserInputType ~= Enum.UserInputType.MouseMovement
            and moveInput.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        local position = Vector2.new(moveInput.Position.X, moveInput.Position.Y)
        activeDrag.last = position
        if not moved and (position - startPos).Magnitude > 8 then
            moved = true
            ghost = create("Frame", {
                Name = "DragGhost",
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(84, 84),
                BackgroundColor3 = Color3.fromRGB(48, 38, 60),
                BackgroundTransparency = 0.15,
                BorderSizePixel = 0,
                ZIndex = 60,
            }, gui)
            addStroke(ghost, 3, GOLD)
            local ghostIcon =
                create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 61 }, ghost)
            buildPreview(tool, ghostIcon).ZIndex = 61
        end
        if ghost then
            ghost.Position = toGuiOffset(position)
            local hoverSlot = slotIndexAt(position)
            for slotIndex, holder in slots do
                local button = holder:FindFirstChild("Button")
                if button then
                    button.Position = UDim2.fromOffset(0, slotIndex == hoverSlot and -8 or 0)
                end
            end
        end
    end)
    endConn = UserInputService.InputEnded:Connect(function(endInput)
        if
            endInput.UserInputType ~= Enum.UserInputType.MouseButton1
            and endInput.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        moveConn:Disconnect()
        endConn:Disconnect()
        local lastPosition = activeDrag and activeDrag.last
        activeDrag = nil
        if ghost then
            ghost:Destroy()
            local hoverSlot = slotIndexAt(lastPosition or Vector2.new(endInput.Position.X, endInput.Position.Y))
            if hoverSlot and tool.Parent then
                placeInSlot(tool, hoverSlot)
                UISound.Play("Open")
            else
                renderBar()
            end
        elseif onTap then
            onTap()
        end
    end)
end

-- ===== 5. Legacy sell bag ("EggBag"), Backpack button, quotes and selling =====
-- The big bag panel is retired (setBagOpen forwards to the Inventory panel), but it is still built, and its
-- quote cache, snapshot handling, sellCharacters and showPopup are shared with the Inventory panel.
local sellEggRemote = ReplicatedStorage:WaitForChild("SellEgg", 10)
local inventoryRequest = ReplicatedStorage:WaitForChild("CharacterInventory"):WaitForChild("InventoryRequest")
local inventoryEvent = ReplicatedStorage.CharacterInventory:WaitForChild("InventoryEvent")
-- bag state: tap-twice confirmation for single characters (armedTool) and for SELL ALL characters (bulkIds),
-- each valid for 4 s; `selling` blocks overlapping sell requests
local selectedTab = "Eggs"
local armedTool, armedUntil = nil, 0
local bulkIds, bulkUntil = nil, 0
local selling = false
local rightButtons = create("Frame", {
    Name = "RightButtons",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.new(1, -8, 0, 250),
    Size = UDim2.fromOffset(150, 64),
    BackgroundTransparency = 1,
}, gui)
local bagButton = create("TextButton", {
    Name = "BagButton",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.fromScale(1, 0),
    Size = UDim2.fromOffset(56, 62),
    BackgroundColor3 = Color3.fromRGB(255, 196, 60),
    Text = "",
    AutoButtonColor = false,
}, rightButtons)
addCorner(bagButton, UDim.new(0, 16))
addStroke(bagButton, 3)

require(game:GetService("ReplicatedStorage"):WaitForChild("PixelIcon")).build(
    bagButton,
    "bag",
    { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(1, -12, 1, -20) }
)
create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 1),
    Position = UDim2.new(0.5, 0, 1, -2),
    Size = UDim2.new(1, 0, 0, 16),
    BackgroundTransparency = 1,
    Text = "BACKPACK",
    FontFace = FONT,
    TextSize = 9,
    TextColor3 = Color3.new(1, 1, 1),
}, bagButton)
local bagBadge = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(1, -4, 0, 4),
    Size = UDim2.fromOffset(24, 24),
    BackgroundColor3 = Color3.fromRGB(232, 69, 44),
    Text = "0",
    FontFace = FONT,
    TextSize = 14,
    TextColor3 = Color3.new(1, 1, 1),
    Visible = false,
}, bagButton)
addCorner(bagBadge, UDim.new(1, 0))
addStroke(bagBadge, 2)
-- phones: the EGGS button would sit on the jump button at y=250, so shrink it and stack it right under the settings gear
local rightScale = create("UIScale", {}, rightButtons)
local function layoutRightButtons()
    local screenSize = gui.AbsoluteSize
    if screenSize.Y <= 0 then
        return
    end
    local scale = phoneScale()
    rightScale.Scale = scale
    if scale < 1 then
        local menuScale = math.min(1, screenSize.X / 600, screenSize.Y / 560)
        rightButtons.Position = UDim2.new(1, -10, 0, 20 + 104 * menuScale + (56 + 10) * scale)
    else
        rightButtons.Position = UDim2.new(1, -8, 0, 250)
    end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutRightButtons)
task.defer(layoutRightButtons)

local bagPanel = create("Frame", {
    Name = "EggBag",
    Active = true,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(620, 470),
    BackgroundColor3 = PLATE,
    Visible = false,
    ZIndex = 5,
}, gui)
addStroke(bagPanel, 4)
addStuds(bagPanel, 28, 0.82)
local bagShadow = create("Frame", {
    Name = "EggBagShadow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 10, 0.5, 10),
    Size = UDim2.fromOffset(620, 470),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 4,
}, gui)
create("UISizeConstraint", { MaxSize = Vector2.new(620, 470) }, bagShadow)
bagPanel:GetPropertyChangedSignal("Visible"):Connect(function()
    bagOpen = bagPanel.Visible
    bagShadow.Visible = bagOpen
    gui.DisplayOrder = bagOpen and 60 or 40
    renderBar()
end)
create("UISizeConstraint", { MaxSize = Vector2.new(620, 470) }, bagPanel)

local bagScale = create("UIScale", {}, bagPanel)
local bagShadowScale = create("UIScale", {}, bagShadow)
bagScale:GetPropertyChangedSignal("Scale"):Connect(function()
    bagShadowScale.Scale = bagScale.Scale
end)
local bagHeader = create("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 62),
    BackgroundColor3 = Color3.fromRGB(240, 110, 20),
    BorderSizePixel = 0,
    ZIndex = 6,
}, bagPanel)
addStuds(bagHeader, 26, 0.1)
create("Frame", {
    Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, 4),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BorderSizePixel = 0,
    ZIndex = 8,
}, bagHeader)
require(game:GetService("ReplicatedStorage"):WaitForChild("PixelIcon")).build(bagHeader, "bag", {
    AnchorPoint = Vector2.new(0, 0.5),
    Position = UDim2.new(0, 16, 0.5, 0),
    Size = UDim2.fromOffset(40, 40),
    ZIndex = 7,
})

local bagTitle = create("TextLabel", {
    Position = UDim2.fromOffset(66, 0),
    Size = UDim2.new(1, -140, 1, 0),
    BackgroundTransparency = 1,
    Name = "Title",
    Text = "SELL ITEMS",
    FontFace = FONT,
    TextSize = 28,
    TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
}, bagHeader)
addStroke(bagTitle, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
local bagCloseButton = create("TextButton", {
    Name = "Close",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -14, 0.5, 0),
    Size = UDim2.fromOffset(44, 44),
    BackgroundColor3 = Color3.fromRGB(226, 50, 44),
    Text = "X",
    FontFace = FONT,
    TextSize = 28,
    TextColor3 = Color3.new(1, 1, 1),
    ZIndex = 7,
}, bagHeader)
create(
    "UIStroke",
    { Color = Color3.new(0, 0, 0), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
    bagCloseButton
)
addCorner(bagCloseButton, UDim.new(0, 12))
addStroke(bagCloseButton, 3)
local bagTabs = create("Frame", {
    Name = "Tabs",
    Position = UDim2.fromOffset(16, 72),
    Size = UDim2.new(1, -32, 0, 36),
    BackgroundTransparency = 1,
    ZIndex = 6,
}, bagPanel)
local bagTabButtons = {}
for i, name in { "Eggs", "Characters" } do
    local tabButton = create("TextButton", {
        Name = name,
        Position = UDim2.new((i - 1) * 0.5, 0, 0, 0),
        Size = UDim2.new(0.5, -6, 1, 0),
        BackgroundColor3 = PLATE,
        BorderSizePixel = 0,
        Text = string.upper(name),
        FontFace = FONT,
        TextSize = 19,
        TextColor3 = CREAM,
        ZIndex = 7,
    }, bagTabs)
    addStroke(tabButton, 2)
    bagTabButtons[name] = tabButton
end
local bagGrid = create("ScrollingFrame", {
    Name = "Items",
    Position = UDim2.fromOffset(16, 122),
    Size = UDim2.new(1, -32, 1, -198),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 6,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(),
    ZIndex = 6,
}, bagPanel)
local bagGridLayout = create("UIGridLayout", {
    CellSize = UDim2.fromOffset(134, 184),
    CellPadding = UDim2.fromOffset(10, 10),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, bagGrid)
create("TextLabel", {
    Name = "DragHint",
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -70, 0.5, 0),
    Size = UDim2.fromOffset(230, 40),
    BackgroundTransparency = 1,
    Text = "Tap an item to hold it",
    FontFace = BOLD,
    TextSize = 13,
    TextWrapped = true,
    TextColor3 = Color3.new(1, 1, 1),
    TextXAlignment = Enum.TextXAlignment.Right,
    ZIndex = 7,
}, bagHeader)
local bagEmptyLabel = create("TextLabel", {
    Name = "Empty",
    Position = UDim2.fromOffset(16, 122),
    Size = UDim2.new(1, -32, 1, -198),
    BackgroundTransparency = 1,
    Text = "No eggs yet — grab some from the river!",
    FontFace = FONT,
    TextSize = 22,
    TextColor3 = Color3.fromRGB(200, 185, 205),
    ZIndex = 6,
}, bagPanel)
local bagFooter = create("Frame", {
    Name = "Footer",
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 16, 1, -14),
    Size = UDim2.new(1, -32, 0, 56),
    BackgroundTransparency = 1,
    ZIndex = 6,
}, bagPanel)
local bagTotalLabel = create("TextLabel", {
    Size = UDim2.new(0.5, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "",
    FontFace = FONT,
    TextSize = 20,
    TextColor3 = CREAM,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 7,
}, bagFooter)
local sellAllButton = create("TextButton", {
    Name = "SellAll",
    AnchorPoint = Vector2.new(1, 0),
    Position = UDim2.fromScale(1, 0),
    Size = UDim2.fromOffset(200, 52),
    BackgroundColor3 = Color3.fromRGB(92, 192, 70),
    Text = "SELL ALL",
    FontFace = FONT,
    TextSize = 24,
    TextColor3 = Color3.new(1, 1, 1),
    ZIndex = 7,
}, bagFooter)
addCorner(sellAllButton, UDim.new(0, 14))
addStroke(sellAllButton, 3)
create(
    "UIStroke",
    { Color = Color3.new(0, 0, 0), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual },
    sellAllButton
)
local function bagItems(kind)
    local list = {}
    for _, tool in allTools() do
        if getCategory(tool) == kind then
            table.insert(list, tool)
        end
    end
    return list
end
local function bagCount()
    return #bagItems("Eggs") + #bagItems("Characters")
end
local sellQuotes = setmetatable({}, { __mode = "k" })
local characterItems = {}
local characterLoaded = false
local fetchingCharacters = false
local onQuote
-- characterItems[itemId] = server record ({ id, sellValue, power, income, ... }) from the latest snapshot
local function applySnapshot(snapshot)
    if type(snapshot) ~= "table" then
        return
    end
    characterItems = {}
    for _, item in snapshot.items or {} do
        characterItems[item.id] = item
    end
    characterLoaded = true
    if onQuote then
        onQuote()
    end
end
local function fetchCharacters()
    if fetchingCharacters then
        return
    end
    fetchingCharacters = true
    task.spawn(function()
        local ok, response = pcall(inventoryRequest.InvokeServer, inventoryRequest, "Fetch")
        fetchingCharacters = false
        if ok and type(response) == "table" and response.ok then
            applySnapshot(response.snapshot)
        end
    end)
end
inventoryEvent.OnClientEvent:Connect(function(action, snapshot)
    if action == "Snapshot" then
        applySnapshot(snapshot)
    end
end)
-- number = sell price, false = can't be sold, nil = still loading. An egg quote is requested once per tool and
-- cached; onQuote re-renders when it arrives.
local function getSellQuote(tool)
    if getCategory(tool) == "Characters" then
        if not characterLoaded then
            return nil
        end
        local item = characterItems[tool:GetAttribute("ItemId")]
        return item and item.sellValue or false
    end
    if sellQuotes[tool] == nil then
        sellQuotes[tool] = "wait"
        task.spawn(function()
            local ok, value = pcall(sellEggRemote.InvokeServer, sellEggRemote, "Quote", tool)
            sellQuotes[tool] = (ok and type(value) == "number") and value or false
            if onQuote then
                onQuote()
            end
        end)
    end
    if sellQuotes[tool] == "wait" then
        return nil
    end
    return sellQuotes[tool]
end
local function showPopup(text, color)
    local label = create("TextLabel", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.45),
        Size = UDim2.fromOffset(400, 50),
        BackgroundTransparency = 1,
        Text = text,
        FontFace = FONT,
        TextSize = 34,
        TextColor3 = color or Color3.fromRGB(130, 240, 110),
        ZIndex = 20,
    }, gui)
    addStroke(label, 3).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    tween(label, 0.9, { Position = UDim2.fromScale(0.5, 0.38), TextTransparency = 1 })
    task.delay(1, function()
        label:Destroy()
    end)
end
local renderBag
local setBagOpen -- defined below; cards use it to close the bag after a tap-to-hold
local inventoryPanel = {} -- the Inventory panel above the hotbar (built further down); the Backpack button opens it
local function sellCharacters(action, payload)
    local ok, response = pcall(inventoryRequest.InvokeServer, inventoryRequest, action, payload)
    if not ok or type(response) ~= "table" then
        showPopup("Couldn't sell. Try again.", Color3.fromRGB(255, 120, 100))
        return
    end
    if response.snapshot then
        applySnapshot(response.snapshot)
    end
    if response.ok then
        local decoded, summary =
            pcall(game:GetService("HttpService").JSONDecode, game:GetService("HttpService"), response.message)
        if decoded then
            showPopup("+" .. formatMoney(summary.cash) .. "  (" .. summary.count .. " characters)")
        end
    else
        showPopup(response.message or "Couldn't sell.", Color3.fromRGB(255, 120, 100))
    end
end
-- One legacy bag card: preview (drag / tap to hold), name, rarity, character stats and a SELL button
-- (characters need a second tap within 4 s to confirm).
local function buildBagCard(index, tool, name, rarity, quoteValue, canSell, isCharacters)
    local card = create("Frame", {
        Name = "Item" .. index,
        LayoutOrder = index,
        BackgroundColor3 = Color3.fromRGB(26, 38, 46),
        BorderSizePixel = 0,
        ZIndex = 7,
    }, bagGrid)
    card:SetAttribute("ItemId", tool:GetAttribute("ItemId"))
    card:SetAttribute("Category", selectedTab)
    addStroke(card, 3, BLACK)
    local cardTop = create("Frame", {
        Size = UDim2.new(1, 0, 0, 96),
        BackgroundColor3 = RARITY_COLORS[rarity] or Color3.fromRGB(190, 195, 205),
        BorderSizePixel = 0,
        ZIndex = 7,
    }, card)
    addStuds(cardTop, 20, 0.55)
    create("Frame", {
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = BLACK,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, cardTop)
    local iconFrame = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 8 }, cardTop)
    buildPreview(tool, iconFrame).ZIndex = 8
    -- drag the picture onto a hotbar slot, or tap it to hold the item
    local grabButton = create("TextButton", {
        Name = "Grab",
        Size = UDim2.new(1, 0, 0, 134),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        ZIndex = 9,
    }, card)
    grabButton.InputBegan:Connect(function(input)
        if
            input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch
        then
            return
        end
        startDrag(tool, input, function()
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and tool.Parent then
                local toolIndex = table.find(allTools(), tool)
                if not toolIndex or toolIndex > visibleSlotCount() then
                    placeInSlot(tool, 1)
                end
                humanoid:EquipTool(tool)
                setBagOpen(false)
            end
        end)
    end)
    create("TextLabel", {
        Name = "ItemName",
        Position = UDim2.fromOffset(6, 98),
        Size = UDim2.new(1, -12, 0, 20),
        BackgroundTransparency = 1,
        Text = name,
        FontFace = FONT,
        TextScaled = true,
        TextColor3 = Color3.new(1, 1, 1),
        ZIndex = 8,
    }, card)
    create("TextLabel", {
        Position = UDim2.fromOffset(6, 119),
        Size = UDim2.new(1, -12, 0, 14),
        BackgroundTransparency = 1,
        Text = string.upper(rarity or ""),
        FontFace = BOLD,
        TextScaled = true,
        TextColor3 = RARITY_COLORS[rarity] or Color3.new(1, 1, 1),
        ZIndex = 8,
    }, card)
    if isCharacters then
        local record = characterItems[tool:GetAttribute("ItemId")]
        local power = record and record.power or tool:GetAttribute("Power") or 0
        local income = record and record.income or tool:GetAttribute("IncomePerSecond") or 0
        create("TextLabel", {
            Name = "Stats",
            Position = UDim2.fromOffset(5, 136),
            Size = UDim2.new(1, -10, 0, 18),
            BackgroundTransparency = 1,
            Text = "PWR " .. formatMoney(power):sub(2) .. " • " .. formatMoney(income) .. "/s",
            FontFace = BOLD,
            TextScaled = true,
            TextColor3 = CREAM,
            ZIndex = 8,
        }, card)
    end
    local isConfirming = isCharacters and armedTool == tool and os.clock() < armedUntil
    local sellButton = create("TextButton", {
        Name = "Sell",
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -6),
        Size = UDim2.new(1, -12, 0, 40),
        BackgroundColor3 = canSell and Color3.fromRGB(92, 192, 70) or Color3.fromRGB(150, 140, 150),
        Text = canSell and ((isConfirming and "CONFIRM " or "SELL ") .. formatMoney(quoteValue))
            or (quoteValue == false and "CAN'T SELL" or "…"),
        FontFace = FONT,
        TextSize = 14,
        TextColor3 = Color3.new(1, 1, 1),
        AutoButtonColor = canSell,
        Interactable = canSell,
        ZIndex = 8,
    }, card)
    addCorner(sellButton, UDim.new(0, 9))
    addStroke(sellButton, 2)
    sellButton.Activated:Connect(function()
        if not canSell or selling then
            return
        end
        if isCharacters then
            if armedTool ~= tool or os.clock() >= armedUntil then
                armedTool = tool
                armedUntil = os.clock() + 4
                bulkIds = nil
                renderBag()
                task.delay(4, function()
                    if armedTool == tool then
                        armedTool = nil
                        if bagPanel.Visible then
                            renderBag()
                        end
                    end
                end)
                return
            end
            selling = true
            armedTool = nil
            sellCharacters("SellBackpack", { id = tool:GetAttribute("ItemId") })
        else
            selling = true
            local success, ok, result = pcall(sellEggRemote.InvokeServer, sellEggRemote, "Sell", tool)
            if success and ok then
                showPopup("+" .. formatMoney(result))
            else
                showPopup(tostring(success and result or "Couldn't sell."), Color3.fromRGB(255, 120, 100))
            end
        end
        selling = false
    end)
end
renderBag = function()
    for _, child in bagGrid:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    local isCharacters = selectedTab == "Characters"
    local items = bagItems(selectedTab)
    local totalValue, sellableCount = 0, 0
    bagEmptyLabel.Visible = #items == 0
    bagEmptyLabel.Text = isCharacters and "No characters in your backpack — hatch an egg first!"
        or "No eggs yet — grab some from the river!"
    bagGridLayout.CellSize = UDim2.fromOffset(134, isCharacters and 208 or 184)
    for tabName, tabButton in bagTabButtons do
        tabButton.BackgroundColor3 = tabName == selectedTab and GOLD or PLATE
        tabButton.TextColor3 = tabName == selectedTab and INK or CREAM
    end
    local itemCount = bagCount()
    bagBadge.Visible = itemCount > 0
    bagBadge.Text = tostring(itemCount)
    for i, tool in items do
        local name, rarity = describeTool(tool)
        local quoteValue = getSellQuote(tool)
        local canSell = type(quoteValue) == "number"
        if canSell then
            totalValue += quoteValue
            sellableCount += 1
        end
        buildBagCard(i, tool, name, rarity, quoteValue, canSell, isCharacters)
    end
    bagTotalLabel.Text = #items > 0 and ("Total value  " .. formatMoney(totalValue)) or ""
    sellAllButton.Text = isCharacters
            and (bulkIds and os.clock() < bulkUntil and "CONFIRM ALL?" or "SELL ALL CHARACTERS")
        or "SELL ALL EGGS"
    sellAllButton.TextSize = isCharacters and 17 or 21
    sellAllButton.Interactable = sellableCount > 0
    sellAllButton.AutoButtonColor = sellableCount > 0
end
sellAllButton.Activated:Connect(function()
    if selling then
        return
    end
    if selectedTab == "Characters" then
        if not bulkIds or os.clock() >= bulkUntil then
            bulkIds = {}
            for _, tool in bagItems("Characters") do
                if type(getSellQuote(tool)) == "number" then
                    table.insert(bulkIds, tool:GetAttribute("ItemId"))
                end
            end
            if #bulkIds == 0 then
                bulkIds = nil
                return
            end
            bulkUntil = os.clock() + 4
            armedTool = nil
            renderBag()
            local armedDeadline = bulkUntil
            task.delay(4, function()
                if bulkUntil == armedDeadline then
                    bulkIds = nil
                    if bagPanel.Visible then
                        renderBag()
                    end
                end
            end)
            return
        end
        local ids = bulkIds
        bulkIds = nil
        selling = true
        sellCharacters("SellBackpackAll", { ids = ids })
    else
        selling = true
        local success, ok, result, soldCount = pcall(sellEggRemote.InvokeServer, sellEggRemote, "SellAll")
        if success and ok then
            showPopup("+" .. formatMoney(result) .. "  (" .. soldCount .. " eggs)")
        else
            showPopup(tostring(success and result or "Couldn't sell."), Color3.fromRGB(255, 120, 100))
        end
    end
    selling = false
    renderBag()
end)
for tabName, tabButton in bagTabButtons do
    tabButton.Activated:Connect(function()
        selectedTab = tabName
        armedTool = nil
        bulkIds = nil
        bagGrid.CanvasPosition = Vector2.zero
        if tabName == "Characters" then
            fetchCharacters()
        end
        renderBag()
    end)
end
local quoteRefreshPending = false
-- debounced bag re-render after quotes arrive (replaced by the Inventory panel's version in section 6)
onQuote = function()
    if quoteRefreshPending then
        return
    end
    quoteRefreshPending = true
    task.delay(0.1, function()
        quoteRefreshPending = false
        if bagPanel.Visible then
            renderBag()
        end
    end)
end
-- Shrinks the bag to fit small (phone) screens; desktop keeps the full 620x470 panel.
local function bagFitScale()
    local screenSize = gui.AbsoluteSize
    if screenSize.X <= 0 or screenSize.Y <= 0 then
        return 1
    end
    return math.clamp(math.min(1, (screenSize.X - 24) / 620, (screenSize.Y - 24) / 470), 0.4, 1)
end
setBagOpen = function(shouldOpen)
    if inventoryPanel.setOpen then
        return inventoryPanel.setOpen(shouldOpen)
    end -- old big backpack panel is retired; Inventory replaces it
    if bagPanel.Visible ~= shouldOpen then
        UISound.Play(shouldOpen and "Open" or "Close")
    end
    if shouldOpen then
        bagPanel.Visible = true
        fetchCharacters()
        bagScale.Scale = bagFitScale() * 0.85
        tween(bagScale, 0.25, { Scale = bagFitScale() }, Enum.EasingStyle.Back)
        renderBag()
    else
        armedTool = nil
        bulkIds = nil
        bagPanel.Visible = false
    end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    if bagPanel.Visible then
        bagScale.Scale = bagFitScale()
    end
end)
bagButton.Activated:Connect(function()
    setBagOpen(not bagPanel.Visible)
end)
bagCloseButton.Activated:Connect(function()
    setBagOpen(false)
end)
bagButton.MouseEnter:Connect(function()
    tween(bagButton, 0.1, { Rotation = -6 })
end)
bagButton.MouseLeave:Connect(function()
    tween(bagButton, 0.1, { Rotation = 0 })
end)

-- ===== 6. Inventory panel: Roblox-style grid that opens above the hotbar (game style) =====
-- Tabs (All / Eggs / Characters), rarity + mutation filters, search, drag items onto the hotbar, tap to hold,
-- SELL mode (tap twice to sell). Opens with the Backpack button or the ` key.
do
    local RARITY_FILTERS = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Limited" }
    local MUTATION_FILTERS = { "Any", "Mutated", "Silver", "Gold", "Diamond", "Rainbow" }
    local INVENTORY_MUTATION_COLORS = {
        Silver = Color3.fromRGB(200, 210, 225),
        Gold = Color3.fromRGB(255, 196, 60),
        Diamond = Color3.fromRGB(90, 220, 255),
        Rainbow = Color3.fromRGB(255, 90, 200),
    }
    local RAINBOW_GRADIENT = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
        ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 230, 60)),
        ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 230, 120)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 150, 255)),
    })
    local activeTab, rarityIndex, mutationIndex, searchQuery, sellMode, armedItem = "All", 1, 1, "", false, nil
    local PANEL_WIDTH, PANEL_HEIGHT = 660, 340
    local inventoryFrame = create("Frame", {
        Name = "Inventory",
        Active = true,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -122),
        Size = UDim2.fromOffset(PANEL_WIDTH, PANEL_HEIGHT),
        BackgroundColor3 = PLATE,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 20,
    }, gui)
    addStroke(inventoryFrame, 4, BLACK)
    addStuds(inventoryFrame, 26, 0.85)
    local inventoryScale = create("UIScale", {}, inventoryFrame)
    local function fitScale()
        local screenSize = gui.AbsoluteSize
        if screenSize.X <= 0 then
            return 1
        end
        return math.clamp(math.min(1, (screenSize.X - 24) / PANEL_WIDTH, (screenSize.Y - 150) / PANEL_HEIGHT), 0.45, 1)
    end
    gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if inventoryFrame.Visible then
            inventoryScale.Scale = fitScale()
        end
    end)
    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = Color3.fromRGB(240, 110, 20),
        BorderSizePixel = 0,
        ZIndex = 21,
    }, inventoryFrame)
    addStuds(header, 22, 0.1)
    create("Frame", {
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 3),
        BackgroundColor3 = BLACK,
        BorderSizePixel = 0,
        ZIndex = 22,
    }, header)
    local titleLabel = create("TextLabel", {
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.fromOffset(160, 46),
        BackgroundTransparency = 1,
        Text = "INVENTORY",
        FontFace = FONT,
        TextSize = 25,
        TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 22,
    }, header)
    addStroke(titleLabel, 2.5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
    local countLabel = create("TextLabel", {
        Position = UDim2.fromOffset(150, 0),
        Size = UDim2.fromOffset(40, 46),
        BackgroundTransparency = 1,
        Text = "",
        FontFace = FONT,
        TextSize = 16,
        TextColor3 = CREAM,
        ZIndex = 22,
    }, header)
    local tabButtons = {}
    for i, tabName in { "All", "Eggs", "Characters" } do
        local tabButton = create("TextButton", {
            Position = UDim2.fromOffset(196 + (i - 1) * 118, 8),
            Size = UDim2.fromOffset(110, 30),
            BackgroundColor3 = PLATE,
            BorderSizePixel = 0,
            Text = string.upper(tabName),
            FontFace = FONT,
            TextSize = 15,
            TextColor3 = CREAM,
            AutoButtonColor = false,
            ZIndex = 22,
        }, header)
        addStroke(tabButton, 2, BLACK)
        tabButtons[tabName] = tabButton
    end
    local closeButton = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(34, 34),
        BackgroundColor3 = Color3.fromRGB(226, 50, 44),
        Text = "X",
        FontFace = FONT,
        TextSize = 20,
        TextColor3 = Color3.new(1, 1, 1),
        ZIndex = 22,
    }, header)
    addStroke(closeButton, 2.5, BLACK)
    local filterRow = create("Frame", {
        Position = UDim2.fromOffset(10, 56),
        Size = UDim2.new(1, -20, 0, 30),
        BackgroundTransparency = 1,
        ZIndex = 21,
    }, inventoryFrame)
    local searchBox = create("TextBox", {
        Size = UDim2.fromOffset(196, 30),
        BackgroundColor3 = Color3.fromRGB(26, 38, 46),
        BorderSizePixel = 0,
        PlaceholderText = "Search…",
        Text = "",
        ClearTextOnFocus = false,
        FontFace = FONT,
        TextSize = 15,
        TextColor3 = Color3.new(1, 1, 1),
        PlaceholderColor3 = Color3.fromRGB(150, 160, 170),
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 22,
    }, filterRow)
    addStroke(searchBox, 2, BLACK)
    create("UIPadding", { PaddingLeft = UDim.new(0, 8) }, searchBox)
    local function createChip(offsetX, width)
        local chipButton = create("TextButton", {
            Position = UDim2.fromOffset(offsetX, 0),
            Size = UDim2.fromOffset(width, 30),
            BackgroundColor3 = Color3.fromRGB(26, 38, 46),
            BorderSizePixel = 0,
            FontFace = FONT,
            TextSize = 14,
            TextColor3 = CREAM,
            AutoButtonColor = false,
            ZIndex = 22,
        }, filterRow)
        addStroke(chipButton, 2, BLACK)
        return chipButton
    end
    local rarityButton = createChip(206, 150)
    local mutationButton = createChip(364, 130)
    local sellModeButton = createChip(502, 138)
    sellModeButton.TextColor3 = Color3.new(1, 1, 1)
    local itemGrid = create("ScrollingFrame", {
        Position = UDim2.fromOffset(10, 96),
        Size = UDim2.new(1, -20, 1, -106),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        ScrollBarImageColor3 = GOLD,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        ZIndex = 21,
    }, inventoryFrame)
    create("UIGridLayout", {
        CellSize = UDim2.fromOffset(86, 98),
        CellPadding = UDim2.fromOffset(9, 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, itemGrid)
    create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 3) }, itemGrid)
    local emptyLabel = create("TextLabel", {
        Position = UDim2.fromOffset(10, 96),
        Size = UDim2.new(1, -20, 1, -106),
        BackgroundTransparency = 1,
        Text = "",
        FontFace = FONT,
        TextSize = 18,
        TextColor3 = Color3.fromRGB(200, 185, 205),
        ZIndex = 21,
    }, inventoryFrame)
    -- tab + rarity + mutation ("Mutated" = any) + case-insensitive plain-text search on "<mutation> <name>"
    local function matchesFilters(tool)
        local kind = getCategory(tool)
        if not kind then
            return false
        end
        if activeTab ~= "All" and kind ~= activeTab then
            return false
        end
        local name, rarity = describeTool(tool)
        local rarityFilter = RARITY_FILTERS[rarityIndex]
        if rarityFilter ~= "All" and rarity ~= rarityFilter then
            return false
        end
        local mutationFilter = MUTATION_FILTERS[mutationIndex]
        local mutation = tool:GetAttribute("Mutation")
        if mutationFilter == "Mutated" and not mutation then
            return false
        end
        if mutationFilter ~= "Any" and mutationFilter ~= "Mutated" and mutation ~= mutationFilter then
            return false
        end
        if searchQuery ~= "" then
            local searchText = ((mutation and (mutation .. " ")) or "") .. name
            if not searchText:lower():find(searchQuery:lower(), 1, true) then
                return false
            end
        end
        return true
    end
    -- tab highlight + rarity / mutation / SELL chip labels and colours
    local function refreshControls()
        for tabName, tabButton in tabButtons do
            tabButton.BackgroundColor3 = tabName == activeTab and GOLD or PLATE
            tabButton.TextColor3 = tabName == activeTab and INK or CREAM
        end
        rarityButton.Text = "RARITY: " .. string.upper(RARITY_FILTERS[rarityIndex])
        mutationButton.Text = MUTATION_FILTERS[mutationIndex] == "Any" and "MUTATION: ANY"
            or string.upper(MUTATION_FILTERS[mutationIndex])
        mutationButton.BackgroundColor3 = INVENTORY_MUTATION_COLORS[MUTATION_FILTERS[mutationIndex]]
                and INVENTORY_MUTATION_COLORS[MUTATION_FILTERS[mutationIndex]]:Lerp(Color3.new(0, 0, 0), 0.45)
            or Color3.fromRGB(26, 38, 46)
        sellModeButton.Text = sellMode and "SELLING: TAP x2" or "SELL ITEMS"
        sellModeButton.BackgroundColor3 = sellMode and Color3.fromRGB(226, 50, 44) or Color3.fromRGB(92, 192, 70)
    end
    local render
    -- One inventory cell: rarity strip, icon, name, mutation tag + animated edge, held highlight, SELL-mode price
    -- and the input handlers (drag / tap to hold, or tap twice within 3 s to sell in SELL mode).
    local function buildCell(index, tool)
        local name, rarity = describeTool(tool)
        local rarityColor = RARITY_COLORS[rarity] or Color3.fromRGB(150, 140, 160)
        local mutation = tool:GetAttribute("Mutation")
        local cell = create(
            "Frame",
            { LayoutOrder = index, BackgroundColor3 = Color3.fromRGB(26, 38, 46), BorderSizePixel = 0, ZIndex = 22 },
            itemGrid
        )
        local cellStroke = addStroke(cell, 2.5, BLACK)
        create("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 4),
            BackgroundColor3 = rarityColor,
            BorderSizePixel = 0,
            ZIndex = 24,
        }, cell)
        local iconFrame = create("Frame", {
            Position = UDim2.fromOffset(5, 5),
            Size = UDim2.new(1, -10, 0, 66),
            BackgroundTransparency = 1,
            ZIndex = 23,
        }, cell)
        buildPreview(tool, iconFrame)
        local nameLabel = create("TextLabel", {
            Position = UDim2.fromOffset(3, 72),
            Size = UDim2.new(1, -6, 0, 20),
            BackgroundTransparency = 1,
            Text = string.upper(name),
            FontFace = FONT,
            TextScaled = true,
            TextColor3 = Color3.new(1, 1, 1),
            ZIndex = 24,
        }, cell)
        create("UITextSizeConstraint", { MaxTextSize = 12 }, nameLabel)
        addStroke(nameLabel, 1.5, BLACK)
        if mutation then
            local mutationTag = create("TextLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0, 0),
                Size = UDim2.fromOffset(0, 14),
                AutomaticSize = Enum.AutomaticSize.X,
                BackgroundColor3 = INVENTORY_MUTATION_COLORS[mutation] or Color3.new(1, 1, 1),
                Text = " " .. string.upper(mutation) .. " ",
                FontFace = FONT,
                TextSize = 11,
                TextColor3 = BLACK,
                ZIndex = 26,
            }, cell)
            create(
                "UIStroke",
                { Color = BLACK, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
                mutationTag
            )
            if mutation == "Rainbow" then
                create("UIGradient", { Color = RAINBOW_GRADIENT }, mutationTag)
            end
            cellStroke.Color = Color3.new(1, 1, 1)
            cellStroke.Thickness = 3
            local edgeGradient = create("UIGradient", {
                Color = mutation == "Rainbow" and RAINBOW_GRADIENT
                    or ColorSequence.new({
                        ColorSequenceKeypoint.new(0, INVENTORY_MUTATION_COLORS[mutation] or Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
                        ColorSequenceKeypoint.new(1, INVENTORY_MUTATION_COLORS[mutation] or Color3.new(1, 1, 1)),
                    }),
            }, cellStroke)
            task.spawn(function()
                local startTime = os.clock()
                while cell.Parent do
                    edgeGradient.Rotation = ((os.clock() - startTime) * 120) % 360
                    task.wait(0.03)
                end
            end)
        end
        if getEquippedTool() == tool then
            cellStroke.Color = GOLD
            cellStroke.Thickness = 4
        end
        if sellMode then
            local quoteValue = getSellQuote(tool)
            local priceLabel = create("TextLabel", {
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.4),
                Size = UDim2.fromOffset(80, 22),
                BackgroundColor3 = armedItem == tool and Color3.fromRGB(226, 50, 44) or Color3.fromRGB(92, 192, 70),
                Text = (armedItem == tool and "CONFIRM " or "") .. (type(quoteValue) == "number" and formatMoney(
                    quoteValue
                ) or (quoteValue == false and "CAN'T" or "…")),
                FontFace = FONT,
                TextSize = 13,
                TextColor3 = Color3.new(1, 1, 1),
                ZIndex = 27,
            }, cell)
            addStroke(priceLabel, 2, BLACK)
        end
        local cellButton = create(
            "TextButton",
            { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 28 },
            cell
        )
        cellButton.MouseEnter:Connect(function()
            tween(cell, 0.08, { Rotation = -3 })
        end)
        cellButton.MouseLeave:Connect(function()
            tween(cell, 0.08, { Rotation = 0 })
        end)
        cellButton.InputBegan:Connect(function(input)
            if sellMode then
                return
            end
            if
                input.UserInputType ~= Enum.UserInputType.MouseButton1
                and input.UserInputType ~= Enum.UserInputType.Touch
            then
                return
            end
            startDrag(tool, input, function()
                if not tool.Parent then
                    return
                end
                local toolIndex = table.find(allTools(), tool)
                if not toolIndex or toolIndex > visibleSlotCount() then
                    placeInSlot(tool, 1)
                end
                toggleEquip(tool)
                task.delay(0.1, function()
                    if inventoryFrame.Visible then
                        render()
                    end
                end)
            end)
        end)
        cellButton.Activated:Connect(function()
            if not sellMode or selling then
                return
            end
            local quoteValue = getSellQuote(tool)
            if type(quoteValue) ~= "number" then
                showPopup("Can't sell that", Color3.fromRGB(255, 120, 100))
                return
            end
            if armedItem ~= tool then
                armedItem = tool
                render()
                task.delay(3, function()
                    if armedItem == tool then
                        armedItem = nil
                        if inventoryFrame.Visible then
                            render()
                        end
                    end
                end)
                return
            end
            armedItem = nil
            selling = true
            if getCategory(tool) == "Characters" then
                sellCharacters("SellBackpack", { id = tool:GetAttribute("ItemId") })
            else
                local ok, sold, earned = pcall(sellEggRemote.InvokeServer, sellEggRemote, "Sell", tool)
                if ok and sold then
                    showPopup("+" .. formatMoney(earned))
                    UISound.Play("CoinChing")
                else
                    showPopup("Couldn't sell", Color3.fromRGB(255, 120, 100))
                end
            end
            selling = false
            task.delay(0.15, function()
                if inventoryFrame.Visible then
                    render()
                end
            end)
        end)
    end
    render = function()
        for _, child in itemGrid:GetChildren() do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        refreshControls()
        local items = {}
        for _, tool in allTools() do
            if matchesFilters(tool) then
                table.insert(items, tool)
            end
        end
        countLabel.Text = tostring(#items)
        emptyLabel.Visible = #items == 0
        emptyLabel.Text = activeTab == "Characters" and "No characters — hatch an egg!"
            or activeTab == "Eggs" and "No eggs — grab some from the river!"
            or "Nothing here yet"
        for i, tool in items do
            buildCell(i, tool)
        end
    end
    for tabName, tabButton in tabButtons do
        tabButton.Activated:Connect(function()
            activeTab = tabName
            armedItem = nil
            if tabName == "Characters" then
                fetchCharacters()
            end
            UISound.Play("Open")
            render()
        end)
    end
    rarityButton.Activated:Connect(function()
        rarityIndex = rarityIndex % #RARITY_FILTERS + 1
        render()
    end)
    mutationButton.Activated:Connect(function()
        mutationIndex = mutationIndex % #MUTATION_FILTERS + 1
        render()
    end)
    sellModeButton.Activated:Connect(function()
        sellMode = not sellMode
        armedItem = nil
        fetchCharacters()
        render()
    end)
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchQuery = searchBox.Text
        render()
    end)
    onQuote = function()
        if inventoryFrame.Visible then
            render()
        end
    end
    local function setInventoryOpen(shouldOpen)
        if shouldOpen and inventoryFrame.Visible then
            shouldOpen = false
        end -- Backpack button toggles
        if shouldOpen == inventoryFrame.Visible then
            return
        end
        UISound.Play(shouldOpen and "Open" or "Close")
        if shouldOpen then
            inventoryFrame.Visible = true
            fetchCharacters()
            render()
            local targetScale = fitScale()
            inventoryScale.Scale = targetScale * 0.85
            inventoryFrame.Position = UDim2.new(0.5, 0, 1, -90)
            tween(inventoryScale, 0.25, { Scale = targetScale }, Enum.EasingStyle.Back)
            tween(inventoryFrame, 0.25, { Position = UDim2.new(0.5, 0, 1, -122) }, Enum.EasingStyle.Back)
        else
            sellMode = false
            armedItem = nil
            inventoryFrame.Visible = false
        end
    end
    inventoryPanel.setOpen = setInventoryOpen
    inventoryPanel.render = render
    closeButton.Activated:Connect(function()
        setInventoryOpen(false)
    end)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.Backquote then
            setInventoryOpen(not inventoryFrame.Visible)
        end
    end)
    -- live refresh while open
    local refreshPending = false
    local function scheduleRefresh()
        if not inventoryFrame.Visible or refreshPending then
            return
        end
        refreshPending = true
        task.delay(0.15, function()
            refreshPending = false
            if inventoryFrame.Visible then
                render()
            end
        end)
    end
    local function watchContainer(container)
        if container then
            container.ChildAdded:Connect(scheduleRefresh)
            container.ChildRemoved:Connect(scheduleRefresh)
        end
    end
    watchContainer(getBackpack())
    player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            watchContainer(child)
        end
    end)
    player.CharacterAdded:Connect(watchContainer)
    watchContainer(player.Character)
end

-- ===== 7. Hotbar hover tooltip: full name, rarity and mutation above the slot =====
do
    local tooltip = create("TextLabel", {
        Name = "HotbarTip",
        AnchorPoint = Vector2.new(0.5, 1),
        Size = UDim2.fromOffset(0, 26),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Color3.fromRGB(20, 16, 28),
        BackgroundTransparency = 0.1,
        Text = "",
        FontFace = FONT,
        TextSize = 16,
        TextColor3 = Color3.new(1, 1, 1),
        RichText = true,
        Visible = false,
        ZIndex = 40,
    }, gui)
    addStroke(tooltip, 2, BLACK)
    create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tooltip)
    RunService.RenderStepped:Connect(function()
        if not hotbar.Visible then
            tooltip.Visible = false
            return
        end
        local mousePosition = UserInputService:GetMouseLocation() - game:GetService("GuiService"):GetGuiInset()
        local slotIndex = slotIndexAt(mousePosition)
        local group = slotIndex and barGroups[slotIndex]
        local tool = group and group.tools[1]
        if not tool then
            tooltip.Visible = false
            return
        end
        local name, rarity = describeTool(tool)
        local mutation = tool:GetAttribute("Mutation")
        local rarityHex = (RARITY_COLORS[rarity] or Color3.new(1, 1, 1)):ToHex()
        tooltip.Text = (mutation and ('<font color="#ffd84a">' .. string.upper(mutation) .. "</font>  ") or "")
            .. name
            .. '  <font color="#'
            .. rarityHex
            .. '">'
            .. string.upper(rarity or "")
            .. "</font>"
        local holder = slots[slotIndex]
        tooltip.Position = UDim2.fromOffset(
            holder.AbsolutePosition.X + holder.AbsoluteSize.X / 2 - gui.AbsolutePosition.X,
            holder.AbsolutePosition.Y - gui.AbsolutePosition.Y - 14
        )
        tooltip.Visible = true
    end)
end

-- ===== 8. Change watchers + hotbar refresh loop =====
-- Backpack/character child changes only set a dirty flag; the loop below re-renders at most every 0.15 s.
local hotbarDirty = true
local function watchForChanges(container)
    if container then
        container.ChildAdded:Connect(function()
            hotbarDirty = true
        end)
        container.ChildRemoved:Connect(function()
            hotbarDirty = true
        end)
    end
end
watchForChanges(getBackpack())
player.ChildAdded:Connect(function(child)
    if child:IsA("Backpack") then
        watchForChanges(child)
        hotbarDirty = true
    end
end)
player.CharacterAdded:Connect(function(child)
    watchForChanges(child)
    hotbarDirty = true
end)
watchForChanges(player.Character)
task.spawn(function()
    while true do
        if hotbarDirty then
            hotbarDirty = false
            renderBar()
            if bagPanel.Visible then
                task.wait(0.25)
                renderBag()
            else
                local itemCount = bagCount()
                bagBadge.Visible = itemCount > 0
                bagBadge.Text = tostring(itemCount)
            end
        end
        task.wait(0.15)
    end
end)

-- ===== 9. Night timer (top centre) =====
-- Replaces the legacy NighttimeHUD / NighttimeStatus guis (disabled here, also when they get re-added).
for _, guiName in { "NighttimeHUD", "NighttimeStatus" } do
    local legacyGui = playerGui:FindFirstChild(guiName)
    if legacyGui then
        legacyGui.Enabled = false
    end
end
playerGui.ChildAdded:Connect(function(child)
    if child.Name == "NighttimeHUD" or child.Name == "NighttimeStatus" then
        task.defer(function()
            child.Enabled = false
        end)
    end
end)
local TimeHUD = ReplicatedStorage:WaitForChild("TimeHUD")
local TimeComponent = require(TimeHUD:WaitForChild("TimeComponent"))
local TimeConfig = require(TimeHUD:WaitForChild("TimeConfig"))
local nightGui = create("ScreenGui", {
    Name = "NightBar",
    ResetOnSpawn = false,
    DisplayOrder = 41,
    ScreenInsets = Enum.ScreenInsets.None,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Global, -- TimeComponent orders its outline layers with global ZIndex
}, playerGui)
local timeHud = TimeComponent.new(nightGui)
timeHud.Root.AnchorPoint = Vector2.new(0.5, 0)
local hudScale = phoneScale()
local bigCountdownLabel = create("TextLabel", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.32),
    Size = UDim2.fromOffset(300, 120),
    BackgroundTransparency = 1,
    Text = "",
    FontFace = FONT,
    TextSize = 110,
    TextColor3 = Color3.fromRGB(255, 60, 60),
    TextTransparency = 1,
}, nightGui)
addStroke(bigCountdownLabel, 5).ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
local bigCountdownScale = create("UIScale", { Scale = hudScale }, bigCountdownLabel)

-- Time HUD: top centre. Phones: as large as fits between the screen centre and the cash panel (top-right);
-- when even the minimum scale would overlap the cash panel, it drops below it instead.
local function getCashUI()
    local moneyDisplay = playerGui:FindFirstChild("MoneyDisplay")
    return moneyDisplay and moneyDisplay:FindFirstChild("CashUI")
end
local function layoutTimeHud()
    local screenSize = nightGui.AbsoluteSize
    if screenSize.X <= 0 or screenSize.Y <= 0 then
        return
    end
    local compact = math.min(screenSize.X, screenSize.Y) < TimeConfig.CompactBreakpoint
    nightGui.ScreenInsets = compact and Enum.ScreenInsets.CoreUISafeInsets or Enum.ScreenInsets.None
    local rootWidth = TimeConfig.RootSize.X
    local scale, top = TimeConfig.Scale.Desktop, TimeConfig.TopMargin
    if compact then
        scale = math.min(TimeConfig.Scale.CompactMax, (screenSize.X - 16) / rootWidth)
        local cashUI = getCashUI()
        if cashUI and cashUI.Visible then
            local origin = nightGui.AbsolutePosition
            local cashLeft = cashUI.AbsolutePosition.X - origin.X
            local fitScale = 2 * (math.min(screenSize.X / 2, cashLeft - screenSize.X / 2) - 8) / rootWidth
            if fitScale >= TimeConfig.Scale.CompactMin then
                scale = math.min(scale, fitScale)
            else
                top = cashUI.AbsolutePosition.Y - origin.Y + cashUI.AbsoluteSize.Y + 6
            end
        end
    end
    timeHud.Scale.Scale = scale
    timeHud.Root.Position = UDim2.new(0.5, 0, 0, top)
end
nightGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTimeHud)
task.spawn(function()
    local moneyDisplay = playerGui:WaitForChild("MoneyDisplay", 30)
    local cashUI = moneyDisplay and moneyDisplay:WaitForChild("CashUI", 30)
    if cashUI then
        cashUI:GetPropertyChangedSignal("AbsolutePosition"):Connect(layoutTimeHud)
        cashUI:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutTimeHud)
        layoutTimeHud()
    end
end)
layoutTimeHud()

-- the bonuses the night event gives (published by NighttimeService, day or night)
local function updateNightBonuses()
    timeHud:SetMultipliers({
        Cash = workspace:GetAttribute("NightBonusCash") or 1,
        Hatch = workspace:GetAttribute("NightBonusHatchSpeed") or 1,
        Luck = workspace:GetAttribute("NightBonusRiverLuck") or 1,
    })
end
for _, attributeName in { "NightBonusCash", "NightBonusHatchSpeed", "NightBonusRiverLuck" } do
    workspace:GetAttributeChangedSignal(attributeName):Connect(updateNightBonuses)
end
updateNightBonuses()

-- re-applies the phone scale to the hotbar and the big countdown (tracks the start-up camera's ViewportSize)
local function rescale()
    hudScale = phoneScale()
    hotbarScale.Scale = hudScale
    bigCountdownScale.Scale = hudScale
    renderBar()
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
local lastCountdownSecond, countdownTween = nil, nil
local function hideBigCountdown()
    lastCountdownSecond = nil
    if countdownTween then
        countdownTween:Cancel()
        countdownTween = nil
    end
    bigCountdownLabel.TextTransparency = 1
    bigCountdownLabel.Text = ""
end
-- last 5 s before night: a big number that pops in once per second
local function updateBigCountdown(secondsLeft)
    local wholeSeconds = math.ceil(secondsLeft)
    if secondsLeft <= 5 and secondsLeft > 0 then
        if wholeSeconds ~= lastCountdownSecond then
            lastCountdownSecond = wholeSeconds
            if countdownTween then
                countdownTween:Cancel()
            end
            bigCountdownLabel.Text = tostring(wholeSeconds)
            bigCountdownLabel.TextTransparency = 0
            bigCountdownLabel.TextSize = 150
            countdownTween = tween(bigCountdownLabel, 0.9, { TextSize = 100, TextTransparency = 0.6 })
        end
    elseif lastCountdownSecond then
        hideBigCountdown()
    end
end
-- Every frame, from the server's night attributes and server time (no local timer). The HUD names the NEXT
-- event: during the day it counts down to the night (Night look), during the night to daylight (Day look).
RunService.RenderStepped:Connect(function()
    local now = workspace:GetServerTimeNow()
    if workspace:GetAttribute("NighttimeActive") then
        timeHud:SetMode("Day")
        timeHud:SetRemainingTime((workspace:GetAttribute("NighttimeEndsAt") or now) - now)
        if lastCountdownSecond then
            hideBigCountdown()
        end
    else
        local secondsLeft = (workspace:GetAttribute("NighttimeNextAt") or now) - now
        timeHud:SetMode("Night")
        timeHud:SetRemainingTime(secondsLeft)
        updateBigCountdown(secondsLeft)
    end
end)

-- ===== 10. Away-earnings popup (PlayerDataService) =====
-- Disabled: `earnings` is hard-wired to nil since OfflineEarningsUI took over, so this never shows anything.
do
    local function showAwayEarnings()
        local earnings = nil -- replaced by OfflineEarningsUI
        if earnings and earnings > 0 then
            local _minutesAway = math.floor((player:GetAttribute("OfflineSeconds") or 0) / 60)
            showPopup("WHILE YOU WERE AWAY: +" .. formatMoney(earnings), Color3.fromRGB(255, 206, 60))
        end
    end
    player:GetAttributeChangedSignal("OfflineEarnings"):Connect(showAwayEarnings)
    task.delay(3, showAwayEarnings)
end

-- ===== 11. Go home: key H + the server's reply (the HOME button itself is GameMenus' left menu) =====
do
    local goHomeRemote = ReplicatedStorage:WaitForChild("GoHome", 10)
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == Enum.KeyCode.H and goHomeRemote then
            goHomeRemote:FireServer()
        end
    end)
    if goHomeRemote then
        goHomeRemote.OnClientEvent:Connect(function(message)
            if message ~= "OK" and message ~= "Wait a moment" then
                showPopup(message, Color3.fromRGB(255, 120, 100))
            end
        end)
    end
end
