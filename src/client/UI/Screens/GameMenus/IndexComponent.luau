-- GameMenus.IndexComponent  (ModuleScript, client)
-- Draws the Character Index menu from the mockup art (IndexConfig / IndexAtlas): one background with the changing
-- parts painted out, atlas pieces on top, FredokaOne labels for the values. Display only: MenuLogic (RENDER.Index)
-- reads the catalogue / discovered state and passes the actions as callbacks. Typing in the search box filters the
-- grid here, without a re-render.
--
--   IndexCanvas (1270x840 mockup pixels, UIScale = panel width / 1270)
--   ├── Background                       panel, title, Winter tab, rewards box, DISCOVERED pill, ...
--   ├── Season_Original / _Halloween     tab art + hit-box (Season_Winter: hit-box only)
--   ├── CollectionFill, CollectionText
--   ├── Search, Filter_<rarity>          characters / eggs pages only
--   ├── Grid (ScrollingFrame)            cards
--   ├── Detail                           selected card
--   ├── Reward1..3                       chests (+ CLAIM while ready)
--   └── Page_<name>                      bottom tabs
--
--   local view = IndexComponent.new(panel, layer, model)
--   view:Destroy()
--
-- model = {
--   page = "Characters" | "Eggs" | "Mutations", onPage(page),
--   season = "Original" | "Halloween", onSeason(season), onWinter(),
--   collectionText, progress (0..1),
--   filters = { { key, selected } }, onFilter(key), search, onSearch(text),   (ignored on Mutations)
--   cards = { { id, name, rarity, image?, egg?, discovered, selected, mutation?, badge?, subtitle? } },
--   onSelect(id),
--   selected = { name, rarity, image?, egg?, obtain, badge?, status? }?,   status replaces DISCOVERED
--   rewards = { { at, state = "locked" | "ready" | "claimed", onActivate } } x3,
--   scrollY, onScroll(y),
-- }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("IndexConfig"))
local Atlas = require(script.Parent:WaitForChild("IndexAtlas"))

local CANVAS = Atlas.Canvas
local Z = 10 -- base ZIndex; layers above it
local IndexComponent = {}
IndexComponent.__index = IndexComponent
IndexComponent.AspectRatio = CANVAS.X / CANVAS.Y

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

-- one atlas piece at its mockup size, top-left at `position`
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

-- a piece 9-sliced to `r`; margins in mockup pixels (a number, or { left, top, right, bottom })
local function sliced(parent, name, pieceName, r, margins, zIndex)
    local info = Atlas.Pieces[pieceName]
    local image = piece(parent, name, pieceName, Vector2.zero, zIndex)
    local toAtlas = info.Rect[3] / info.Size.X
    local m = type(margins) == "table" and margins or { margins, margins, margins, margins }
    image.ScaleType = Enum.ScaleType.Slice
    image.SliceCenter =
        Rect.new(m[1] * toAtlas, m[2] * toAtlas, info.Rect[3] - m[3] * toAtlas, info.Rect[4] - m[4] * toAtlas)
    image.SliceScale = 1 / toAtlas
    rect(image, r)
    return image
end

local function placed(parent, spec, zIndex)
    return piece(parent, spec[1], spec[1], Vector2.new(spec[2], spec[3]), zIndex)
end

local function label(parent, name, text, r, size, color, zIndex, options)
    options = options or {}
    local textLabel = new("TextLabel", name, parent, zIndex)
    textLabel.FontFace = Config.Font
    textLabel.Text = text
    textLabel.TextColor3 = color
    textLabel.TextXAlignment = options.alignX or Enum.TextXAlignment.Center
    textLabel.TextWrapped = options.wrap == true
    textLabel.TextScaled = true
    local limit = Instance.new("UITextSizeConstraint")
    limit.MaxTextSize = size
    limit.Parent = textLabel
    rect(textLabel, r)
    local thickness = options.stroke or 3
    if thickness > 0 then
        local stroke = Instance.new("UIStroke")
        stroke.Color = Config.Stroke
        stroke.Thickness = thickness
        stroke.LineJoinMode = Enum.LineJoinMode.Round
        stroke.Parent = textLabel
    end
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

-- rarity pill: the piece sized to its text, right edge at `right`
local function badge(parent, pieceName, text, right, top, style, zIndex)
    local textWidth = TextService:GetTextSize(text, style.TextSize, Enum.Font.FredokaOne, Vector2.new(1000, 100)).X
    local width = textWidth + style.Padding * 2
    local frame = new("Frame", "Badge", parent, zIndex)
    rect(frame, { right - width, top, width, style.Height })
    sliced(frame, "Art", pieceName, { 0, 0, width, style.Height }, 12, zIndex)
    local value = label(
        frame,
        "Text",
        text,
        { 0, 0, width, style.Height - 2 },
        style.TextSize,
        Config.White,
        zIndex + 1,
        {
            stroke = 2,
        }
    )
    value.TextScaled = false
    value.TextSize = style.TextSize
    return frame
end

-- the egg's menu model in a ViewportFrame (black when undiscovered)
local function eggView(parent, modelName, r, silhouette, zIndex)
    local previews = ReplicatedStorage:FindFirstChild("GameMenu")
    previews = previews and previews:FindFirstChild("EggPreviews")
    local model = previews and modelName and previews:FindFirstChild(modelName)
    if not model then
        return
    end
    local viewport = new("ViewportFrame", "Egg", parent, zIndex)
    rect(viewport, r)
    viewport.Ambient = Color3.new(1, 1, 1)
    viewport.LightColor = Color3.new(1, 1, 1)
    viewport.LightDirection = Vector3.new(-0.4, -0.6, -1)
    if silhouette then
        viewport.ImageColor3 = Color3.new(0, 0, 0)
    end
    local egg = model:Clone()
    egg.Parent = viewport
    local boundsCFrame, boundsSize = egg:GetBoundingBox()
    egg:PivotTo(CFrame.new(-boundsCFrame.Position) * egg:GetPivot())
    local camera = Instance.new("Camera")
    camera.FieldOfView = 40
    camera.CFrame = CFrame.lookAt(Vector3.new(0, boundsSize.Y * 0.08, -boundsSize.Magnitude * 1.25), Vector3.zero)
    camera.Parent = viewport
    viewport.CurrentCamera = camera
    return viewport
end

local function portrait(parent, image, r, silhouette, zIndex)
    if not image or image == "" then
        return
    end
    local picture = new("ImageLabel", "Portrait", parent, zIndex)
    picture.Image = image
    picture.ScaleType = Enum.ScaleType.Fit
    if silhouette then
        picture.ImageColor3 = Color3.new(0, 0, 0)
    end
    rect(picture, r)
    return picture
end

-- ---------- cards ----------
function IndexComponent:_card(parent, card, x, y)
    local grid = Config.Grid
    local w, h = grid.CardSize.X, grid.CardSize.Y
    local frame = new("Frame", "Card_" .. card.id, parent, Z + 2)
    rect(frame, { x, y, w, h })
    local mutation = card.mutation and Config.Mutations[card.mutation]
    local art = mutation
        or Config.RarityPieces[card.discovered and card.rarity or "Locked"]
        or Config.RarityPieces.Common
    sliced(frame, "Art", card.selected and "CardSelected" or art.Card, { 0, 0, w, h }, grid.CardSlice, Z + 2)
    if card.selected then
        local o = grid.GlowOutset
        sliced(frame, "Glow", "SelectedGlow", { -o, -o, w + o * 2, h + o * 2 }, grid.GlowSlice, Z + 3)
    end
    local p = grid.Portrait
    if mutation then
        local icon = piece(frame, "Icon", "IconDna", Vector2.zero, Z + 4)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position = UDim2.fromOffset(w / 2, p[2] + p[4] * 0.42)
        icon.Size = UDim2.fromOffset(96, 104)
        label(frame, "Subtitle", card.subtitle or "", { 8, p[2] + p[4] - 44, w - 16, 34 }, 30, mutation.Color, Z + 4)
    elseif card.egg then
        eggView(frame, card.egg, { p[1] + 20, p[2] + 14, p[3] - 40, p[4] - 20 }, not card.discovered, Z + 4)
    else
        portrait(frame, card.image, p, not card.discovered, Z + 4)
    end
    local style = grid.Badge
    local badgeArt = card.discovered and art.Badge or Config.RarityPieces.Locked.Badge
    local badgeText = card.badge or (card.discovered and card.rarity or "???")
    badge(frame, badgeArt, badgeText, w - style.Right, style.Top, style, Z + 5)
    label(
        frame,
        "Name",
        card.discovered and string.upper(card.name) or "???",
        grid.Name,
        grid.NameSize,
        Config.White,
        Z + 5
    )
    if card.discovered then
        hitBox(frame, "Hit", { 0, 0, w, h }, function()
            self.model.onSelect(card.id)
        end, Z + 7)
    end
end

-- cards whose name contains the search text (case-insensitive; undiscovered names never match)
function IndexComponent:_fillGrid()
    local grid, scroller = Config.Grid, self.grid
    for _, child in scroller:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    local view = grid.Viewport
    local needle = string.lower(self.search)
    local shown = 0
    for _, card in self.model.cards do
        local haystack = card.discovered and string.lower(card.name) or ""
        if needle == "" or string.find(haystack, needle, 1, true) then
            local column, row = shown % #grid.Columns, shown // #grid.Columns
            self:_card(scroller, card, grid.Columns[column + 1] - view[1], grid.Top + row * grid.Pitch - view[2])
            shown += 1
        end
    end
    if shown == 0 then
        label(scroller, "Empty", "No characters found", grid.Empty, 26, Config.White, Z + 2)
    end
    local rows = math.ceil(shown / #grid.Columns)
    local height = rows > 0 and (grid.Top - view[2]) + (rows - 1) * grid.Pitch + grid.CardSize.Y + grid.BottomPad or 0
    scroller.CanvasSize = UDim2.fromOffset(0, height)
    return height
end

-- ---------- detail ----------
function IndexComponent:_buildDetail()
    local style, selected = Config.Detail, self.model.selected
    local frame = new("Frame", "Detail", self.canvas, Z + 1)
    frame.Size = UDim2.fromScale(1, 1)
    if not selected then
        local cover = new("Frame", "EmptyCover", frame, Z + 1)
        rect(cover, style.Empty)
        label(frame, "Empty", style.EmptyText, style.Empty, 32, Config.White, Z + 2, { wrap = true })
        return
    end
    local mutation = selected.mutation and Config.Mutations[selected.mutation]
    if mutation then
        local icon = piece(frame, "Icon", "IconDna", Vector2.zero, Z + 2)
        icon.AnchorPoint = Vector2.new(0.5, 0.5)
        icon.Position =
            UDim2.fromOffset(style.Portrait[1] + style.Portrait[3] / 2, style.Portrait[2] + style.Portrait[4] / 2)
        icon.Size = UDim2.fromOffset(170, 184)
    elseif selected.egg and not selected.image then
        eggView(frame, selected.egg, style.Portrait, false, Z + 2)
    else
        portrait(frame, selected.image, style.Portrait, false, Z + 2)
    end
    local art = mutation or Config.RarityPieces[selected.rarity] or Config.RarityPieces.Common
    badge(
        frame,
        art.Badge,
        selected.badge or selected.rarity or "",
        style.Badge.Right,
        style.Badge.Top,
        style.Badge,
        Z + 3
    )
    label(frame, "Name", string.upper(selected.name), style.Name, style.NameSize, Config.White, Z + 3)
    if selected.status then
        local cover = new("Frame", "StatusCover", frame, Z + 3)
        cover.BackgroundTransparency = 0
        cover.BackgroundColor3 = style.StatusCover
        rect(cover, style.Status)
        label(
            frame,
            "Status",
            selected.status,
            style.Status,
            style.StatusSize,
            mutation and mutation.Color or style.StatusColor,
            Z + 4
        )
    end
    if selected.egg then
        eggView(frame, selected.egg, style.ObtainIcon, false, Z + 3)
    elseif mutation then
        local obtainIcon = piece(frame, "ObtainIcon", "IconDna", Vector2.zero, Z + 3)
        local r = style.ObtainIcon
        obtainIcon.AnchorPoint = Vector2.new(0.5, 0.5)
        obtainIcon.Position = UDim2.fromOffset(r[1] + r[3] / 2, r[2] + r[4] / 2)
    end
    label(frame, "Obtain", selected.obtain or "", style.Obtain, style.ObtainSize, Config.White, Z + 3, {
        alignX = Enum.TextXAlignment.Left,
        stroke = 2,
    })
end

-- ---------- collection rewards ----------
function IndexComponent:_buildRewards()
    local style = Config.Rewards
    for i, reward in self.model.rewards or {} do
        local spec = style.List[i]
        if spec then
            local chestPos = spec.Position
            local info = Atlas.Pieces[spec.Chest]
            local chest = piece(self.canvas, "Reward" .. i, spec.Chest, chestPos, Z + 2)
            chest.AnchorPoint = Vector2.new(0.5, 0.5)
            chest.Position = UDim2.fromOffset(chestPos.X + info.Size.X / 2, chestPos.Y + info.Size.Y / 2)
            local pill = spec.Pill
            if reward.state == "claimed" then
                chest.ImageTransparency = style.ClaimedTransparency
                label(
                    self.canvas,
                    "Claimed" .. i,
                    "✓",
                    { pill[1], pill[2] - 34, pill[3], 30 },
                    30,
                    Config.White,
                    Z + 3
                )
            elseif reward.state == "ready" then
                sliced(self.canvas, "ClaimPill" .. i, "ClaimPill", pill, style.PillSlice, Z + 3)
                label(self.canvas, "Claim" .. i, "CLAIM", pill, style.PillText, Config.White, Z + 4, { stroke = 2 })
                local scale = Instance.new("UIScale")
                scale.Parent = chest
                local tween = TweenService:Create(
                    scale,
                    TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
                    { Scale = style.Pulse }
                )
                tween:Play()
                table.insert(self.tweens, tween)
                local x0, y0 = math.min(chestPos.X, pill[1]), chestPos.Y
                hitBox(self.canvas, "ClaimHit" .. i, {
                    x0,
                    y0,
                    math.max(chestPos.X + info.Size.X, pill[1] + pill[3]) - x0,
                    pill[2] + pill[4] - y0,
                }, reward.onActivate, Z + 6)
            end
        end
    end
end

-- ---------- tabs ----------
function IndexComponent:_buildSeasons()
    local seasons = Config.Seasons
    for _, key in { "Original", "Halloween" } do
        local spec = seasons[key]
        local selected = self.model.season == key
        sliced(
            self.canvas,
            "SeasonArt_" .. key,
            selected and "TabOn" or "TabOff",
            spec.Selected, -- both states cover the larger selected tab baked into the background
            seasons.Slice,
            Z + 1
        )
        placed(self.canvas, spec.Icon, Z + 2)
        placed(self.canvas, spec.Label, Z + 2)
        hitBox(self.canvas, "Season_" .. key, spec.Rect, function()
            self.model.onSeason(key)
        end, Z + 3)
    end
    hitBox(self.canvas, "Season_Winter", seasons.Winter.Rect, self.model.onWinter, Z + 3)
end

function IndexComponent:_buildPages()
    local pages = Config.Pages
    for _, key in { "Characters", "Eggs", "Mutations" } do
        local spec = pages[key]
        sliced(
            self.canvas,
            "PageArt_" .. key,
            self.model.page == key and pages.On or spec.Off,
            spec.Rect,
            pages.Slice,
            Z + 1
        )
        placed(self.canvas, spec.Icon, Z + 2)
        placed(self.canvas, spec.Label, Z + 2)
        hitBox(self.canvas, "Page_" .. key, spec.Rect, function()
            self.model.onPage(key)
        end, Z + 3)
    end
end

function IndexComponent:_buildToolbar()
    local search = Config.Search
    sliced(self.canvas, "SearchArt", "SearchBox", search.Rect, search.Slice, Z + 1)
    piece(self.canvas, "SearchIcon", "IconSearch", Vector2.new(search.Icon[1], search.Icon[2]), Z + 2)
    local box = new("TextBox", "Search", self.canvas, Z + 2)
    rect(box, search.Box)
    box.FontFace = Config.Font
    box.TextSize = search.TextSize
    box.TextColor3 = Config.White
    box.PlaceholderText = search.Placeholder[self.model.page] or search.Placeholder.Characters
    box.PlaceholderColor3 = search.PlaceholderColor
    box.TextXAlignment = Enum.TextXAlignment.Left
    box.ClearTextOnFocus = false
    box.Text = self.search
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if #box.Text > search.MaxLength then
            box.Text = string.sub(box.Text, 1, search.MaxLength)
        elseif box.Text ~= self.search then
            self.search = box.Text
            self.model.onSearch(box.Text)
            self:_fillGrid()
        end
    end)

    local filters = Config.Filters
    local selectedKey
    for _, filter in self.model.filters or {} do
        if filter.selected then
            selectedKey = filter.key
        end
    end
    local x = filters.X
    for _, filter in filters.List do
        local r = { x, filters.Y, filter.Width, filters.Height }
        sliced(
            self.canvas,
            "FilterArt_" .. filter.Key,
            selectedKey == filter.Key and "FilterAll" or filter.Piece,
            r,
            filters.Slice,
            Z + 1
        )
        label(
            self.canvas,
            "FilterText_" .. filter.Key,
            filter.Key,
            { r[1] + 4, r[2] + 4, r[3] - 8, r[4] - 12 },
            filters.TextSize,
            Config.White,
            Z + 2,
            { stroke = 2 }
        )
        hitBox(self.canvas, "Filter_" .. filter.Key, r, function()
            self.model.onFilter(filter.Key)
        end, Z + 3)
        x += filter.Width + filters.Gap
    end
end

function IndexComponent.new(panel, layer, model)
    local self = setmetatable({ model = model, search = model.search or "", tweens = {} }, IndexComponent)
    for _, name in { "CleanSkin", "CleanBase", "FigmaWindow" } do
        local child = panel:FindFirstChild(name)
        if child and child:IsA("GuiObject") then
            child.Visible = false
        end
    end
    -- the panel's own Close button becomes an invisible hit-box over the drawn X
    local closeButton = panel:FindFirstChild("Close")
    if closeButton then
        local close = Config.Close
        closeButton.AnchorPoint = Vector2.zero
        closeButton.Position = UDim2.fromScale(close[1] / CANVAS.X, close[2] / CANVAS.Y)
        closeButton.Size = UDim2.fromScale(close[3] / CANVAS.X, close[4] / CANVAS.Y)
        closeButton.BackgroundTransparency = 1
        closeButton.ZIndex = 30
        for _, descendant in closeButton:GetDescendants() do
            if descendant:IsA("GuiObject") then
                descendant.Visible = false
            elseif descendant:IsA("UIStroke") then
                descendant.Enabled = false
            end
        end
        if closeButton:IsA("ImageButton") then
            closeButton.ImageTransparency = 1
        elseif closeButton:IsA("TextButton") then
            closeButton.TextTransparency = 1
        end
    end

    local canvas = new("Frame", "IndexCanvas", nil, Z)
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
    self:_buildSeasons()

    local collection = Config.Collection
    local bar = collection.Bar
    local ratio = math.clamp(model.progress or 0, 0, 1)
    if ratio > 0 then
        local width = ratio >= 1 and bar[3] or math.max(collection.MinFill, math.floor(bar[3] * ratio + 0.5))
        sliced(canvas, "CollectionFill", "BarFill", { bar[1], bar[2], width, bar[4] }, collection.Slice, Z + 1)
    end
    label(canvas, "CollectionText", model.collectionText or "", bar, collection.TextSize, collection.TextColor, Z + 2)

    if model.page ~= "Mutations" then
        self:_buildToolbar()
    end
    local view = Config.Grid.Viewport
    self.grid = new("ScrollingFrame", "Grid", canvas, Z + 1)
    rect(self.grid, view)
    self.grid.ScrollingDirection = Enum.ScrollingDirection.Y
    self.grid.ScrollBarThickness = 6
    self.grid.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 190)
    local height = self:_fillGrid()
    self.grid.CanvasPosition = Vector2.new(0, math.clamp(model.scrollY or 0, 0, math.max(0, height - view[4])))
    self.grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        model.onScroll(self.grid.CanvasPosition.Y)
    end)
    self:_buildDetail()
    self:_buildRewards()
    self:_buildPages()
    canvas.Parent = layer
    return self
end

function IndexComponent:Destroy()
    for _, tween in self.tweens do
        tween:Cancel()
    end
    self.sizeConnection:Disconnect()
    self.canvas:Destroy()
end

return IndexComponent
