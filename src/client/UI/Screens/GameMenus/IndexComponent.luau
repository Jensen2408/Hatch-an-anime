-- GameMenus.IndexComponent  (ModuleScript, client)
-- Draws the Index menu (Figma "02 Index") from a view model with the StudKit pieces. Display only: MenuLogic
-- (RENDER.Index) reads the catalog / discovered state and passes the actions as callbacks. Typing in the
-- search box filters the grid here, without a re-render.
--
--   StudCanvas
--   ├── Shadow, Plate, Header (+ Close art)      Panel + Header/orange
--   ├── Season_<key> x3                          Tab/Selected, Tab/Default (+ LIVE badge)
--   ├── CollectionText, Timer, Progress          collection count, event countdown
--   ├── Search, Filter_<rarity>                  Input, Tab x6
--   ├── Grid (ScrollingFrame)                    CharacterCard / LockedCard
--   └── Detail                                   selected character
--
-- model = {
--   title, seasons = { { key, label, selected, live?, onActivate } }, collectionText, progress (0..1),
--   timerEndsAt? (os.time), filters = { { key, label, selected } }, onFilter(key), search, onSearch(text),
--   characters = { { id, name, rarity, rarityColor, image, discovered, selected } }, onSelect(id),
--   selected = { name, rarity, rarityColor, image, status, statusColor, obtain }?, scrollY, onScroll(y),
-- }
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = ReplicatedStorage:WaitForChild("StudKit")
local StudUI = require(Kit:WaitForChild("StudUI"))
local Theme = require(Kit:WaitForChild("StudTheme"))
local Config = require(script.Parent:WaitForChild("IndexConfig"))

local Colors = Theme.Colors
local label, centered = StudUI.label, StudUI.centered

local IndexComponent = {}
IndexComponent.__index = IndexComponent

local function portrait(parent, image, r, silhouette)
    if not image or image == "" then
        return
    end
    local picture = Instance.new("ImageLabel")
    picture.Name = "Portrait"
    picture.BackgroundTransparency = 1
    picture.Image = image
    picture.ScaleType = Enum.ScaleType.Fit
    if silhouette then
        picture.ImageColor3 = Color3.new(0, 0, 0)
        picture.ImageTransparency = 0.15
    end
    picture.ZIndex = parent.ZIndex + 1
    StudUI.rect(picture, r)
    picture.Parent = parent
end

-- 12d 04:05:06 / 04:05:06
local function formatCountdown(seconds)
    seconds = math.max(0, math.floor(seconds))
    local days = seconds // 86400
    return (days > 0 and (days .. "d ") or "")
        .. string.format("%02d:%02d:%02d", (seconds // 3600) % 24, (seconds // 60) % 60, seconds % 60)
end

-- CharacterCard (discovered, selectable) or LockedCard (silhouette + ???)
function IndexComponent:_cell(parent, character, x, y)
    local grid = Config.Grid
    local r = { x, y, grid.CellSize.X, grid.CellSize.Y }
    local cell, stroke
    if character.discovered then
        cell, stroke = StudUI.card(
            parent,
            "Card_" .. character.id,
            r,
            Colors.Panel2,
            grid.Radius,
            character.selected and Colors.Gold or Colors.Muted,
            function()
                self.model.onSelect(character.id)
            end
        )
        if character.selected then
            stroke.Thickness = grid.SelectedBorder
        end
    else
        cell = StudUI.card(parent, "Locked_" .. character.id, r, Colors.Panel, grid.Radius, Colors.Muted)
    end
    portrait(cell, character.image, grid.ImageRect, not character.discovered)
    StudUI.plate(cell, "NameStrip", grid.StripRect, Colors.Ink, grid.StripRadius)
    label(
        cell,
        "Name",
        character.discovered and character.name or "???",
        grid.NameRect,
        grid.NameSize,
        Colors.White,
        centered({ display = true })
    )
    label(
        cell,
        "Rarity",
        string.upper(character.rarity or ""),
        grid.RarityRect,
        grid.RaritySize,
        character.rarityColor,
        centered()
    )
end

-- Grid cells for the characters whose name contains the search text (case-insensitive)
function IndexComponent:_fillGrid()
    local grid, scroller = Config.Grid, self.grid
    for _, child in scroller:GetChildren() do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
    local needle = string.lower(self.search)
    local shown = 0
    local stepX, stepY = grid.CellSize.X + grid.Gap.X, grid.CellSize.Y + grid.Gap.Y
    for _, character in self.model.characters do
        -- undiscovered names stay hidden, so they never match a search
        local haystack = character.discovered and string.lower(character.name) or ""
        if needle == "" or string.find(haystack, needle, 1, true) then
            local column, row = shown % grid.Columns, shown // grid.Columns
            self:_cell(scroller, character, column * stepX, row * stepY)
            shown += 1
        end
    end
    if shown == 0 then
        label(scroller, "Empty", "No characters found", grid.EmptyRect, grid.EmptySize, Colors.Muted, centered())
    end
    local height = math.max(0, math.ceil(shown / grid.Columns) * stepY - grid.Gap.Y)
    StudUI.setScrollHeight(scroller, height)
    return height
end

function IndexComponent:_buildDetail()
    local style, selected = Config.Detail, self.model.selected
    local card =
        StudUI.card(self.canvas, "Detail", style.Rect, Colors.Purple, style.Radius, Colors.Muted, nil, self.zContent)
    if not selected then
        label(
            card,
            "Empty",
            "Hatch eggs to discover characters!",
            style.EmptyRect,
            style.EmptySize,
            Colors.White,
            centered({
                display = true,
                wrap = true,
            })
        )
        return
    end
    local stage = StudUI.plate(card, "Stage", style.ImageRect, Colors.Ink, 8)
    portrait(stage, selected.image, { 0, 0, style.ImageRect[3], style.ImageRect[4] })
    StudUI.badge(
        card,
        "Rarity",
        style.BadgeRect,
        string.upper(selected.rarity or "?"),
        selected.rarityColor,
        card.ZIndex + 4
    )
    label(card, "Name", selected.name, style.NameRect, style.NameSize, Colors.White, centered({ display = true }))
    label(card, "Status", selected.status, style.StatusRect, style.StatusSize, selected.statusColor, centered())
    label(card, "Obtain", selected.obtain or "", style.ObtainRect, style.ObtainSize, Colors.Muted, centered())
end

function IndexComponent.new(panel, layer, model)
    local self = setmetatable({ model = model, search = model.search or "", alive = true }, IndexComponent)
    self.canvas, self.stopCanvas = StudUI.newCanvas(panel, layer)
    self.zContent = StudUI.shell(self.canvas, Colors.Orange, model.title)
    local z = self.zContent

    local tabs = Config.SeasonTabs
    for i, season in model.seasons do
        local tab = StudUI.tab(
            self.canvas,
            "Season_" .. season.key,
            { tabs.Xs[i], tabs.Y, tabs.Width, tabs.Height },
            season.label,
            season.selected,
            season.onActivate,
            z
        )
        if season.live then
            StudUI.badge(tab, "Live", tabs.LiveBadge, "LIVE", Colors.Red, tab.ZIndex + 4)
        end
    end

    local collection = Config.Collection
    label(self.canvas, "CollectionText", model.collectionText, collection.TextRect, collection.TextSize, Colors.White, {
        display = true,
        zIndex = z,
    })
    StudUI.progress(self.canvas, "Progress", collection.ProgressRect, model.progress, nil, z)
    if model.timerEndsAt then
        local timer = label(self.canvas, "Timer", "", collection.TimerRect, collection.TimerSize, Colors.Gold, {
            display = true,
            align = Enum.TextXAlignment.Right,
            zIndex = z,
        })
        local function update()
            timer.Text = "ENDS IN " .. formatCountdown(model.timerEndsAt - os.time())
        end
        update()
        task.spawn(function()
            while self.alive do
                task.wait(1)
                if self.alive then
                    update()
                end
            end
        end)
    end

    local search = Config.Search
    local box = StudUI.input(self.canvas, "Search", search.Rect, {
        placeholder = search.Placeholder,
        maxLength = search.MaxLength,
        zIndex = z,
    })
    box.Text = self.search

    local filters = Config.Filters
    local x = filters.X
    for i, filter in model.filters do
        local width = filters.Widths[i]
        local tab = StudUI.tab(
            self.canvas,
            "Filter_" .. filter.key,
            { x, filters.Y, width, filters.Height },
            filter.label,
            filter.selected,
            function()
                model.onFilter(filter.key)
            end,
            z
        )
        tab.Label:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = filters.LabelSize
        x += width + filters.Gap
    end

    local grid = Config.Grid
    local r = grid.Rect
    self.grid = StudUI.scroller(self.canvas, "Grid", r, z)
    local height = self:_fillGrid()
    self.grid.CanvasPosition = Vector2.new(0, math.clamp(model.scrollY or 0, 0, math.max(0, height - r[4])))
    self.grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        model.onScroll(self.grid.CanvasPosition.Y)
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if box.Text ~= self.search then
            self.search = box.Text
            model.onSearch(box.Text)
            self:_fillGrid()
        end
    end)

    self:_buildDetail()
    return self
end

function IndexComponent:Destroy()
    self.alive = false
    self.stopCanvas()
    self.canvas:Destroy()
end

return IndexComponent
