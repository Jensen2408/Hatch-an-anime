--[[ ReplicatedStorage.EggLabel  (ModuleScript, client-only)
Clean floating text label for every river egg: name, rarity, price, plus a small Collect hint when near.
Reads data from egg attributes first, then from ReplicatedStorage.CharacterCatalog. No pricing system of its own.
Does not change spawning, river movement, rarity chances or collection. Collection is still the egg's ProximityPrompt.

Start it from a LocalScript:   require(game.ReplicatedStorage.EggLabel).Start()
Eggs are found by CollectionService tag (Config.Tag, default "RiverEgg").
Only eggs with the "RiverEggVisual" attribute set to true get a label.
All labels share one 10 Hz Heartbeat update (EggLabel:_tick) instead of one connection per egg.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local Config = {
    Tag = "RiverEgg",
    PlaytestFree = false, -- hint says "Collect · FREE"; no charges are made either way
    MaxDistance = 110, -- labels hide and pause beyond this
    NearFallbackDistance = 10, -- used only if an egg has no ProximityPrompt
    GuiSize = Vector2.new(210, 138),
    HeightAboveEgg = 0.8, -- studs between the egg's top and the label's bottom
    Font = Enum.Font.FredokaOne, -- swap to the exact font from your mockups if you have it
    Outline = rgb(11, 10, 14),
    PriceFree = rgb(255, 255, 0),
    PriceOk = rgb(20, 255, 0),
    PriceTooMuch = rgb(255, 16, 16),
    CurrencyStats = { "Money", "Cash", "Coins" }, -- leaderstats value used for green/red price
    CatalogFields = {
        Name = { "DisplayName", "Name", "EggName" },
        Rarity = { "Rarity", "rarity", "Tier" },
        Price = { "Price", "price", "Cost", "cost", "EggPrice" },
    },
    Rarities = {
        Common = rgb(220, 225, 235),
        Uncommon = rgb(20, 255, 0),
        Rare = rgb(31, 139, 255),
        Epic = rgb(182, 61, 255),
        Legendary = rgb(255, 196, 0),
    },
}

local EggLabel = { Config = Config }
EggLabel.__index = EggLabel

---------------------------------------------------------------- helpers
local function make(class, props, parent)
    local instance = Instance.new(class)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local function corner(radius, parent)
    return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end
-- Unused border-stroke helper; kept for reference.
local function _stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Color = color,
        Thickness = thickness,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end
local function textStroke(parent, thickness)
    return make(
        "UIStroke",
        { Color = Config.Outline, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Round },
        parent
    )
end
local function tween(instance, duration, props, style, direction)
    local activeTween = TweenService:Create(
        instance,
        TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
        props
    )
    activeTween:Play()
    return activeTween
end

-- "FREE" for <= 0, otherwise "$" + 3 significant digits with K/M/B suffix ("$1.5K", "$12.5M", "$250").
function EggLabel.FormatPrice(n)
    n = tonumber(n) or 0
    if n <= 0 then
        return "FREE"
    end
    for _, unit in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
        if n >= unit[1] then
            local scaled = n / unit[1]
            local text = scaled < 10 and string.format("%.2f", scaled)
                or scaled < 100 and string.format("%.1f", scaled)
                or tostring(math.floor(scaled + 0.5))
            if string.find(text, ".", 1, true) then
                text = text:gsub("0+$", ""):gsub("%.$", "")
            end
            return "$" .. text .. unit[2]
        end
    end
    return "$" .. tostring(math.floor(n))
end

---------------------------------------------------------------- data (attributes → CharacterCatalog)
local catalog -- nil = not loaded yet, false = missing / failed to load, table = loaded
local function getCatalog()
    if catalog ~= nil then
        return catalog
    end
    catalog = false
    local catalogModule = ReplicatedStorage:FindFirstChild("CharacterCatalog", true)
    if catalogModule and catalogModule:IsA("ModuleScript") then
        local ok, result = pcall(require, catalogModule)
        if ok then
            catalog = result
        else
            warn("[EggLabel] CharacterCatalog failed to load:", result)
        end
    end
    return catalog
end
-- First non-nil value of entry[fieldName] for the given list of candidate field names.
local function field(entry, names)
    if type(entry) ~= "table" then
        return nil
    end
    for _, fieldName in names do
        if entry[fieldName] ~= nil then
            return entry[fieldName]
        end
    end
    return nil
end
-- Looks an egg up in the catalog by name, with or without a trailing " Egg":
-- catalog.GetEgg(name) first, then keyed lookups and a name-field scan across the known pools.
local function findEntry(name)
    local catalogTable = getCatalog()
    if not catalogTable or not name then
        return nil
    end
    local shortName = name:gsub("%s*[Ee]gg$", "")
    if type(catalogTable.GetEgg) == "function" then
        local ok, entry = pcall(catalogTable.GetEgg, name)
        if ok and entry then
            return entry
        end
    end
    for _, pool in { catalogTable.ById or {}, catalogTable.Eggs or {}, catalogTable.eggs or {}, catalogTable } do
        if type(pool) == "table" then
            local entry = pool[name] or pool[shortName] or pool[shortName .. " Egg"]
            if type(entry) == "table" then
                return entry
            end
            for _, candidate in pool do
                if type(candidate) == "table" then
                    local candidateName = field(candidate, Config.CatalogFields.Name)
                    if candidateName == name or candidateName == shortName or candidateName == shortName .. " Egg" then
                        return candidate
                    end
                end
            end
        end
    end
    return nil
end
-- Returns displayName ("... egg"), rarity (always a Config.Rarities key) and numeric price for an egg.
local function resolve(egg)
    local name = egg:GetAttribute("EggName")
        or egg:GetAttribute("EggType")
        or egg:GetAttribute("DisplayName")
        or egg.Name
    local rarity, price = egg:GetAttribute("Rarity"), egg:GetAttribute("Price")
    if rarity == nil or price == nil then
        local entry = findEntry(name)
        if entry then
            rarity = rarity or field(entry, Config.CatalogFields.Rarity)
            price = price or field(entry, Config.CatalogFields.Price)
            -- Keep the egg ID as its name; catalog Name is the character reward.
        end
    end
    if not Config.Rarities[rarity] then
        rarity = "Common"
    end
    local display = tostring(name)
    if not display:lower():find("egg$") then
        display ..= " egg"
    end
    return display, rarity, tonumber(price) or 0
end

---------------------------------------------------------------- alpha fade for plain frames (hint row)
-- Each object's original transparency is cached once in the "_bt" / "_tt" / "_st" attributes
-- (background / text / stroke) so fading in restores it instead of forcing 0.
local function fadeTree(root, visible, duration)
    for _, descendant in root:GetDescendants() do
        local props = {}
        if descendant:IsA("GuiObject") then
            if descendant:GetAttribute("_bt") == nil then
                descendant:SetAttribute("_bt", descendant.BackgroundTransparency)
            end
            props.BackgroundTransparency = visible and descendant:GetAttribute("_bt") or 1
            if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                if descendant:GetAttribute("_tt") == nil then
                    descendant:SetAttribute("_tt", descendant.TextTransparency)
                end
                props.TextTransparency = visible and descendant:GetAttribute("_tt") or 1
            end
        elseif descendant:IsA("UIStroke") then
            if descendant:GetAttribute("_st") == nil then
                descendant:SetAttribute("_st", descendant.Transparency)
            end
            props.Transparency = visible and descendant:GetAttribute("_st") or 1
        end
        if next(props) then
            if duration > 0 then
                tween(descendant, duration, props)
            else
                for key, value in props do
                    descendant[key] = value
                end
            end
        end
    end
    if root:IsA("GuiObject") then
        if root:GetAttribute("_bt") == nil then
            root:SetAttribute("_bt", root.BackgroundTransparency)
        end
        local backgroundTransparency = visible and root:GetAttribute("_bt") or 1
        if duration > 0 then
            tween(root, duration, { BackgroundTransparency = backgroundTransparency })
        else
            root.BackgroundTransparency = backgroundTransparency
        end
    end
end

---------------------------------------------------------------- build
local labels = {} -- [egg] = label
local folder -- PlayerGui holder

-- Builds the BillboardGui for one label object and stores its handles on self
-- (fit, price, emph, key, keyCorner, verb, hint, tap, gui, root).
local function build(self)
    local guiWidth, guiHeight = Config.GuiSize.X, Config.GuiSize.Y
    local gui = make("BillboardGui", {
        Name = "EggLabel_" .. self.name,
        Size = UDim2.fromOffset(guiWidth, guiHeight),
        SizeOffset = Vector2.new(0, 0.5),
        StudsOffsetWorldSpace = Vector3.new(0, self.offsetY, 0),
        AlwaysOnTop = false,
        LightInfluence = 0,
        MaxDistance = Config.MaxDistance,
        ResetOnSpawn = false,
        Active = true,
        Adornee = self.adornee,
    }, nil)
    -- Root starts transparent and 8 px low; _appear() fades/slides it into place.
    local root = make("CanvasGroup", {
        Name = "Root",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 8),
        Size = UDim2.fromOffset(guiWidth, guiHeight),
        BackgroundTransparency = 1,
        GroupTransparency = 1,
    }, gui)
    self.fit = make("UIScale", { Name = "Fit", Scale = 0.82 }, root)
    -- Velm plate behind the text (Figma "World Nameplates v2" river egg tag)
    do
        -- [rarity] = { gradient top, gradient bottom }
        local plateColorsByRarity = {
            Common = { rgb(150, 156, 172), rgb(64, 70, 86) },
            Uncommon = { rgb(67, 220, 78), rgb(11, 122, 27) },
            Rare = { rgb(59, 120, 255), rgb(11, 42, 156) },
            Epic = { rgb(168, 102, 255), rgb(74, 21, 166) },
            Legendary = { rgb(255, 214, 72), rgb(214, 132, 0) },
            Mythic = { rgb(255, 74, 74), rgb(150, 0, 20) },
        }
        local plateColors = plateColorsByRarity[self.rarity] or plateColorsByRarity.Common
        local plateShadow = make("Frame", {
            Name = "PlateShadow",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 2),
            Size = UDim2.new(1, -8, 0, 84),
            BackgroundColor3 = Color3.new(0, 0, 0),
            BorderSizePixel = 0,
            ZIndex = 0,
        }, root)
        corner(12, plateShadow)
        local plate = make("Frame", {
            Name = "Plate",
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, -4),
            Size = UDim2.new(1, -8, 0, 84),
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 1,
            ClipsDescendants = true,
        }, root)
        corner(12, plate)
        make("UIGradient", { Rotation = 90, Color = ColorSequence.new(plateColors[1], plateColors[2]) }, plate)
        make("ImageLabel", {
            Name = "Studs",
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = "rbxassetid://132561191216691",
            ScaleType = Enum.ScaleType.Tile,
            TileSize = UDim2.fromOffset(18, 18),
            ImageTransparency = 0.45,
            ZIndex = 1,
        }, plate)
        make(
            "UIStroke",
            { Color = Color3.new(1, 1, 1), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border },
            plate
        )
        -- Rotated square under the plate forming the speech-bubble pointer.
        local _pointer = make("Frame", {
            Name = "Pointer",
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0, 82),
            Size = UDim2.fromOffset(14, 14),
            Rotation = 45,
            BackgroundColor3 = Color3.new(1, 1, 1),
            BorderSizePixel = 0,
            ZIndex = 0,
        }, root)
    end

    -- One text row: a holder Frame at offsetY (height px) containing a scaled "Fill" TextLabel.
    -- Returns fillLabel, holder.
    local function textRow(rowName, offsetY, height, maxTextSize, color, content)
        local holder = make("Frame", {
            Name = rowName,
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, offsetY),
            Size = UDim2.new(1, -10, 0, height),
            BackgroundTransparency = 1,
        }, root)
        local function makeLabel(labelName, textColor, offset, zIndex)
            local textLabel = make("TextLabel", {
                Name = labelName,
                Position = UDim2.fromOffset(offset.X, offset.Y),
                Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1,
                Font = Config.Font,
                Text = content,
                TextColor3 = textColor,
                TextScaled = true,
                ZIndex = zIndex,
            }, holder)
            make(
                "UITextSizeConstraint",
                { MaxTextSize = maxTextSize, MinTextSize = math.floor(maxTextSize * 0.6) },
                textLabel
            )
            textStroke(textLabel, 1.6)
            return textLabel
        end
        -- A single clean outline avoids the heavy doubled shadow.   -- solid black drop shadow, like the mockups
        return makeLabel("Fill", color, Vector2.zero, 2), holder
    end
    textRow("Name", 0, 30, 26, Color3.new(1, 1, 1), self.name)
    local rarityLabel = textRow("Rarity", 32, 22, 20, Color3.new(1, 1, 1), string.upper(self.rarity))
    do -- glowing rarity: rarity-coloured outline that pulses + a light shimmer through the letters
        local rarityColor = Config.Rarities[self.rarity] or Config.Rarities.Common
        local rarityStroke = rarityLabel:FindFirstChildOfClass("UIStroke")
        if rarityStroke then
            rarityStroke.Color = rarityColor
            rarityStroke.Thickness = 2.6
        end
        -- Blurred-looking copy behind the text (thick, translucent stroke) that pulses forever.
        local glow = rarityLabel:Clone()
        glow.Name = "Glow"
        glow.ZIndex = 1
        glow.TextColor3 = rarityColor
        glow.TextTransparency = 0.35
        local glowStroke = glow:FindFirstChildOfClass("UIStroke")
        if glowStroke then
            glowStroke.Color = rarityColor
            glowStroke.Thickness = 6
            glowStroke.Transparency = 0.55
        end
        glow.Parent = rarityLabel.Parent
        TweenService:Create(
            glow,
            TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { TextTransparency = 0.75 }
        ):Play()
        if glowStroke then
            TweenService:Create(
                glowStroke,
                TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                { Transparency = 0.9, Thickness = 9 }
            ):Play()
        end
        local shimmerGradient = make("UIGradient", {
            Rotation = 20,
            Offset = Vector2.new(-1, 0),
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(0.42, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(0.5, rarityColor:Lerp(Color3.new(1, 1, 1), 0.5)),
                ColorSequenceKeypoint.new(0.58, Color3.new(1, 1, 1)),
                ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
            }),
        }, rarityLabel)
        -- Shimmer sweep every 2.4 s; the loop ends once the label is destroyed (Parent becomes nil).
        task.spawn(function()
            while rarityLabel.Parent do
                shimmerGradient.Offset = Vector2.new(-1, 0)
                TweenService
                    :Create(shimmerGradient, TweenInfo.new(1.1, Enum.EasingStyle.Sine), { Offset = Vector2.new(1, 0) })
                    :Play()
                task.wait(2.4)
            end
        end)
    end
    local priceHolder
    self.price, priceHolder = textRow("Price", 56, 26, 24, Config.PriceOk, EggLabel.FormatPrice(self.priceValue))
    self.emph = make("UIScale", { Name = "Emph" }, priceHolder)
    self:_updatePrice()
    -- Collect hint (custom ProximityPrompt UI, sits under the price)
    local hint = make("Frame", {
        Name = "Hint",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 88),
        Size = UDim2.fromOffset(0, 28),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundColor3 = Config.Outline,
        BackgroundTransparency = 0.15,
    }, root)
    corner(14, hint)
    make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }, hint)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 7),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, hint)
    self.key = make("TextLabel", {
        Name = "Key",
        LayoutOrder = 1,
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = rgb(243, 238, 232),
        Font = Config.Font,
        Text = "E",
        TextColor3 = Config.Outline,
        TextSize = 14,
    }, hint)
    self.keyCorner = corner(5, self.key)
    self.verb = make("TextLabel", {
        Name = "Verb",
        LayoutOrder = 2,
        Size = UDim2.fromOffset(0, 22),
        AutomaticSize = Enum.AutomaticSize.X,
        BackgroundTransparency = 1,
        Font = Config.Font,
        Text = "Collect",
        TextColor3 = rgb(243, 238, 232),
        TextSize = 15,
    }, hint)
    hint.Visible = false
    self.hint = hint
    fadeTree(hint, false, 0)
    -- Invisible touch target over the hint; only enabled for touch input (see SetNear).
    self.tap = make("TextButton", {
        Name = "TapTarget",
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 84),
        Size = UDim2.fromOffset(190, 36),
        BackgroundTransparency = 1,
        Text = "",
        Active = false,
        Visible = false,
    }, root)
    self.gui, self.root = gui, root
    gui.Parent = folder
end

-- Unused: the price colour no longer depends on the player's balance (see _updatePrice).
local function _playerMoney()
    local leaderstats = Players.LocalPlayer:FindFirstChild("leaderstats")
    if not leaderstats then
        return nil
    end
    for _, statName in Config.CurrencyStats do
        local stat = leaderstats:FindFirstChild(statName)
        if stat and (stat:IsA("IntValue") or stat:IsA("NumberValue")) then
            return stat.Value
        end
    end
    return nil
end
function EggLabel:_updatePrice()
    local priceColor
    if self.priceValue <= 0 then
        priceColor = Config.PriceFree
    else
        priceColor = Config.PriceOk
    end
    if self.price.TextColor3 ~= priceColor then
        self.price.TextColor3 = priceColor
    end
end

function EggLabel:_appear()
    if self.shown then
        return
    end
    self.shown = true
    tween(self.root, 0.25, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) })
end

function EggLabel:_setActive(on)
    self.active = on
end

-- "touch" | "gamepad" | "keyboard": from the prompt's input type, else from the last input used.
local function inputKind(promptInput)
    if promptInput == Enum.ProximityPromptInputType.Touch then
        return "touch"
    end
    if promptInput == Enum.ProximityPromptInputType.Gamepad then
        return "gamepad"
    end
    if promptInput == Enum.ProximityPromptInputType.Keyboard then
        return "keyboard"
    end
    local lastInputType = UserInputService:GetLastInputType()
    if lastInputType == Enum.UserInputType.Touch then
        return "touch"
    end
    if lastInputType.Name:find("Gamepad") then
        return "gamepad"
    end
    return "keyboard"
end
-- [KeyCode name] = { glyph, button colour } for gamepad face buttons.
local PAD_BUTTONS = {
    ButtonX = { "X", rgb(47, 111, 224) },
    ButtonA = { "A", rgb(52, 168, 83) },
    ButtonB = { "B", rgb(220, 60, 60) },
    ButtonY = { "Y", rgb(230, 180, 40) },
}

-- Shows/hides the Collect hint, styled for the current input device. Forced off until shown or while collecting.
function EggLabel:SetNear(on, promptInput)
    if not self.shown or self.collecting then
        on = false
    end
    if self.near == on then
        return
    end
    self.near = on
    local freeSuffix = "" -- Price is shown above; the interaction hint only says Collect.
    if on then
        local kind, prompt = inputKind(promptInput), self.prompt
        if kind == "gamepad" then
            local padButton = PAD_BUTTONS[(prompt and prompt.GamepadKeyCode or Enum.KeyCode.ButtonX).Name]
                or PAD_BUTTONS.ButtonX
            self.key.Text, self.key.BackgroundColor3, self.key.TextColor3 =
                padButton[1], padButton[2], Color3.new(1, 1, 1)
            self.keyCorner.CornerRadius = UDim.new(1, 0)
            self.verb.Text = "Collect" .. freeSuffix
        elseif kind == "touch" then
            self.key.Text, self.key.BackgroundColor3 = "", rgb(243, 238, 232)
            self.keyCorner.CornerRadius = UDim.new(1, 0)
            self.verb.Text = "Tap to collect" .. freeSuffix
        else
            local keyCode = prompt and prompt.KeyboardKeyCode or Enum.KeyCode.E
            local keyString = UserInputService:GetStringForKeyCode(keyCode)
            self.key.Text = (keyString ~= nil and keyString ~= "") and keyString:upper() or keyCode.Name
            self.key.BackgroundColor3, self.key.TextColor3 = rgb(243, 238, 232), Config.Outline
            self.keyCorner.CornerRadius = UDim.new(0, 5)
            self.verb.Text = "Collect" .. freeSuffix
        end
        -- The key cap must fade in fully opaque, whatever fadeTree cached before.
        self.key:SetAttribute("_bt", 0)
        self.key:SetAttribute("_tt", 0)
        self.tap.Visible, self.tap.Active = kind == "touch", kind == "touch"
    else
        self.tap.Visible, self.tap.Active = false, false
    end
    fadeTree(self.hint, on, 0.2)
    tween(self.emph, 0.2, { Scale = on and 1.1 or 1 })
end

-- collected=true: quick pulse, then fade. false: the egg drifted away, so just fade.
function EggLabel:Remove(collected)
    if self.collecting then
        return
    end
    self.collecting = true
    self:SetNear(false)
    -- The egg already left the workspace: pin the label to an invisible part at its last position while it fades.
    if self.adornee and not self.adornee:IsDescendantOf(workspace) then
        self.temp = make("Part", {
            Name = "EggLabelTemp",
            Anchored = true,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            Transparency = 1,
            Size = Vector3.new(0.2, 0.2, 0.2),
            CFrame = CFrame.new(self.lastPos or self.adornee.Position),
        }, workspace)
        self.gui.Adornee = self.temp
    end
    if collected and self.shown then
        local baseScale = self.fit.Scale
        local growTween = tween(self.fit, 0.12, { Scale = baseScale * 1.1 })
        growTween.Completed:Once(function()
            tween(self.fit, 0.3, { Scale = baseScale * 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tween(self.root, 0.3, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end)
        task.delay(0.5, function()
            self:Destroy()
        end)
    else
        tween(self.root, 0.2, { GroupTransparency = 1 })
        task.delay(0.25, function()
            self:Destroy()
        end)
    end
end

function EggLabel:Destroy()
    if not self.alive then
        return
    end
    self.alive = false
    for _, connection in self.conns do
        connection:Disconnect()
    end
    if self.gui then
        self.gui:Destroy()
    end
    if self.temp then
        self.temp:Destroy()
    end
    if labels[self.egg] == self then
        labels[self.egg] = nil
    end
end

-- shared 10 Hz update for every label (distance, scale, fallback near)
function EggLabel:_tick(camPos, charPos, viewportScale)
    local adornee = self.adornee
    if self.collecting or not adornee or not adornee:IsDescendantOf(workspace) then
        return
    end
    local pos = adornee.Position
    self.lastPos = pos
    -- Distance from whichever is farther, camera or character.
    local distance = math.max((camPos - pos).Magnitude, charPos and (charPos - pos).Magnitude or 0)
    self.active = distance <= Config.MaxDistance
    self.gui.Enabled = self.active
    if not self.active then
        return
    end
    self:_updatePrice()
    -- Bounded screen size: compact nearby, gently larger at distance, never oversized.
    -- smoothstep over 12..80 studs maps the scale 0.82 -> 1.0, then eases 35% of the way there per tick.
    local blend = math.clamp((distance - 12) / 68, 0, 1)
    blend = blend * blend * (3 - 2 * blend)
    local targetScale = (0.82 + 0.18 * blend) * viewportScale
    local newScale = self.fit.Scale + (targetScale - self.fit.Scale) * 0.35
    self.fit.Scale = newScale
    self.gui.Size = UDim2.fromOffset(Config.GuiSize.X * newScale, Config.GuiSize.Y * newScale)
    if not self.prompt and charPos and self.collectible then
        self:SetNear((charPos - pos).Magnitude <= Config.NearFallbackDistance)
    end
end

---------------------------------------------------------------- attach / start
-- Part the label floats over: the egg itself if it is a part, an explicit anchor part, or the model's primary/any part.
local function pickAdornee(egg)
    if egg:IsA("BasePart") then
        return egg
    end
    for _, anchorName in { "LabelAnchor", "EggLabelAnchor" } do
        local anchor = egg:FindFirstChild(anchorName, true)
        if anchor and anchor:IsA("BasePart") then
            return anchor
        end
    end
    return egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)
end

-- Creates (or returns the existing) label for an egg. May yield up to ~5 s waiting for the egg's parts to stream in.
function EggLabel.Attach(egg)
    if egg:GetAttribute("RiverEggVisual") ~= true then
        return
    end
    if labels[egg] or not (egg:IsA("Model") or egg:IsA("BasePart")) then
        return labels[egg]
    end
    local adornee = pickAdornee(egg)
    if not adornee then
        local waitStart = os.clock()
        repeat
            task.wait(0.2)
            adornee = pickAdornee(egg)
        until adornee or os.clock() - waitStart > 5 or not egg.Parent
        -- Another Attach may have created the label while this one was waiting.
        if not adornee or labels[egg] then
            return labels[egg]
        end
    end
    local name, rarity, price = resolve(egg)
    local topY
    if egg:IsA("Model") then
        local boundsCFrame, boundsSize = egg:GetBoundingBox()
        topY = boundsCFrame.Position.Y + boundsSize.Y / 2
    else
        topY = adornee.Position.Y + adornee.Size.Y / 2
    end
    local self = setmetatable({
        egg = egg,
        adornee = adornee,
        name = name,
        rarity = rarity,
        priceValue = price,
        offsetY = (adornee.Name == "LabelAnchor" and -1.2 or topY - adornee.Position.Y + Config.HeightAboveEgg),
        alive = true,
        active = true,
        conns = {},
    }, EggLabel)
    labels[egg] = self
    build(self)
    -- ProximityPrompt: draw it ourselves so nothing overlaps the label
    local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
    -- Hooks the first ProximityPrompt found (also used as the DescendantAdded handler, hence the type check).
    local function hookPrompt(promptInstance)
        if self.prompt or not promptInstance:IsA("ProximityPrompt") then
            return
        end
        self.prompt = promptInstance
        promptInstance.Style = Enum.ProximityPromptStyle.Custom
        table.insert(
            self.conns,
            promptInstance.PromptShown:Connect(function(inputType)
                self:SetNear(true, inputType)
            end)
        )
        table.insert(
            self.conns,
            promptInstance.PromptHidden:Connect(function()
                self:SetNear(false)
            end)
        )
        -- Remembered so Detach can tell "collected" from "drifted away" when the egg disappears.
        table.insert(
            self.conns,
            promptInstance.Triggered:Connect(function()
                self.triggeredAt = os.clock()
            end)
        )
        -- Touch: tapping the hint simulates holding the prompt for its HoldDuration.
        table.insert(
            self.conns,
            self.tap.Activated:Connect(function()
                if not promptInstance.Enabled then
                    return
                end
                promptInstance:InputHoldBegin()
                task.delay(promptInstance.HoldDuration + 0.05, function()
                    promptInstance:InputHoldEnd()
                end)
            end)
        )
    end
    if prompt then
        hookPrompt(prompt)
    end
    table.insert(self.conns, egg.DescendantAdded:Connect(hookPrompt))
    -- appear when collectible (attribute optional)
    local function refreshCollectible()
        self.collectible = egg:GetAttribute("Collectible") ~= false
        if self.collectible then
            self:_appear()
        end
    end
    table.insert(self.conns, egg:GetAttributeChangedSignal("Collectible"):Connect(refreshCollectible))
    table.insert(
        self.conns,
        egg:GetAttributeChangedSignal("Collected"):Connect(function()
            if egg:GetAttribute("Collected") then
                self:Remove(true)
            end
        end)
    )
    table.insert(
        self.conns,
        egg.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                EggLabel.Detach(egg)
            end
        end)
    )
    refreshCollectible()
    return self
end

-- Removes an egg's label; plays the "collected" pulse if the egg was collected or its prompt fired < 1.5 s ago.
function EggLabel.Detach(egg)
    local label = labels[egg]
    if not label then
        return
    end
    local collected = egg:GetAttribute("Collected") == true
        or (label.triggeredAt ~= nil and os.clock() - label.triggeredAt < 1.5)
    label:Remove(collected)
end

local started = false
-- Idempotent. Yields on PlayerGui, then labels every tagged egg (current and future).
function EggLabel.Start(tag)
    if started then
        return
    end
    started = true
    tag = tag or Config.Tag
    local player = Players.LocalPlayer
    -- a ScreenGui that survives respawns (a plain Folder in PlayerGui gets cleared when the character spawns)
    folder = Instance.new("ScreenGui")
    folder.ResetOnSpawn = false
    folder.Name = "EggLabels"
    folder.Parent = player:WaitForChild("PlayerGui")
    for _, instance in CollectionService:GetTagged(tag) do
        task.spawn(EggLabel.Attach, instance)
    end
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
        task.spawn(EggLabel.Attach, instance)
    end)
    CollectionService:GetInstanceRemovedSignal(tag):Connect(EggLabel.Detach)
    local elapsed = 0
    RunService.Heartbeat:Connect(function(dt)
        elapsed += dt
        if elapsed < 0.1 then
            return
        end
        elapsed = 0
        local camera = workspace.CurrentCamera
        if not camera then
            return
        end
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        -- Shrink labels slightly on short viewports (< 820 px tall), never below 85%.
        local viewportScale = math.clamp(camera.ViewportSize.Y / 820, 0.85, 1)
        for _, label in labels do
            label:_tick(camera.CFrame.Position, rootPart and rootPart.Position, viewportScale)
        end
    end)
end

return EggLabel
