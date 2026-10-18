--[[ ReplicatedStorage.CharacterInventory.InventoryView  (ModuleScript)
Builds and renders the inventory panel. It owns no game state: InventoryClient hands it a state
table and receives the player's intents through callbacks.

Two layouts:
  • "Wide"    desktop / tablet: header, toolbar, card grid and a details column side by side.
  • "Compact" phones / small windows: tighter metrics, details open as a sheet over the grid.

The grid is virtualized: only the visible rows (plus one row above and below) exist as cards, and
cards are pooled and re-used while scrolling. Card portraits are static ViewportFrames that are only
re-framed when a card shows a different character. Only the single details portrait turns slowly.

API (used by InventoryClient): View.new(gui, mode, density, callbacks), view:Render(state),
view:SetSize(viewportSize), view:Toast(message, kind), view:Step(dt, reducedMotion),
view:SetLoadingPulse(alpha), view:FirstSelectable(), view:Destroy(); fields read by the client:
root, scale, search, bestButton, mode, d (details parts: primary, back, ...).
callbacks: onSelect(id?), onAction(action, id?), onSearch(text), onRarity(rarity?), onSort(sortId?),
onPin(id), onClearFilters(), onClose().
]]
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.InventoryConfig)
local Format = require(script.Parent.InventoryFormat)
local Model = require(script.Parent.InventoryModel)
local Style = require(script.Parent.InventoryStyle)
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))

local Theme = Config.Theme
local Fonts = Config.Fonts
local make, text, chip = Style.Make, Style.Text, Style.Chip
local SHEET_TWEEN = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) -- compact details sheet

local View = {}
View.__index = View

---------------------------------------------------------------- portraits
local portraitFolder
local function portraitTemplate(item)
    portraitFolder = portraitFolder or ReplicatedStorage.CharacterInventory:FindFirstChild(Config.PortraitFolder)
    if not portraitFolder then
        return nil
    end
    return (item.golden and portraitFolder:FindFirstChild(item.characterId .. "_Golden"))
        or portraitFolder:FindFirstChild(item.characterId)
end

local function newViewport(parent, props)
    local viewport = make("ViewportFrame", {
        Name = "Portrait",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Ambient = Color3.fromRGB(168, 170, 182),
        LightColor = Color3.fromRGB(255, 249, 238),
        LightDirection = Vector3.new(-0.55, -1, -0.65),
    }, parent)
    for key, value in props or {} do
        viewport[key] = value
    end
    return viewport
end

-- Puts a fresh copy of the character in the viewport (only when `key` changes). Returns the new
-- model, or nil when nothing changed or there is no portrait template.
local function showPortrait(viewport, item, key)
    if viewport:GetAttribute("Key") == key then
        return
    end
    viewport:SetAttribute("Key", key)
    for _, child in viewport:GetChildren() do
        if child:IsA("Model") then
            child:Destroy()
        end
    end
    local template = item and portraitTemplate(item)
    if not template then
        return
    end
    local copy = template:Clone()
    copy.Parent = viewport
    Style.FrameModel(viewport, copy, 20, 1.08)
    return copy
end

---------------------------------------------------------------- small parts
local function statRow(parent, label, order, valueSize)
    local row = make(
        "Frame",
        { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, valueSize + 6), LayoutOrder = order },
        parent
    )
    text(row, {
        Text = label,
        FontFace = Fonts.Bold,
        TextSize = 11,
        TextColor3 = Theme.Muted,
        Size = UDim2.new(0.45, 0, 1, 0),
    })
    local value = text(row, {
        Name = "Value",
        Text = "",
        FontFace = Fonts.Bold,
        TextSize = valueSize,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.55, 0, 1, 0),
    })
    return row, value
end

---------------------------------------------------------------- construction
function View.new(gui, mode, density, callbacks)
    local self = setmetatable({}, View)
    self.gui = gui
    self.mode = mode
    self.density = density -- Wide only: "Full" (names + sort buttons) | "Roomy" (names) | "Dense" (short names)
    self.cb = callbacks
    self.M = mode == "Compact" and Config.Layout.Compact or Config.Layout.Wide
    self.cards = {} -- pool
    self.list = {} -- filtered + sorted items currently shown
    self.connections = {}
    self.state = nil
    self.detailsOpen = mode ~= "Compact"
    self:_build()
    return self
end

-- Connects a UI signal with the click sound; tracked so Destroy can disconnect it.
function View:_connect(signal, handler)
    local connection = signal:Connect(function(...)
        UISound.Play("Click")
        handler(...)
    end)
    table.insert(self.connections, connection)
    return connection
end

-- Placeholder over the grid (loading / empty / no results / error): icon, title, body, a CLEAR FILTERS
-- button (no results) and the three first-visit steps (empty). Called once from View:_build.
local function buildNote(self, gridWell, compact)
    local note = make("Frame", {
        Name = "Note",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.46),
        Size = UDim2.fromOffset(compact and 360 or 450, 200),
        Visible = false,
        ZIndex = 5,
    }, gridWell)
    self.noteIcon = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(32, 32),
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.fromScale(0.5, 0),
        ZIndex = 5,
    }, note)
    for i = 0, 3 do
        Style.Stud(self.noteIcon, (i % 2) * 18, math.floor(i / 2) * 18, 14, 6)
    end
    self.noteTitle = text(note, {
        Text = "",
        FontFace = Fonts.Head,
        TextSize = compact and 18 or 22,
        TextColor3 = Theme.PageText,
        Position = UDim2.fromOffset(0, 42),
        Size = UDim2.new(1, 0, 0, 26),
        TextXAlignment = Enum.TextXAlignment.Center,
        ZIndex = 5,
    })
    self.noteBody = text(note, {
        Text = "",
        TextColor3 = Theme.PageMuted,
        TextSize = compact and 12 or 14,
        Position = UDim2.fromOffset(0, 70),
        Size = UDim2.new(1, 0, 0, 36),
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 5,
        TextTruncate = Enum.TextTruncate.None,
    })
    self.noteButton = Style.Button(note, "CLEAR FILTERS", "Secondary", {
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 108),
        Size = UDim2.fromOffset(140, 32),
        Visible = false,
        ZIndex = 5,
    })
    self:_connect(self.noteButton.Activated, function()
        self.cb.onClearFilters()
    end)
    -- first visit: hatch, collect, come back
    self.steps = make("Frame", {
        Name = "Steps",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 108),
        Size = UDim2.new(1, 0, 0, compact and 76 or 86),
        Visible = false,
        ZIndex = 5,
    }, note)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, self.steps)
    for i, step in
        {
            { "Hatch an egg", "Hold an egg at your chamber" },
            { "Collect it", "Every hatch rolls its own Power" },
            { "Come back here", "Place your best on the temple" },
        }
    do
        local card = make("Frame", {
            BackgroundColor3 = Theme.Card,
            BorderSizePixel = 0,
            Size = UDim2.new(1 / 3, -6, 1, 0),
            LayoutOrder = i,
            ZIndex = 5,
        }, self.steps)
        Style.Corner(card, 10)
        Style.Stroke(card, Theme.CardEdge, 1)
        chip(card, tostring(i), Theme.ChipOn, {
            TextColor3 = Theme.ButtonText,
            Position = UDim2.fromOffset(8, 8),
            ZIndex = 6,
            TextSize = 11,
            Size = UDim2.fromOffset(0, 18),
        })
        text(card, {
            Text = step[1],
            FontFace = Fonts.Head,
            TextSize = compact and 13 or 15,
            Position = UDim2.fromOffset(8, 30),
            Size = UDim2.new(1, -16, 0, 18),
            ZIndex = 6,
        })
        text(card, {
            Text = step[2],
            TextSize = 11,
            TextColor3 = Theme.Muted,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.None,
            TextYAlignment = Enum.TextYAlignment.Top,
            Position = UDim2.fromOffset(8, 50),
            Size = UDim2.new(1, -16, 0, 30),
            ZIndex = 6,
        })
    end
    self.note = note
end

function View:_build()
    local compact = self.mode == "Compact"
    local pad = compact and 8 or 12

    -- the shrine shell: tile roof, gold studs and a dark-wood page, the same build as the leaderboard's expanded view
    local root = Style.Shell(self.gui, {
        Name = "InventoryPanel",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(800, 520),
        Active = true,
    }, 12)
    self.root = root
    self.scale = make("UIScale", { Scale = 1 }, root)
    self.roofH = compact and 16 or 22
    Style.Roof(root, self.roofH)
    local band = Style.StudBand(root, 6, 26, 6, 2)
    band.Position = UDim2.fromOffset(20, 6)
    band.Size = UDim2.new(1, -40, 0, 6)
    local page = Style.Page(root, 8, 16, 8, 8, 8)
    self.page = page

    ------------------------------------------------ header
    local headerY = compact and 6 or 10
    local headerH = compact and 32 or 40
    local header = make("Frame", {
        Name = "Header",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(pad, headerY),
        Size = UDim2.new(1, -pad * 2, 0, headerH),
    }, page)
    local headerLeft = make(
        "Frame",
        { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X },
        header
    )
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, compact and 8 or 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, headerLeft)
    self.title = text(headerLeft, {
        Text = "CHARACTERS",
        FontFace = Fonts.Head,
        TextSize = compact and 22 or 27,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 1,
    })
    Style.GoldText(self.title, compact and 2 or 3)
    self.owned = text(headerLeft, {
        Text = "",
        FontFace = Fonts.Bold,
        TextSize = compact and 11 or 13,
        TextColor3 = Theme.PageMuted,
        LayoutOrder = 2,
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 1, 0),
        TextTruncate = Enum.TextTruncate.None,
    })
    Style.Pad(self.owned, 0, compact and 4 or 6, 0, 0)

    local headerRight = make("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X,
    }, header)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, compact and 8 or 12),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, headerRight)

    -- capacity: "SLOTS 4 / 6" + one pip per slot
    local capacityBox = make(
        "Frame",
        { BackgroundTransparency = 1, Size = UDim2.fromOffset(compact and 74 or 150, headerH), LayoutOrder = 1 },
        headerRight
    )
    self.capLabel = text(capacityBox, {
        Text = "SLOTS",
        FontFace = Fonts.Bold,
        TextSize = 10,
        TextColor3 = Theme.PageMuted,
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.fromOffset(0, compact and 1 or 2),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    self.capValue = text(capacityBox, {
        Text = "–",
        FontFace = Fonts.Heavy,
        TextSize = compact and 15 or 17,
        TextColor3 = Theme.PageText,
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.fromOffset(0, compact and 12 or 13),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    self.pips = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 6),
        Position = UDim2.fromOffset(0, compact and 32 or 33),
        Visible = not compact,
    }, capacityBox)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, self.pips)

    self.bestButton = Style.Button(headerRight, "PLACE BEST", "Primary", {
        Size = UDim2.fromOffset(compact and 112 or 160, compact and 30 or 38),
        LayoutOrder = 2,
        TextSize = compact and 15 or 17,
        TextYAlignment = compact and Enum.TextYAlignment.Center or Enum.TextYAlignment.Top,
    })
    if not compact then -- wide layout: a second line under PLACE BEST shows the expected gain
        Style.Pad(self.bestButton, 0, 4, 0, 0)
        self.bestSub = text(self.bestButton, {
            Text = "",
            FontFace = Fonts.Bold,
            TextSize = 11,
            TextColor3 = Theme.Ink,
            TextTransparency = 0.15,
            Position = UDim2.new(0, 0, 1, -18),
            Size = UDim2.new(1, 0, 0, 13),
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    end
    self:_connect(self.bestButton.Activated, function()
        if Style.Enabled(self.bestButton) then
            self.cb.onAction("PlaceBest")
        end
    end)

    self.closeButton = Style.Button(headerRight, "×", "Secondary", {
        Size = UDim2.fromOffset(compact and 30 or 34, compact and 30 or 34),
        TextSize = compact and 20 or 22,
        FontFace = Fonts.Bold,
        LayoutOrder = 3,
    })
    self:_connect(self.closeButton.Activated, function()
        self.cb.onClose()
    end)

    ------------------------------------------------ toolbar
    local toolbarY = headerY + headerH + (compact and 4 or 6)
    local toolbarH = compact and 28 or 32
    local toolbar = make("Frame", {
        Name = "Toolbar",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(pad, toolbarY),
        Size = UDim2.new(1, -pad * 2, 0, toolbarH),
    }, page)
    local searchWidth = compact and 140 or (self.density == "Full" and 220 or (self.density == "Roomy" and 190 or 170))
    local searchWell =
        Style.Inset(toolbar, { Size = UDim2.fromOffset(searchWidth, toolbarH), BackgroundColor3 = Theme.Card }, 7)
    self.search = make("TextBox", {
        Name = "Search",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 1, 0),
        FontFace = Fonts.Body,
        TextSize = compact and 12 or 13,
        TextColor3 = Theme.Text,
        PlaceholderText = "Search characters",
        PlaceholderColor3 = Theme.Faint,
        Text = "",
        ClearTextOnFocus = false,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 3,
        Selectable = true,
    }, searchWell)
    -- debounce: only the last keystroke within 0.12 s reaches onSearch
    local searchSeq = 0
    self:_connect(self.search:GetPropertyChangedSignal("Text"), function()
        searchSeq += 1
        local mine = searchSeq
        task.delay(0.12, function()
            if mine == searchSeq then
                self.cb.onSearch(self.search.Text)
            end
        end)
    end)

    local chips = make("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(searchWidth + 10, 0),
        Size = UDim2.new(1, -(searchWidth + 10), 1, 0),
    }, toolbar)
    self.chips = chips
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, compact and 4 or 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, chips)
    self.rarityButtons = {} -- [rarity | "All"] = button
    -- id nil = the ALL button; color adds a swatch in front of the label
    local function rarityButton(id, label, color, order)
        local button = Style.Button(chips, label, "Secondary", {
            Size = UDim2.fromOffset(0, toolbarH),
            AutomaticSize = Enum.AutomaticSize.X,
            TextSize = compact and 11 or 12,
            LayoutOrder = order,
        })
        Style.Pad(button, color and (compact and 20 or 24) or 10, 0, compact and 8 or 10, 0)
        if color then
            local swatch = make("Frame", {
                BorderSizePixel = 0,
                BackgroundColor3 = color,
                Size = UDim2.fromOffset(8, 8),
                AnchorPoint = Vector2.new(0, 0.5),
                Position = UDim2.new(0, compact and -12 or -14, 0.5, 0),
                ZIndex = button.ZIndex + 1,
            }, button)
            Style.Corner(swatch, 2)
        end
        self:_connect(button.Activated, function()
            self.cb.onRarity(id)
        end)
        self.rarityButtons[id or "All"] = button
        return button
    end
    -- labels: compact = first letter, Dense = these short names, otherwise the full name
    local SHORT_RARITY_LABELS = { Common = "COM", Uncommon = "UNC", Rare = "RARE", Epic = "EPIC", Legendary = "LEG" }
    rarityButton(nil, "ALL", nil, 0)
    for i, rarity in Config.Rarities do
        local label = compact and rarity:sub(1, 1)
            or (self.density == "Dense" and SHORT_RARITY_LABELS[rarity] or string.upper(rarity))
        rarityButton(rarity, label, Theme.Rarity[rarity], i)
    end

    -- sort: segmented control (full width) or one cycling button (dense / compact)
    local spacer = make(
        "Frame",
        { BackgroundTransparency = 1, Size = UDim2.fromOffset(compact and 4 or 12, 1), LayoutOrder = 10 },
        chips
    )
    spacer.Name = "Spacer"
    self.sortButtons = {} -- [sortId] = button (Full density only)
    if compact or self.density ~= "Full" then
        local button = Style.Button(chips, "POWER ▼", "Secondary", {
            Size = UDim2.fromOffset(0, toolbarH),
            AutomaticSize = Enum.AutomaticSize.X,
            TextSize = 11,
            LayoutOrder = 11,
        })
        Style.Pad(button, 10, 0, 10, 0)
        Style.SetOn(button, true)
        self.sortCycle = button
        self:_connect(button.Activated, function()
            self.cb.onSort(nil)
        end)
    else
        text(chips, {
            Text = "SORT",
            FontFace = Fonts.Bold,
            TextSize = 10,
            TextColor3 = Theme.PageMuted,
            Size = UDim2.fromOffset(30, toolbarH),
            LayoutOrder = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        for i, sort in Config.Sorts do
            local button = Style.Button(chips, sort.Label, "Secondary", {
                Size = UDim2.fromOffset(0, toolbarH),
                AutomaticSize = Enum.AutomaticSize.X,
                TextSize = 12,
                LayoutOrder = 11 + i,
            })
            Style.Pad(button, 10, 0, 10, 0)
            self.sortButtons[sort.Id] = button
            self:_connect(button.Activated, function()
                self.cb.onSort(sort.Id)
            end)
        end
    end

    ------------------------------------------------ body
    local bodyY = toolbarY + toolbarH + (compact and 6 or 8)
    local footerHeight = compact and 16 or 20
    local detailsWidth = compact and 0 or Config.Layout.DetailsWidth
    local body = make("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(pad, bodyY),
        Size = UDim2.new(1, -pad * 2, 1, -(bodyY + footerHeight + (compact and 2 or 4))),
        ClipsDescendants = compact, -- the details sheet slides up from inside the body
    }, page)
    self.body = body

    -- the cards sit straight on the dark-wood page (no extra box around them)
    local gridWell = make("Frame", {
        Name = "GridWell",
        BackgroundTransparency = 1,
        ClipsDescendants = true,
        Size = UDim2.new(1, compact and 0 or -(detailsWidth + 8), 1, 0),
    }, body)
    self.gridWell = gridWell
    self.grid = make("ScrollingFrame", {
        Name = "Grid",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        ScrollBarThickness = compact and 4 or 6,
        ScrollBarImageColor3 = Theme.CardEdge,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        ZIndex = 2,
        Selectable = false,
        ScrollBarImageTransparency = 0.25,
    }, gridWell)
    self:_connect(self.grid:GetPropertyChangedSignal("CanvasPosition"), function()
        self:_layoutGrid(false)
    end)
    self:_connect(self.grid:GetPropertyChangedSignal("AbsoluteSize"), function()
        self:_layoutGrid(true)
    end)

    buildNote(self, gridWell, compact)

    -- skeleton cards while loading (one CanvasGroup pulses, nothing else animates)
    self.skeleton = make("CanvasGroup", {
        Name = "Skeleton",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 3,
    }, gridWell)

    ------------------------------------------------ details
    -- wide: a fixed column on the right; compact: a sheet that slides up over the grid (see _renderDetails)
    local details
    details = Style.Inset(body, compact and {
        Name = "DetailsSheet",
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromScale(0, 1.1),
        Visible = false,
        ZIndex = 20,
        BackgroundColor3 = Theme.Card,
    } or {
        Name = "Details",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0, detailsWidth, 1, 0),
        BackgroundColor3 = Theme.Card,
    }, 8)
    local detailsEdge = details:FindFirstChildOfClass("UIStroke")
    detailsEdge.Color, detailsEdge.Thickness = Theme.Gold, 2
    self.details = details
    self:_buildDetails(details)

    ------------------------------------------------ footerHeight: hints + toast
    self.hint = text(page, {
        Name = "Hint",
        Text = "",
        FontFace = Fonts.Bold,
        TextSize = 11,
        TextColor3 = Theme.PageMuted,
        Position = UDim2.new(0, pad, 1, -(footerHeight + 1)),
        Size = UDim2.new(0.6, 0, 0, footerHeight),
    })
    self.toast = text(page, {
        Name = "Toast",
        Text = "",
        FontFace = Fonts.Bold,
        TextSize = compact and 11 or 13,
        TextColor3 = Theme.PageText,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -pad, 1, -(footerHeight + 1)),
        Size = UDim2.new(0.5, 0, 0, footerHeight),
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTransparency = 1,
    })
end

function View:_buildDetails(parent)
    local compact = self.mode == "Compact"
    local parts = {} -- every widget _renderDetails updates (exposed as self.d)
    self.d = parts
    local footerH = compact and 90 or 98
    local scroll = make("ScrollingFrame", {
        Name = "Scroll",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, -footerH),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = Theme.Faint,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = parent.ZIndex + 1,
        Selectable = false,
    }, parent)
    Style.Pad(scroll, 12, compact and 10 or 12, 12, 12)
    make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
    parts.scroll = scroll

    -- empty selection
    parts.empty = text(scroll, {
        Text = "Select a character to see its exact Power, income and actions.",
        TextColor3 = Theme.Muted,
        TextSize = 13,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 60),
        TextXAlignment = Enum.TextXAlignment.Center,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 0,
    })

    local content = make("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
        Visible = false,
    }, scroll)
    make("UIListLayout", { Padding = UDim.new(0, compact and 6 or 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
    parts.content = content

    if compact then
        parts.back = Style.Button(
            content,
            "‹ BACK",
            "Secondary",
            { Size = UDim2.fromOffset(84, 28), TextSize = 12, LayoutOrder = 0 }
        )
        self:_connect(parts.back.Activated, function()
            self.cb.onSelect(nil)
        end)
    end

    local portraitWell = Style.Inset(content, { Size = UDim2.new(1, 0, 0, compact and 120 or 140), LayoutOrder = 1 }, 6)
    portraitWell.BackgroundColor3 = Theme.Portrait
    parts.rarityGlow = make("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.Rarity.Common,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 0,
    }, portraitWell)
    make("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.55, 0.96),
            NumberSequenceKeypoint.new(1, 0.78),
        }),
    }, parts.rarityGlow)
    parts.viewport = newViewport(portraitWell, { ZIndex = portraitWell.ZIndex + 1 })

    parts.name = text(content, {
        Text = "",
        FontFace = Fonts.Head,
        TextSize = compact and 20 or 22,
        Size = UDim2.new(1, 0, 0, compact and 24 or 26),
        LayoutOrder = 2,
    })
    local chipsRow =
        make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 3 }, content)
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 6),
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, chipsRow)
    parts.rarityChip =
        chip(chipsRow, "", Theme.Rarity.Common, { LayoutOrder = 1, Size = UDim2.fromOffset(0, 18), TextSize = 11 })
    parts.qualityChip =
        chip(chipsRow, "", Theme.Portrait, { LayoutOrder = 2, Size = UDim2.fromOffset(0, 18), TextSize = 11 })
    parts.stateChip =
        chip(chipsRow, "", Theme.Placed, { LayoutOrder = 3, Size = UDim2.fromOffset(0, 18), TextSize = 11 })

    -- Power and income: two big tiles side by side, exact Power underneath
    local tiles = make(
        "Frame",
        { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, compact and 62 or 68), LayoutOrder = 4 },
        content
    )
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, tiles)
    local powerTile =
        Style.Inset(tiles, { Size = UDim2.new(0.56, -4, 1, 0), BackgroundColor3 = Theme.Panel, LayoutOrder = 1 }, 8)
    powerTile:FindFirstChildOfClass("UIStroke").Color = Theme.Gold
    Style.Pad(powerTile, 10, 6, 10, 6)
    text(powerTile, {
        Text = "POWER",
        FontFace = Fonts.Bold,
        TextSize = 10,
        TextColor3 = Theme.ButtonTextDim,
        Size = UDim2.new(1, 0, 0, 12),
    })
    parts.power = text(powerTile, {
        Text = "",
        FontFace = Fonts.Heavy,
        TextSize = compact and 26 or 30,
        TextColor3 = Theme.GoldHi,
        Position = UDim2.fromOffset(0, 14),
        Size = UDim2.new(1, 0, 1, -14),
        TextTruncate = Enum.TextTruncate.None,
    })
    local incomeTile = Style.Inset(
        tiles,
        { Size = UDim2.new(0.44, -4, 1, 0), BackgroundColor3 = Theme.IncomeTile, LayoutOrder = 2 },
        8
    )
    incomeTile:FindFirstChildOfClass("UIStroke").Color = Theme.Income
    Style.Pad(incomeTile, 10, 6, 10, 6)
    text(incomeTile, {
        Text = "INCOME / SEC",
        FontFace = Fonts.Bold,
        TextSize = 10,
        TextColor3 = Theme.IncomeLight,
        Size = UDim2.new(1, 0, 0, 12),
    })
    parts.income = text(incomeTile, {
        Text = "",
        FontFace = Fonts.Heavy,
        TextSize = compact and 17 or 19,
        TextColor3 = Theme.IncomeLight,
        Position = UDim2.fromOffset(0, 14),
        Size = UDim2.new(1, 0, 1, -14),
        TextTruncate = Enum.TextTruncate.None,
    })
    local exactRow =
        make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 5 }, content)
    parts.exact = text(
        exactRow,
        { Text = "", FontFace = Fonts.Body, TextSize = 12, TextColor3 = Theme.Muted, Size = UDim2.new(0.62, 0, 1, 0) }
    )
    parts.multiplier = text(exactRow, {
        Text = "",
        FontFace = Fonts.Bold,
        TextSize = 11,
        TextColor3 = Theme.Muted,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.fromScale(1, 0),
        Size = UDim2.new(0.38, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    local eventRow, eventValue = statRow(content, "OWNER EVENT", 6, 12)
    parts.eventRow, parts.eventValue = eventRow, eventValue
    local _, base = statRow(content, "BASE POWER", 7, 13)
    parts.base = base
    local slotRow, slotValue = statRow(content, "SLOT", 8, 13)
    parts.slotRow, parts.slotValue = slotRow, slotValue
    local _, acquired = statRow(content, "ACQUIRED", 9, 13)
    parts.acquired = acquired

    -- comparison
    local compareWell = Style.Inset(
        content,
        { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 10 },
        6
    )
    Style.Pad(compareWell, 12, 9, 12, 9)
    make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, compareWell)
    parts.compareTitle = text(compareWell, {
        Text = "",
        FontFace = Fonts.Bold,
        TextSize = 11,
        TextColor3 = Theme.Muted,
        Size = UDim2.new(1, 0, 0, 14),
        LayoutOrder = 1,
    })
    local function deltaRow(label, order)
        local row = make(
            "Frame",
            { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order },
            compareWell
        )
        text(row, {
            Text = label,
            FontFace = Fonts.Bold,
            TextSize = 11,
            TextColor3 = Theme.Muted,
            Size = UDim2.new(0.34, 0, 1, 0),
        })
        local value = text(row, {
            Text = "",
            FontFace = Fonts.Bold,
            TextSize = 14,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -52, 0, 0),
            Size = UDim2.new(0.66, -52, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        local rel = text(row, {
            Text = "",
            FontFace = Fonts.Bold,
            TextSize = 11,
            TextColor3 = Theme.Muted,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.fromScale(1, 0),
            Size = UDim2.new(0, 48, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
        })
        return row, value, rel
    end
    parts.cmpPowerRow, parts.cmpPower, parts.cmpPowerRel = deltaRow("POWER", 2)
    parts.cmpIncomeRow, parts.cmpIncome, parts.cmpIncomeRel = deltaRow("INCOME", 3)
    parts.compareNone = text(compareWell, {
        Text = "Nothing to compare yet.",
        TextColor3 = Theme.Muted,
        TextSize = 12,
        Size = UDim2.new(1, 0, 0, 16),
        LayoutOrder = 4,
    })

    -- actions
    -- pinned to the bottom of the panel so the actions never scroll out of view
    local footer = make("Frame", {
        Name = "Actions",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, footerH),
        ZIndex = parent.ZIndex + 1,
        Visible = false,
    }, parent)
    Style.Pad(footer, 12, 8, 12, compact and 10 or 12)
    make("UIListLayout", {
        Padding = UDim.new(0, 6),
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
    }, footer)
    make(
        "Frame",
        { BorderSizePixel = 0, BackgroundColor3 = Theme.CardEdge, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 0 },
        footer
    )
    parts.footer = footer
    local actions = make(
        "Frame",
        { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, compact and 34 or 38), LayoutOrder = 2 },
        footer
    )
    make("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, actions)
    parts.primary = Style.Button(actions, "PLACE", "Primary", { Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 1 })
    parts.secondary = Style.Button(actions, "HOLD", "Secondary", { Size = UDim2.new(0.3, -4, 1, 0), LayoutOrder = 2 })
    parts.pin =
        Style.Button(actions, "PIN", "Ghost", { Size = UDim2.new(0.2, -8, 1, 0), LayoutOrder = 3, TextSize = 11 })
    parts.reason = text(footer, {
        Text = "",
        TextColor3 = Theme.Warn,
        TextSize = 11,
        TextWrapped = true,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        TextTruncate = Enum.TextTruncate.None,
        LayoutOrder = 1,
    })
    local function fire(button)
        local action = button:GetAttribute("Action")
        if action and Style.Enabled(button) and self.selected then
            self.cb.onAction(action, self.selected.id)
        end
    end
    self:_connect(parts.primary.Activated, function()
        fire(parts.primary)
    end)
    self:_connect(parts.secondary.Activated, function()
        fire(parts.secondary)
    end)
    self:_connect(parts.pin.Activated, function()
        if self.selected and Style.Enabled(parts.pin) then
            self.cb.onPin(self.selected.id)
        end
    end)
end

---------------------------------------------------------------- cards
-- One pooled grid card (hidden until _layoutGrid positions it and _assignCard fills it).
function View:_newCard()
    local metrics = self.M
    local compact = self.mode == "Compact"
    local card = {}
    local frame = make("TextButton", {
        Name = "Card",
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(metrics.CardW, metrics.CardH),
        Selectable = true,
        ZIndex = 3,
        Visible = false,
    }, self.grid)
    Style.Corner(frame, 8)
    card.stroke = Style.Stroke(frame, Theme.CardEdge, 1)
    make("Frame", { -- top light
        BorderSizePixel = 0,
        BackgroundColor3 = Theme.CardHi,
        Size = UDim2.new(1, -14, 0, 1),
        Position = UDim2.fromOffset(7, 1),
        ZIndex = 4,
    }, frame)
    card.frame = frame

    local portrait = Style.Inset(frame, {
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.new(1, -12, 0, metrics.Portrait),
        BackgroundColor3 = Theme.Portrait,
        ZIndex = 4,
    }, 6)
    card.glow = make(
        "Frame",
        { BorderSizePixel = 0, BackgroundColor3 = Theme.Rarity.Common, Size = UDim2.fromScale(1, 1), ZIndex = 4 },
        portrait
    )
    make("UIGradient", {
        Rotation = 90,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.85),
            NumberSequenceKeypoint.new(0.5, 0.62),
            NumberSequenceKeypoint.new(1, 0.35),
        }),
    }, card.glow)
    card.viewport = newViewport(portrait, { ZIndex = 5 })
    -- static diagonal sheen, only on unusual rolls
    card.sheen = make("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = Color3.new(1, 1, 1),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 6,
        Visible = false,
    }, portrait)
    make("UIGradient", {
        Rotation = 35,
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.42, 1),
            NumberSequenceKeypoint.new(0.5, 0.86),
            NumberSequenceKeypoint.new(0.58, 1),
            NumberSequenceKeypoint.new(1, 1),
        }),
    }, card.sheen)
    card.rarity = chip(portrait, "", Theme.Rarity.Common, {
        Position = UDim2.fromOffset(5, 5),
        ZIndex = 7,
        TextSize = compact and 9 or 10,
        Size = UDim2.fromOffset(0, compact and 14 or 16),
    })
    card.quality = chip(portrait, "", Theme.Ink, {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 5, 1, -5),
        ZIndex = 7,
        TextSize = compact and 9 or 10,
        Size = UDim2.fromOffset(0, compact and 14 or 16),
        BackgroundTransparency = 0.15,
    })

    local y = 6 + metrics.Portrait + (compact and 5 or 6)
    card.name = text(frame, {
        Text = "",
        FontFace = Fonts.Head,
        TextSize = compact and 15 or 17,
        Position = UDim2.fromOffset(8, y),
        Size = UDim2.new(1, -16, 0, compact and 18 or 20),
        ZIndex = 4,
    })
    y += compact and 19 or 21
    text(frame, {
        Text = "POWER",
        FontFace = Fonts.Bold,
        TextSize = compact and 9 or 10,
        TextColor3 = Theme.Muted,
        Position = UDim2.fromOffset(8, y),
        Size = UDim2.new(1, -16, 0, 11),
        ZIndex = 4,
    })
    y += compact and 10 or 11
    card.power = text(frame, {
        Text = "",
        FontFace = Fonts.Heavy,
        TextSize = compact and 22 or 26,
        Position = UDim2.fromOffset(8, y),
        Size = UDim2.new(1, -16, 0, compact and 24 or 28),
        ZIndex = 4,
        TextTruncate = Enum.TextTruncate.None,
    })
    y += compact and 24 or 28
    card.income = text(frame, {
        Text = "",
        FontFace = Fonts.Bold,
        TextSize = compact and 12 or 13,
        TextColor3 = Theme.Income,
        Position = UDim2.fromOffset(8, y),
        Size = UDim2.new(1, -16, 0, 16),
        ZIndex = 4,
    })
    -- placed / held state sits on the income line: a placed character is the one earning
    card.stateChip = chip(frame, "", Theme.Placed, {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0, y + 8),
        ZIndex = 5,
        TextSize = compact and 9 or 10,
        Size = UDim2.fromOffset(0, compact and 14 or 16),
    })

    frame.MouseEnter:Connect(function()
        card.hover = true
        self:_paintCard(card)
    end)
    frame.MouseLeave:Connect(function()
        card.hover = false
        self:_paintCard(card)
    end)
    frame.SelectionGained:Connect(function()
        card.hover = true
        self:_paintCard(card)
    end)
    frame.SelectionLost:Connect(function()
        card.hover = false
        self:_paintCard(card)
    end)
    frame.Activated:Connect(function()
        if card.item then
            self.cb.onSelect(card.item.id)
        end
    end)
    return card
end

-- Hover / selection / roll-quality edge; cheap, so it runs on every hover change and every layout.
function View:_paintCard(card)
    local item = card.item
    if not item then
        return
    end
    local selected = self.state and self.state.selectedId == item.id
    local notable = item.qualityRank >= Config.NotableRank
    card.frame.BackgroundColor3 = card.hover and Theme.CardHover or Theme.Card
    if selected then
        card.stroke.Color, card.stroke.Thickness = Theme.Accent, 2.5
    elseif notable then
        card.stroke.Color, card.stroke.Thickness = Style.Deep(item.qualityColor), 1.5
    else
        card.stroke.Color, card.stroke.Thickness =
            Style.Deep(Theme.Rarity[item.rarity] or Theme.CardEdge):Lerp(Theme.CardEdge, 0.3), 1.5 -- rarity-coloured edge
    end
end

-- Shows `item` on `card`. Text and portrait are only rewritten when the item's visible key changed.
function View:_assignCard(card, item, multiplier)
    card.item = item
    local key = item.id .. "|" .. item.power .. "|" .. item.state .. "|" .. tostring(item.slot) .. "|" .. multiplier
    if card.key ~= key then
        card.key = key
        local rarityColor = Theme.Rarity[item.rarity] or Theme.Rarity.Common
        card.glow.BackgroundColor3 = rarityColor
        card.rarity.Text = string.upper(item.rarity)
        card.rarity.BackgroundColor3 = rarityColor
        card.name.Text = item.name
        card.power.Text = Format.Short(item.power)
        card.income.Text = Format.Rate(item.income * multiplier)
        local notable = item.qualityRank >= Config.NotableRank
        card.power.TextColor3 = notable and Style.Deep(item.qualityColor) or Theme.Text
        card.sheen.Visible = notable
        card.quality.Visible = notable
        if notable then
            card.quality.Text = string.upper(item.quality)
            card.quality.TextColor3 = item.qualityColor
            card.quality.BackgroundColor3 = Theme.Ink
        end
        if item.state == "Placed" then
            card.stateChip.Visible = true
            card.stateChip.Text = item.slot and ("SLOT " .. item.slot) or "PLACED"
            card.stateChip.BackgroundColor3 = Theme.Placed
        elseif item.state == "Held" then
            card.stateChip.Visible = true
            card.stateChip.Text = "HELD"
            card.stateChip.BackgroundColor3 = Theme.Held
        else
            card.stateChip.Visible = false
        end
        showPortrait(card.viewport, item, item.characterId .. (item.golden and "_G" or ""))
    end
    self:_paintCard(card)
end

-- Virtualized grid: computes columns / canvas height, then binds pooled cards to the visible rows
-- (plus Config.Layout.BufferRows). `force` re-applies the CanvasSize even when it did not change.
function View:_layoutGrid(force)
    local metrics = self.M
    local grid = self.grid
    local pad = self.mode == "Compact" and 6 or 8
    local width = grid.AbsoluteSize.X - grid.ScrollBarThickness
    if width <= 0 then
        return
    end
    local cols = math.max(1, math.floor((width - pad * 2 + metrics.Gap) / (metrics.CardW + metrics.Gap)))
    -- cards widen (up to +25%) to fill the row instead of leaving wide gutters
    local cardW = math.max(
        metrics.CardW,
        math.min(math.floor(metrics.CardW * 1.25), math.floor((width - pad * 2 - (cols - 1) * metrics.Gap) / cols))
    )
    local itemCount = #self.list
    local rows = math.ceil(itemCount / cols)
    local stepY = metrics.CardH + metrics.Gap
    local canvasH = rows > 0 and (rows * stepY - metrics.Gap + pad * 2) or 0
    if force or self.cols ~= cols or self.canvasH ~= canvasH then
        self.cols, self.canvasH = cols, canvasH
        grid.CanvasSize = UDim2.fromOffset(0, canvasH)
    end
    local used = cols * cardW + (cols - 1) * metrics.Gap
    local startX = math.floor((width - used) / 2)
    local scrollTop = grid.CanvasPosition.Y
    local firstRow = math.max(0, math.floor((scrollTop - pad) / stepY) - Config.Layout.BufferRows)
    local lastRow =
        math.min(rows - 1, math.floor((scrollTop + grid.AbsoluteSize.Y - pad) / stepY) + Config.Layout.BufferRows)

    -- cards keep their index while visible, so a scroll only touches the rows that changed
    local wanted = {}
    for row = firstRow, lastRow do
        for col = 0, cols - 1 do
            local i = row * cols + col + 1
            if i <= itemCount then
                wanted[i] = true
            end
        end
    end
    local released = {}
    for i, card in self.cards do
        if not wanted[i] then
            self.cards[i] = nil
            table.insert(released, card)
        end
    end
    self.spare = self.spare or {}
    for _, card in released do
        if GuiService.SelectedObject == card.frame then
            GuiService.SelectedObject = nil
        end
        card.frame.Visible = false
        table.insert(self.spare, card)
    end
    local multiplier = self.state and self.state.multiplier or 1
    for i in wanted do
        local card = self.cards[i]
        if not card then
            card = table.remove(self.spare) or self:_newCard()
            self.cards[i] = card
        end
        local row, col = (i - 1) // cols, (i - 1) % cols
        card.frame.Position = UDim2.fromOffset(startX + col * (cardW + metrics.Gap), pad + row * stepY)
        card.frame.Size = UDim2.fromOffset(cardW, metrics.CardH)
        card.frame.LayoutOrder = i
        card.frame.Visible = true
        self:_assignCard(card, self.list[i], multiplier)
    end
end

---------------------------------------------------------------- rendering
-- Fits the panel to the usable screen area (viewport = InventoryClient's viewportSize()).
function View:SetSize(viewport)
    local layout = Config.Layout
    local margin = self.mode == "Compact" and 8 or layout.Margin
    local width = math.min(layout.PanelMaxWidth, viewport.X - margin * 2)
    local height = math.min(layout.PanelMaxHeight, viewport.Y - margin * 2 - self.roofH)
    self.root.Size = UDim2.fromOffset(math.max(320, width), math.max(260, height))
    self.root.Position = UDim2.new(0.5, 0, 0.5, math.floor(self.roofH / 2)) -- the roof stands above the panel
end

-- Eight grey placeholder cards (2 rows of 4) inside the pulsing skeleton CanvasGroup; built once.
local function buildSkeletonCards(skeleton, metrics)
    for i = 0, 7 do
        local ghostCard = make("Frame", {
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.Card,
            Size = UDim2.fromOffset(metrics.CardW, metrics.CardH),
            Position = UDim2.fromOffset(
                10 + (i % 4) * (metrics.CardW + metrics.Gap),
                10 + (i // 4) * (metrics.CardH + metrics.Gap)
            ),
        }, skeleton)
        Style.Corner(ghostCard, 6)
        local ghostPortrait = make("Frame", {
            BorderSizePixel = 0,
            BackgroundColor3 = Theme.Portrait,
            Position = UDim2.fromOffset(6, 6),
            Size = UDim2.fromOffset(metrics.CardW - 12, metrics.Portrait),
        }, ghostCard)
        Style.Corner(ghostPortrait, 4)
        for j, widthScale in { 0.6, 0.3, 0.5 } do -- name, label and Power bars
            local bar = make("Frame", {
                BorderSizePixel = 0,
                BackgroundColor3 = Theme.Portrait,
                Size = UDim2.new(widthScale, 0, 0, j == 3 and 18 or 10),
                Position = UDim2.fromOffset(8, metrics.Portrait + 14 + (j - 1) * 20),
            }, ghostCard)
            Style.Corner(bar, 2)
        end
    end
end

-- kind = nil (hide) | "loading" (skeleton) | "empty" | "nomatch" | "error".
function View:_showNote(kind)
    local note = self.note
    if not kind then
        note.Visible = false
        self.skeleton.Visible = false
        return
    end
    note.Visible = kind ~= "loading"
    self.noteButton.Visible = kind == "nomatch"
    self.steps.Visible = kind == "empty"
    self.skeleton.Visible = kind == "loading"
    if kind == "empty" then
        self.noteTitle.Text = "No characters yet"
        self.noteBody.Text = "Your collection starts with your first hatch."
    elseif kind == "nomatch" then
        self.noteTitle.Text = "No characters match"
        self.noteBody.Text = "Try another name or turn a rarity filter off."
    elseif kind == "error" then
        self.noteTitle.Text = "Couldn't load your characters"
        self.noteBody.Text = "Retrying in a moment."
    end
    if kind == "loading" and #self.skeleton:GetChildren() == 0 then
        buildSkeletonCards(self.skeleton, self.M)
    end
end

function View:SetLoadingPulse(alpha)
    self.skeleton.GroupTransparency = alpha
end

-- Removes the slot pips (the UIListLayout stays).
local function clearPips(pips)
    for _, pip in pips:GetChildren() do
        if pip:IsA("Frame") then
            pip:Destroy()
        end
    end
end

-- Full refresh from InventoryClient's state (header, PLACE BEST, filters, grid, details, hints).
function View:Render(state)
    self.state = state
    local items = state.items
    local compact = self.mode == "Compact"

    -- header
    self.owned.Text = state.status == "ready" and (#items == 1 and "1 owned" or (#items .. " owned")) or ""
    local capacity = state.capacity
    if capacity and capacity.hasPlot then
        self.capValue.Text = capacity.placed .. " / " .. capacity.unlocked
        local full = capacity.unlocked > 0 and capacity.placed >= capacity.unlocked
        self.capValue.TextColor3 = full and Theme.PageWarn or Theme.PageText
        self.capLabel.Text = full and "SLOTS · FULL" or "SLOTS"
        self.capLabel.TextColor3 = full and Theme.PageWarn or Theme.PageMuted
        if not compact then
            clearPips(self.pips)
            for i = 1, capacity.total do -- one pip per slot: placed / unlocked-free / locked
                local isFilled = i <= capacity.placed
                local isUnlocked = i <= capacity.unlocked
                local pip = make("Frame", {
                    BorderSizePixel = 0,
                    Size = UDim2.fromOffset(8, 6),
                    LayoutOrder = i,
                    BackgroundColor3 = isFilled and Theme.Placed or (isUnlocked and Theme.Card or Theme.Locked),
                }, self.pips)
                Style.Corner(pip, 1)
                if isUnlocked and not isFilled then
                    Style.Stroke(pip, Theme.Faint, 1, 0.3)
                end
            end
        end
    else
        self.capValue.Text = "—"
        self.capValue.TextColor3 = Theme.PageMuted
        self.capLabel.Text = state.status == "ready" and "NO PLOT" or "SLOTS"
        self.capLabel.TextColor3 = Theme.PageMuted
        if not compact then
            clearPips(self.pips)
        end
    end

    -- PLACE BEST
    local plan = Model.BestPlan(items, capacity, state.allowStore)
    local pendingBest = state.pending and state.pending.action == "PlaceBest"
    local canBest = state.status == "ready"
        and capacity
        and capacity.hasPlot
        and plan.place > 0
        and state.alive
        and not state.pending
    self.bestButton:SetAttribute("Disabled", not canBest)
    self.bestButton.Text = pendingBest and "PLACING…" or "PLACE BEST"
    if self.bestSub then
        local multiplier = state.multiplier or 1
        if pendingBest then
            self.bestSub.Text = ""
        elseif not capacity or not capacity.hasPlot then
            self.bestSub.Text = "claim a plot first"
        elseif plan.place > 0 and plan.gain > 0 then
            self.bestSub.Text = Format.Delta(plan.gain * multiplier, true) .. "/s"
        elseif plan.place > 0 then
            self.bestSub.Text = plan.place .. " to place"
        else
            self.bestSub.Text = "best already placed"
        end
    end

    -- filters + sort
    local noneOn = next(state.rarities) == nil
    local counts = { All = #items }
    for _, item in items do
        counts[item.rarity] = (counts[item.rarity] or 0) + 1
    end
    for id, button in self.rarityButtons do
        local on = (id == "All" and noneOn) or state.rarities[id] == true
        Style.SetOn(button, on)
        if on and id ~= "All" then -- a selected rarity fills with its own colour
            button:SetAttribute("Fill", Theme.Rarity[id])
            button.TextColor3 = Theme.Ink
        end
        -- the original label is remembered once, so the count suffix is never appended twice
        local base = button:GetAttribute("Label") or button.Text
        button:SetAttribute("Label", base)
        button.Text = compact and base or (base .. "  " .. (counts[id] or 0))
    end
    local arrow = state.ascending and " ▲" or " ▼"
    for id, button in self.sortButtons do
        local on = state.sort == id
        local label
        for _, sort in Config.Sorts do
            if sort.Id == id then
                label = sort.Label
            end
        end
        button.Text = label .. (on and arrow or "")
        Style.SetOn(button, on)
    end
    if self.sortCycle then
        local prefix = self.mode == "Compact" and "" or "SORT: "
        for _, sort in Config.Sorts do
            if sort.Id == state.sort then
                self.sortCycle.Text = prefix .. sort.Label .. arrow
            end
        end
    end
    if self.search.Text ~= state.search and not self.search:IsFocused() then
        self.search.Text = state.search
    end

    -- grid
    self.list = Model.Sort(Model.Filter(items, state.search, state.rarities), state.sort, state.ascending)
    if state.status == "loading" then
        self:_showNote("loading")
    elseif state.status == "error" and #items == 0 then
        self:_showNote("error")
    elseif #items == 0 then
        self:_showNote("empty")
    elseif #self.list == 0 then
        self:_showNote("nomatch")
    else
        self:_showNote(nil)
    end
    self:_layoutGrid(true)

    self:_renderDetails(state)

    -- footer
    self.hint.Text = state.inputHint or ""
end

-- Details for state.selectedId: portrait, stats, comparison and the action buttons.
-- Compact layout: also slides the sheet in / out when the selection appears or clears.
function View:_renderDetails(state)
    local parts = self.d
    local selected = state.selectedId and state.byId[state.selectedId]
    self.selected = selected
    if self.mode == "Compact" then
        local open = selected ~= nil
        if open ~= self.detailsOpen then
            self.detailsOpen = open
            if open then
                self.details.Visible = true
                self.details.Position = UDim2.fromScale(0, 1.1)
                TweenService:Create(self.details, SHEET_TWEEN, { Position = UDim2.fromScale(0, 0) }):Play()
            else
                local tween = TweenService:Create(self.details, SHEET_TWEEN, { Position = UDim2.fromScale(0, 1.1) })
                tween.Completed:Connect(function()
                    if not self.detailsOpen then
                        self.details.Visible = false
                    end
                end)
                tween:Play()
            end
        end
    end
    parts.empty.Visible = selected == nil
    parts.content.Visible = selected ~= nil
    parts.footer.Visible = selected ~= nil
    if not selected then
        return
    end

    local multiplier = state.multiplier or 1
    local rarityColor = Theme.Rarity[selected.rarity] or Theme.Rarity.Common
    parts.rarityGlow.BackgroundColor3 = rarityColor
    parts.name.Text = selected.name
    parts.rarityChip.Text = string.upper(selected.rarity)
    parts.rarityChip.BackgroundColor3 = rarityColor
    parts.qualityChip.Text = string.upper(selected.quality) .. " ROLL"
    local notable = selected.qualityRank >= Config.NotableRank
    parts.qualityChip.BackgroundColor3 = notable and Theme.Ink or Theme.Portrait
    parts.qualityChip.TextColor3 = notable and selected.qualityColor or Theme.Text
    parts.stateChip.Visible = selected.state ~= "Backpack"
    parts.stateChip.Text = selected.state == "Placed" and "PLACED" or "HELD"
    parts.stateChip.BackgroundColor3 = selected.state == "Placed" and Theme.Placed or Theme.Held

    parts.power.Text = Format.Short(selected.power)
    parts.power.TextColor3 = notable and selected.qualityColor or Theme.GoldHi -- light on the dark tile
    parts.exact.Text = Format.Exact(selected.power) .. " exact"
    parts.multiplier.Text = Format.Multiplier(selected.power, selected.basePower) .. " of base"
    parts.income.Text = Format.Rate(selected.income * multiplier)
    parts.eventRow.Visible = multiplier ~= 1
    parts.eventValue.Text = "×" .. tostring(multiplier) .. " applied"
    parts.base.Text = Format.Exact(selected.basePower)
    parts.slotRow.Visible = selected.state == "Placed" and selected.slot ~= nil
    parts.slotValue.Text = selected.slot and ("Slot " .. selected.slot) or ""
    parts.acquired.Text = selected.acquired and Format.Ago((state.serverNow or 0) - selected.acquired) or "—"
    self.detailsModel = showPortrait(parts.viewport, selected, selected.characterId .. (selected.golden and "_G" or ""))
        or self.detailsModel

    -- comparison
    local other, why = Model.CompareTarget(state.items, selected, state.pinnedId)
    parts.compareNone.Visible = other == nil
    parts.cmpPowerRow.Visible = other ~= nil
    parts.cmpIncomeRow.Visible = other ~= nil
    if other then
        parts.compareTitle.Text = "VS " .. why .. " · " .. string.upper(other.name)
        local powerDelta = selected.power - other.power
        local incomeDelta = (selected.income - other.income) * multiplier
        parts.cmpPower.Text = Format.Delta(powerDelta)
        parts.cmpPower.TextColor3 = powerDelta > 0 and Theme.Up or (powerDelta < 0 and Theme.Down or Theme.Muted)
        parts.cmpPowerRel.Text = Format.Relative(selected.power, other.power)
        parts.cmpIncome.Text = Format.Delta(incomeDelta, true) .. "/s"
        parts.cmpIncome.TextColor3 = incomeDelta > 0 and Theme.Up or (incomeDelta < 0 and Theme.Down or Theme.Muted)
        parts.cmpIncomeRel.Text = Format.Relative(selected.income, other.income)
    else
        parts.compareTitle.Text = "COMPARE"
    end
    parts.pin.Text = state.pinnedId == selected.id and "UNPIN" or "PIN"
    parts.pin:SetAttribute("Disabled", #state.items < 2)

    -- actions
    local actions = Model.Actions(selected, state.capacity, state.allowStore, state.alive)
    local pending = state.pending
    local buttons = { parts.primary, parts.secondary }
    local reason
    for i, button in buttons do
        local entry = actions[i]
        button.Visible = entry ~= nil
        if entry then
            local busyHere = pending and pending.id == selected.id and pending.action == entry.action
            button.Text = busyHere and "…" or entry.label
            button:SetAttribute("Action", entry.action)
            button:SetAttribute("Disabled", not entry.enabled or pending ~= nil)
            if not entry.enabled and entry.reason and not reason then
                reason = entry.reason
            end
        end
    end
    parts.primary.Size = actions[2] and UDim2.new(0.5, -4, 1, 0) or UDim2.new(0.8, -4, 1, 0)
    parts.reason.Text = reason or ""
    parts.reason.Visible = reason ~= nil
end

-- Footer message; kind = "ok" | "error" | nil. Fades after 2.6 s unless a newer toast replaced it.
function View:Toast(message, kind)
    self.toastSeq = (self.toastSeq or 0) + 1
    local mine = self.toastSeq
    self.toast.Text = message
    self.toast.TextColor3 = kind == "error" and Theme.PageDown or (kind == "ok" and Theme.PageUp or Theme.PageText)
    self.toast.TextTransparency = 0
    task.delay(2.6, function()
        if self.toastSeq == mine and self.toast.Parent then
            TweenService:Create(self.toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
        end
    end)
end

-- Turns only the details portrait, slowly. Called from one RenderStepped while the panel is open.
function View:Step(dt, reducedMotion)
    if reducedMotion or not self.selected or not self.detailsModel or not self.detailsModel.Parent then
        return
    end
    self.spin = ((self.spin or 0) + dt * 18) % 360
    Style.FrameModel(self.d.viewport, self.detailsModel, 20 + math.sin(math.rad(self.spin)) * 28, 1.08)
end

-- Gamepad entry point: the visible card with the lowest index, else the search box.
function View:FirstSelectable()
    local best, bestIndex
    for i, card in self.cards do
        if card.frame.Visible and (not bestIndex or i < bestIndex) then
            best, bestIndex = card.frame, i
        end
    end
    return best or self.search
end

-- Disconnects the tracked UI connections and destroys the panel (pooled cards go with it).
function View:Destroy()
    for _, connection in self.connections do
        connection:Disconnect()
    end
    self.connections = {}
    if self.root then
        self.root:Destroy()
    end
    self.cards, self.spare = {}, {}
end

return View
