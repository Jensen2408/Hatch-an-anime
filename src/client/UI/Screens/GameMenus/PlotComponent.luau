-- GameMenus.PlotComponent  (ModuleScript, client)
-- Draws the Plot menu from the mockup art (PlotConfig / PlotAtlas): one background with the changing parts
-- painted out, pieces of an atlas on top, and FredokaOne labels for the values. Display only: MenuLogic
-- (RENDER.Plot) reads the plot state, formats every value and passes the actions as callbacks.
--
--   PlotCanvas (1382x822 mockup pixels, UIScale = panel width / 1382)
--   ├── Background                          panel, title, stat icons + labels, row icons + texts, milestone
--   ├── Stat1..3                            value labels
--   ├── SlotsTab, UpgradesTab               hit-boxes (+ the swapped tab art on the Upgrades tab)
--   ├── Content (ScrollingFrame)            slot cards, or one row per incubator
--   ├── SlotsText, SlotsFill
--   ├── TempleUpgrades, IncubatorSpeed, IncubatorUpgrades   price + button (names used by FirstHatchTutorial)
--   └── Milestone                           progress dots (+ hit-box while there is something to buy)
--
--   local view = PlotComponent.new(panel, layer, model)   -- builds into `layer`
--   view:Destroy()
--
-- model = {
--   tab = "slots" | "upgrades", scrollY = number?,
--   stats = { { label, value } x3 },
--   slots = { { number, state = "placed" | "empty" | "locked", image?, name?, income?, price?, onActivate?,
--               onRemove? } },   -- a locked slot with onActivate is the next one to buy
--   slotsText, slotsProgress (0..1),
--   upgrades = { { name, title, subtitle, price, enabled, buttonText?, onActivate } x3 },
--   incubators = { { title, subtitle, progress (0..1), price, enabled, buttonText?, onActivate } },
--   milestone = { dots (0..5), onActivate? },
--   onTab(tab), onScroll(y),
-- }
local Config = require(script.Parent:WaitForChild("PlotConfig"))
local Atlas = require(script.Parent:WaitForChild("PlotAtlas"))

local CANVAS = Atlas.Canvas
local Z = 10 -- base ZIndex; layers above it
local PlotComponent = {}
PlotComponent.__index = PlotComponent
PlotComponent.AspectRatio = CANVAS.X / CANVAS.Y

-- ---------- keystone ----------
-- The mockup's sides lean out towards the bottom; the background is drawn with them vertical (PlotAtlas.Keystone).
-- Every mockup coordinate in PlotConfig goes through the same mapping: per row, Left(y)..Right(y) -> Target.
local Keystone = Atlas.Keystone

local function rowSpan(y)
    return Keystone.Left.Offset + Keystone.Left.Slope * y, Keystone.Right.Offset + Keystone.Right.Slope * y
end

local function stretchAt(y)
    local left, right = rowSpan(y)
    return (Keystone.Target.Y - Keystone.Target.X) / (right - left)
end

local function keystoneX(x, y)
    return Keystone.Target.X + (x - rowSpan(y)) * stretchAt(y)
end

local function keystonePoint(point)
    return Vector2.new(keystoneX(point.X, point.Y), point.Y)
end

-- a rect maps at its centre row: same y / height, x moved and the width stretched
local function keystoneRect(r)
    local centreY = r[2] + r[4] / 2
    return { keystoneX(r[1], centreY), r[2], r[3] * stretchAt(centreY), r[4] }
end

-- grid columns: each takes the mean x / width of the mockup's two cards in it (rows: PlotConfig.Grid)
local function keystoneColumns()
    local columns, count = {}, Config.Columns
    for column = 1, count do
        local top, bottom = keystoneRect(Config.Cells[column]), keystoneRect(Config.Cells[count + column])
        columns[column] = { X = (top[1] + bottom[1]) / 2, Width = (top[3] + bottom[3]) / 2 }
    end
    return columns
end

local Layout = {
    Stats = {},
    Tabs = { Slots = keystoneRect(Config.Tabs.Slots), Upgrades = keystoneRect(Config.Tabs.Upgrades) },
    Viewport = keystoneRect(Config.Viewport),
    Columns = keystoneColumns(),
    UpgradeRows = {},
    Milestone = {
        Rect = keystoneRect(Config.Milestone.Rect),
        Dots = {
            First = keystonePoint(Config.Milestone.Dots.First),
            Step = Config.Milestone.Dots.Step * stretchAt(Config.Milestone.Dots.First.Y),
            Count = Config.Milestone.Dots.Count,
        },
    },
    FooterText = keystoneRect(Config.Footer.Text),
    FooterBar = keystoneRect(Config.Footer.Bar),
    FooterMinFill = Config.Footer.MinFill * stretchAt(Config.Footer.Bar[2]),
}
for i, value in Config.Stats.Values do
    Layout.Stats[i] = keystoneRect(value.Rect)
end
for i, row in Config.UpgradeRows do
    Layout.UpgradeRows[i] = {
        Name = row.Name,
        Row = keystoneRect(row.Row),
        Price = keystonePoint(row.Price),
        Button = keystoneRect(row.Button),
    }
end
Layout.IncubatorWidth = Layout.Viewport[3] - (Config.Viewport[3] - Config.IncubatorRows.Width)

local function rect(instance, r)
    instance.Position = UDim2.fromOffset(r[1], r[2])
    instance.Size = UDim2.fromOffset(r[3], r[4])
end

local function new(className, name, parent, zIndex)
    local instance = Instance.new(className)
    instance.Name = name
    if instance:IsA("GuiObject") then
        instance.BackgroundTransparency = 1
        instance.BorderSizePixel = 0
        instance.ZIndex = zIndex or Z
    end
    instance.Parent = parent
    return instance
end

-- one atlas piece, drawn at its mockup size unless a rect is given
local function piece(parent, name, pieceName, position, zIndex)
    local info = Atlas.Pieces[pieceName]
    local image = new("ImageLabel", name, parent, zIndex)
    image.Image = Config.Pieces
    image.ImageRectOffset = Vector2.new(info.Rect[1], info.Rect[2])
    image.ImageRectSize = Vector2.new(info.Rect[3], info.Rect[4])
    image.Position = UDim2.fromOffset(position.X, position.Y)
    image.Size = UDim2.fromOffset(info.Size.X, info.Size.Y)
    return image
end

-- a piece 9-sliced to `r`: its borders keep their mockup size
local function slicedPiece(parent, name, pieceName, r, sliceCenter, zIndex)
    local info = Atlas.Pieces[pieceName]
    local image = piece(parent, name, pieceName, Vector2.zero, zIndex)
    image.ScaleType = Enum.ScaleType.Slice
    image.SliceCenter = sliceCenter
    image.SliceScale = info.Size.X / info.Rect[3]
    rect(image, r)
    return image
end

local function label(parent, name, text, r, size, color, zIndex, options)
    options = options or {}
    local textLabel = new("TextLabel", name, parent, zIndex)
    textLabel.FontFace = Config.Font
    textLabel.Text = text
    textLabel.TextSize = size
    textLabel.TextColor3 = color
    textLabel.TextXAlignment = options.alignX or Enum.TextXAlignment.Center
    textLabel.TextWrapped = options.wrap == true
    if options.fit then
        textLabel.TextScaled = true
        local limit = Instance.new("UITextSizeConstraint")
        limit.MaxTextSize = size
        limit.Parent = textLabel
    end
    rect(textLabel, r)
    local stroke = Instance.new("UIStroke")
    stroke.Color = Config.Stroke
    stroke.Thickness = options.stroke or 3
    stroke.LineJoinMode = Enum.LineJoinMode.Round
    stroke.Enabled = (options.stroke or 3) > 0
    stroke.Parent = textLabel
    return textLabel
end

local function hitBox(parent, name, r, onActivate, zIndex)
    local button = new("TextButton", name, parent, zIndex)
    button.Text = ""
    button.AutoButtonColor = false
    rect(button, r)
    button.Activated:Connect(onActivate)
    return button
end

-- coin + price, the pair centred on `centre` (hidden for "MAX": a maxed upgrade says so on its button)
local function priceRow(parent, name, centre, text, color, coinPiece, textSize, zIndex)
    local coin = Atlas.Pieces[coinPiece].Size
    local row = new("Frame", name, parent, zIndex)
    row.Visible = text ~= "MAX"
    row.AnchorPoint = Vector2.new(0.5, 0.5)
    row.Position = UDim2.fromOffset(centre.X, centre.Y)
    row.AutomaticSize = Enum.AutomaticSize.X
    row.Size = UDim2.fromOffset(0, math.max(coin.Y, textSize))
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, Config.Card.CoinGap)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = row
    local image = piece(row, "Coin", coinPiece, Vector2.zero, zIndex)
    image.LayoutOrder = 1
    local value = label(row, "Price", text, { 0, 0, 0, textSize }, textSize, color, zIndex, {
        stroke = Config.Card.PriceStroke,
    })
    value.AutomaticSize = Enum.AutomaticSize.X
    value.LayoutOrder = 2
    return row
end

-- buy button of an upgrade row: green PURCHASE art, or the grey button with the reason / MAX
local function buyButton(parent, r, item, zIndex)
    if item.enabled then
        slicedPiece(parent, "Purchase", "PurchaseButton", r, Rect.new(12, 8, 100, 34), zIndex)
    else
        slicedPiece(parent, "Disabled", "GreyButton", r, Rect.new(12, 8, 95, 34), zIndex)
        local style, inset = Config.GreyButtonText, Config.GreyButtonText.Inset
        label(
            parent,
            "Reason",
            item.buttonText or "MAX",
            { r[1] + inset[1], r[2] + inset[2], r[3] - inset[1] * 2, r[4] - inset[2] * 2 - 4 },
            style.TextSize,
            style.Color,
            zIndex + 1,
            { wrap = true, fit = true, stroke = 0 }
        )
    end
    hitBox(parent, "Buy", r, item.onActivate, zIndex + 2)
end

local function dots(parent, layout, filled, zIndex)
    for i = 1, layout.Count do
        local size = Atlas.Pieces.DotOn.Size
        local centre = layout.First + Vector2.new((i - 1) * layout.Step, 0)
        piece(parent, "Dot" .. i, i <= filled and "DotOn" or "DotOff", centre - size / 2, zIndex)
    end
end

-- ---------- slot cards ----------
-- every card the same height, rows PlotConfig.Grid.Pitch apart
local function cellRect(index)
    local grid = Config.Grid
    local row, column = (index - 1) // Config.Columns, Layout.Columns[(index - 1) % Config.Columns + 1]
    return { column.X, grid.Top + row * grid.Pitch, column.Width, grid.Height }
end

-- template frame (mockup card height), shrunk to fit a shorter card, centred at the top
local function template(card, width, height, templateHeight)
    local scale = math.min(1, height / templateHeight)
    local frame = new("Frame", "Contents", card, Z + 4) -- above the card art (Sibling ZIndexBehavior)
    frame.AnchorPoint = Vector2.new(0.5, 0)
    frame.Position = UDim2.fromScale(0.5, 0)
    frame.Size = UDim2.fromOffset(width / scale, templateHeight)
    local uiScale = Instance.new("UIScale")
    uiScale.Scale = scale
    uiScale.Parent = frame
    return frame, width / scale
end

function PlotComponent:_slotCard(parent, slot, r)
    local cardStyle, colors = Config.Card, Config.Card.Colors
    local card = new("Frame", string.format("Slot%02d", slot.number), parent, Z + 2)
    rect(card, r)
    local w, h = r[3], r[4]
    slicedPiece(card, "Frame", "Card", { 0, 0, w, h }, cardStyle.SliceCenter, Z + 2)
    local isNext = slot.state == "locked" and slot.onActivate ~= nil
    if isNext then
        local out = cardStyle.GlowOutset
        slicedPiece(
            card,
            "Glow",
            "Glow",
            { -out[1], -out[2], w + out[1] + out[3], h + out[2] + out[4] },
            cardStyle.GlowSliceCenter,
            Z + 3
        )
    end
    local number = cardStyle.Number
    label(
        card,
        "Number",
        tostring(slot.number),
        { number.Centre.X - 20, number.Centre.Y - 20, 40, 40 },
        number.TextSize,
        colors.White,
        Z + 4,
        { stroke = number.Stroke }
    )

    if slot.state == "placed" then
        local style = cardStyle.Placed
        local contents, tw = template(card, w, h, style.Height)
        if slot.image and slot.image ~= "" then
            local portrait = new("ImageLabel", "Portrait", contents, Z + 4)
            portrait.Image = slot.image
            portrait.ScaleType = Enum.ScaleType.Fit
            local p = style.Portrait
            rect(portrait, { (tw - p[3]) / 2, p[2], p[3], p[4] })
        end
        label(
            contents,
            "Name",
            string.upper(slot.name or ""),
            { 8, style.NameY - 16, tw - 16, 32 },
            style.NameSize,
            colors.White,
            Z + 4,
            { fit = true }
        )
        priceRow(
            contents,
            "Income",
            Vector2.new(tw / 2, style.IncomeY),
            slot.income or "",
            colors.Green,
            "CoinGreen",
            style.IncomeSize,
            Z + 4
        )
        local button = piece(
            contents,
            "Remove",
            "RemoveButton",
            Vector2.new((tw - Atlas.Pieces.RemoveButton.Size.X) / 2, style.Button[2]),
            Z + 4
        )
        if slot.onRemove then
            hitBox(button, "Hit", { 0, 0, button.Size.X.Offset, button.Size.Y.Offset }, slot.onRemove, Z + 6)
        end
    elseif slot.state == "empty" then
        label(card, "Empty", "EMPTY", { 0, h / 2 - 20, w, 40 }, cardStyle.EmptySize, colors.Locked, Z + 4)
    elseif isNext then
        local style = cardStyle.Next
        local contents, tw = template(card, w, h, style.Height)
        local lock, nextLabel, unlock =
            Atlas.Pieces.LockGold.Size, Atlas.Pieces.NextSlot.Size, Atlas.Pieces.UnlockButton.Size
        piece(contents, "Lock", "LockGold", Vector2.new((tw - lock.X) / 2, style.Lock[2]), Z + 4)
        piece(contents, "NextSlot", "NextSlot", Vector2.new((tw - nextLabel.X) / 2, style.Label[2]), Z + 4)
        priceRow(
            contents,
            "Price",
            Vector2.new(tw / 2, style.PriceY),
            slot.price or "",
            colors.Green,
            "CoinGreen",
            cardStyle.PriceSize,
            Z + 4
        )
        piece(contents, "Unlock", "UnlockButton", Vector2.new((tw - unlock.X) / 2, style.Button[2]), Z + 4)
        hitBox(card, "Hit", { 0, 0, w, h }, slot.onActivate, Z + 6)
    else
        local style = cardStyle.Locked
        local tall = h >= 200
        local priceY = tall and style.TallPriceY + (h - 219) / 2 or math.floor(h * style.ShortPriceRatio + 0.5)
        local lockTop = priceY - (tall and style.LockAbovePrice or style.ShortLockAbovePrice)
        local lock = Atlas.Pieces.LockGrey.Size
        piece(card, "Lock", "LockGrey", Vector2.new((w - lock.X) / 2, lockTop), Z + 4)
        priceRow(
            card,
            "Price",
            Vector2.new(w / 2, priceY),
            slot.price or "",
            colors.Locked,
            "CoinGrey",
            cardStyle.PriceSize,
            Z + 4
        )
    end
    return card
end

function PlotComponent:_incubatorRow(parent, i, item, y)
    local style = Config.IncubatorRows
    local w, h = Layout.IncubatorWidth, style.Height
    local row = new("Frame", "Incubator" .. i, parent, Z + 2)
    rect(row, { 0, y, w, h })
    slicedPiece(row, "Frame", "RowBlank", { 0, 0, w, h }, style.RowSlice, Z + 2)
    piece(row, "Egg", "Egg", Vector2.new(style.Egg[1], style.Egg[2]), Z + 3)
    label(
        row,
        "Title",
        item.title,
        style.Title,
        style.TitleSize,
        Config.Card.Colors.White,
        Z + 3,
        { alignX = Enum.TextXAlignment.Left }
    )
    label(row, "Subtitle", item.subtitle, style.Subtitle, style.SubtitleSize, style.SubtitleColor, Z + 3, {
        alignX = Enum.TextXAlignment.Left,
        fit = true,
        stroke = 2,
    })
    dots(row, style.Dots, math.floor((item.progress or 0) * style.Dots.Count + 0.5), Z + 3)
    local priceStyle = Config.UpgradePrice
    priceRow(
        row,
        "Price",
        Vector2.new(w - style.PriceRight, style.PriceY),
        item.price,
        item.enabled and Config.Card.Colors.Green or priceStyle.Off,
        item.enabled and "CoinGreenSmall" or "CoinGreySmall",
        priceStyle.TextSize,
        Z + 3
    )
    local b = style.Button
    buyButton(row, { w - b[1], b[2], b[3], b[4] }, item, Z + 3)
end

function PlotComponent:_buildContent()
    local view = Layout.Viewport
    local scroller = new("ScrollingFrame", "Content", self.canvas, Z + 1)
    rect(scroller, view)
    scroller.ScrollingDirection = Enum.ScrollingDirection.Y
    scroller.ScrollBarThickness = 6
    scroller.ScrollBarImageColor3 = Config.Card.Colors.Locked
    scroller.CanvasSize = UDim2.new()
    local height = 0
    if self.model.tab == "upgrades" then
        local style = Config.IncubatorRows
        for i, item in self.model.incubators do
            local y = 6 + (i - 1) * (style.Height + style.Gap)
            self:_incubatorRow(scroller, i, item, y)
            height = y + style.Height
        end
    else
        for i, slot in self.model.slots do
            local r = cellRect(i)
            local cell = { r[1] - view[1], r[2] - view[2], r[3], r[4] } -- viewport coordinates
            self:_slotCard(scroller, slot, cell)
            height = math.max(height, cell[2] + cell[4])
        end
    end
    height += Config.ScrollBottomPad
    scroller.CanvasSize = UDim2.fromOffset(0, height)
    scroller.CanvasPosition = Vector2.new(0, math.clamp(self.model.scrollY or 0, 0, math.max(0, height - view[4])))
    scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        self.model.onScroll(scroller.CanvasPosition.Y)
    end)
end

function PlotComponent:_buildTabs()
    local tabs = Layout.Tabs
    if self.model.tab == "upgrades" then
        rect(piece(self.canvas, "SlotsTabArt", "TabSlotsOff", Vector2.zero, Z + 1), tabs.Slots)
        rect(piece(self.canvas, "UpgradesTabArt", "TabUpgradesOn", Vector2.zero, Z + 1), tabs.Upgrades)
    end
    hitBox(self.canvas, "SlotsTab", tabs.Slots, function()
        self.model.onTab("slots")
    end, Z + 3)
    hitBox(self.canvas, "UpgradesTab", tabs.Upgrades, function()
        self.model.onTab("upgrades")
    end, Z + 3)
end

function PlotComponent:_buildRight()
    local priceStyle = Config.UpgradePrice
    for i, rowConfig in Layout.UpgradeRows do
        local item = self.model.upgrades[i]
        if item then
            local row = new("Frame", rowConfig.Name, self.canvas, Z + 1)
            rect(row, rowConfig.Row)
            local origin = Vector2.new(rowConfig.Row[1], rowConfig.Row[2])
            priceRow(
                row,
                "Price",
                rowConfig.Price - origin,
                item.price,
                item.enabled and Config.Card.Colors.Green or priceStyle.Off,
                item.enabled and "CoinGreenSmall" or "CoinGreySmall",
                priceStyle.TextSize,
                Z + 2
            )
            local b = rowConfig.Button
            buyButton(row, { b[1] - origin.X, b[2] - origin.Y, b[3], b[4] }, item, Z + 2)
        end
    end
end

function PlotComponent:_buildFooter()
    local footer = Config.Footer
    label(
        self.canvas,
        "SlotsText",
        self.model.slotsText,
        Layout.FooterText,
        footer.TextSize,
        Config.Card.Colors.White,
        Z + 1,
        {
            alignX = Enum.TextXAlignment.Left,
            fit = true,
        }
    )
    local ratio = math.clamp(self.model.slotsProgress or 0, 0, 1)
    if ratio > 0 then
        local bar = Layout.FooterBar
        local width = ratio >= 1 and bar[3] or math.max(Layout.FooterMinFill, math.floor(bar[3] * ratio + 0.5))
        slicedPiece(self.canvas, "SlotsFill", "BarFill", { bar[1], bar[2], width, bar[4] }, footer.BarSlice, Z + 1)
    end
    local milestone, model = Layout.Milestone, self.model.milestone
    local frame = new("Frame", "Milestone", self.canvas, Z + 1)
    rect(frame, milestone.Rect)
    local origin = Vector2.new(milestone.Rect[1], milestone.Rect[2])
    dots(frame, {
        First = milestone.Dots.First - origin,
        Step = milestone.Dots.Step,
        Count = milestone.Dots.Count,
    }, model.dots or 0, Z + 2)
    if model.onActivate then
        hitBox(frame, "Hit", { 0, 0, milestone.Rect[3], milestone.Rect[4] }, model.onActivate, Z + 3)
    end
end

function PlotComponent.new(panel, layer, model)
    local self = setmetatable({ model = model }, PlotComponent)
    -- the panel's own skin and Close button are not part of this art (closing: click outside / the Plot button)
    for _, name in { "CleanSkin", "CleanBase", "FigmaWindow", "Close" } do
        local child = panel:FindFirstChild(name)
        if child and child:IsA("GuiObject") then
            child.Visible = false
        end
    end
    local canvas = new("Frame", "PlotCanvas", layer, Z)
    canvas.AnchorPoint = Vector2.new(0.5, 0.5)
    canvas.Position = UDim2.fromScale(0.5, 0.5)
    canvas.Size = UDim2.fromOffset(CANVAS.X, CANVAS.Y)
    local scale = Instance.new("UIScale")
    scale.Parent = canvas
    local function fit()
        scale.Scale = math.max(panel.Size.X.Offset, 1) / CANVAS.X
    end
    fit()
    self.sizeConnection = panel:GetPropertyChangedSignal("Size"):Connect(fit)
    self.canvas = canvas

    local background = new("ImageLabel", "Background", canvas, Z)
    background.Image = Config.Background
    background.Size = UDim2.fromScale(1, 1)
    local stats = Config.Stats
    for i, value in stats.Values do
        local stat = model.stats[i]
        if stat then
            label(canvas, "Stat" .. i, stat[2], Layout.Stats[i], stats.TextSize, value.Color, Z + 1, {
                alignX = Enum.TextXAlignment.Left,
                fit = true,
                stroke = stats.StrokeThickness,
            })
        end
    end
    self:_buildTabs()
    self:_buildContent()
    self:_buildRight()
    self:_buildFooter()
    canvas.Parent = layer
    return self
end

function PlotComponent:Destroy()
    self.sizeConnection:Disconnect()
    self.canvas:Destroy()
end

return PlotComponent
