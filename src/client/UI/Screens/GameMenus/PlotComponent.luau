-- GameMenus.PlotComponent  (ModuleScript, client)
-- Draws the Plot menu (Figma "03 Plot") from a view model with the StudUI kit. Display only: MenuLogic
-- (RENDER.Plot) reads the plot state, formats every value and passes the actions as callbacks.
--
--   StudCanvas (1160x730, UIScale = panel width / 1160)
--   ├── Shadow, Plate, Header (+ Close art)  Panel + Header/red
--   ├── Stat1..3                             Stat
--   ├── SlotsTab, UpgradesTab, EquipBestButton
--   ├── Content (ScrollingFrame)             slot cells, or one row per incubator
--   ├── TempleUpgrades, IncubatorSpeed, IncubatorUpgrades   UpgradeRow (names used by FirstHatchTutorial)
--   └── SlotsText, SlotsProgress, Milestone
--
--   local view = PlotComponent.new(panel, layer, model)   -- builds into `layer`
--   view:Destroy()
--
-- model = {
--   tab = "slots" | "upgrades", scrollY = number?,
--   stats = { { label, value } x3 },
--   slots = { { number, state = "placed" | "empty" | "locked", image?, name?, income?, price?, onActivate? } },
--   slotsText, slotsProgress (0..1),
--   upgrades = { { name, title, subtitle, price, enabled, onActivate } x3 },
--   incubators = { { title, subtitle, progress, price, enabled, onActivate } },
--   milestone = { text, enabled, onActivate? },
--   onTab(tab), onEquipBest(), onScroll(y),
-- }
local Kit = game:GetService("ReplicatedStorage"):WaitForChild("StudKit")
local Config = require(script.Parent:WaitForChild("PlotConfig"))
local StudUI = require(Kit:WaitForChild("StudUI"))
local Theme = require(Kit:WaitForChild("StudTheme"))

local Colors = Theme.Colors
local label, centered = StudUI.label, StudUI.centered

local PlotComponent = {}
PlotComponent.__index = PlotComponent

-- Figma "Stat": muted label + green value
function PlotComponent:_buildStats()
    local stats = Config.Stats
    for i, stat in self.model.stats do
        local tile = StudUI.card(
            self.canvas,
            "Stat" .. i,
            { stats.Xs[i], stats.Y, stats.Width, stats.Height },
            Colors.Panel2,
            stats.Radius,
            Colors.Ink,
            nil,
            self.zContent
        )
        label(tile, "Label", stat[1], stats.LabelRect, stats.LabelSize, Colors.Muted)
        label(tile, "Value", stat[2], stats.ValueRect, stats.ValueSize, Colors.Green, { display = true })
    end
end

-- One slot cell: CharacterCard when a character is placed, otherwise number + EMPTY / lock + price.
-- The next slot to buy is a gold-bordered button.
function PlotComponent:_slotCell(parent, slot, x, y)
    local grid = Config.SlotGrid
    local cell = StudUI.card(
        parent,
        string.format("Slot%02d", slot.number),
        { x, y, grid.CellSize.X, grid.CellSize.Y },
        Colors.Panel2,
        grid.Radius,
        slot.onActivate and Colors.Gold or Colors.Muted,
        slot.onActivate
    )
    if slot.state == "placed" then
        if slot.image and slot.image ~= "" then
            local portrait = Instance.new("ImageLabel")
            portrait.Name = "Portrait"
            portrait.BackgroundTransparency = 1
            portrait.Image = slot.image
            portrait.ScaleType = Enum.ScaleType.Fit
            portrait.ZIndex = cell.ZIndex + 1
            StudUI.rect(portrait, grid.ImageRect)
            portrait.Parent = cell
        end
        StudUI.plate(cell, "NameStrip", grid.StripRect, Colors.Ink, grid.StripRadius)
        label(cell, "Name", slot.name or "", grid.NameRect, grid.NameSize, Colors.White, centered({ display = true }))
        label(cell, "Income", slot.income or "", grid.IncomeRect, grid.IncomeSize, Colors.Green, centered())
    else
        label(cell, "Number", tostring(slot.number), grid.NumberRect, grid.NumberSize, Colors.White)
        if slot.state == "empty" then
            label(cell, "Empty", "EMPTY", grid.EmptyRect, grid.EmptySize, Colors.Muted, centered())
        else
            label(cell, "Lock", "🔒", grid.LockRect, grid.LockSize, Colors.White, centered())
            label(cell, "Price", slot.price or "", grid.PriceRect, grid.PriceSize, Colors.Gold, centered())
        end
    end
    return cell
end

-- Upgrades tab row (UpgradeRow art, full column width): title, subtitle, level bar, price button
function PlotComponent:_incubatorRow(parent, i, row, y, width, height)
    local style = Config.IncubatorRow
    local frame =
        StudUI.card(parent, "Incubator" .. i, { 0, y, width, height }, Colors.Panel2, style.Radius, Colors.Ink)
    label(frame, "Title", row.title, style.TitleRect, style.TitleSize, Colors.White)
    label(frame, "Subtitle", row.subtitle, style.SubtitleRect, style.SubtitleSize, Colors.Muted)
    StudUI.progress(frame, "Level", style.ProgressRect, row.progress)
    local button = style.Button
    StudUI.button(
        frame,
        "Buy",
        { width - button.Right - button.Width, (height - button.Height) / 2, button.Width, button.Height },
        Colors.Green,
        row.price,
        { enabled = row.enabled, onActivate = row.onActivate }
    )
end

-- Left column: scrolling slot grid (Character Slots tab) or the incubator rows (Upgrades tab)
function PlotComponent:_buildContent()
    local content = Config.Content
    local r = content.Rect
    local scroller = StudUI.scroller(self.canvas, "Content", r, self.zContent)

    local height
    if self.model.tab == "upgrades" then
        local rows = Config.IncubatorRows
        for i, row in self.model.incubators do
            self:_incubatorRow(scroller, i, row, (i - 1) * (rows.Height + rows.Gap), r[3], rows.Height)
        end
        height = #self.model.incubators * (rows.Height + rows.Gap) - rows.Gap
    else
        local grid = Config.SlotGrid
        local stepX, stepY = grid.CellSize.X + grid.Gap.X, grid.CellSize.Y + grid.Gap.Y
        for i, slot in self.model.slots do
            local column, row = (i - 1) % grid.Columns, (i - 1) // grid.Columns
            self:_slotCell(scroller, slot, column * stepX, row * stepY)
        end
        height = math.ceil(#self.model.slots / grid.Columns) * stepY - grid.Gap.Y
    end
    height = math.max(height, 0)
    StudUI.setScrollHeight(scroller, height)
    scroller.CanvasPosition = Vector2.new(0, math.clamp(self.model.scrollY or 0, 0, math.max(0, height - r[4])))
    scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
        self.model.onScroll(scroller.CanvasPosition.Y)
    end)
end

-- Right column: Figma "UpgradeRow" x3
function PlotComponent:_buildUpgrades()
    local rows = Config.UpgradeRows
    local button = rows.Button
    for i, row in self.model.upgrades do
        local frame = StudUI.card(
            self.canvas,
            row.name,
            { rows.X, rows.Ys[i], rows.Width, rows.Height },
            Colors.Panel2,
            rows.Radius,
            Colors.Ink,
            nil,
            self.zContent
        )
        label(frame, "Title", row.title, rows.TitleRect, rows.TitleSize, Colors.White)
        label(frame, "Subtitle", row.subtitle, rows.SubtitleRect, rows.SubtitleSize, Colors.Muted, {
            wrap = true,
            alignY = Enum.TextYAlignment.Top,
        })
        StudUI.button(frame, "Buy", {
            rows.Width - button.Right - button.Width,
            rows.Height - button.Bottom - button.Height,
            button.Width,
            button.Height,
        }, Colors.Green, row.price, { enabled = row.enabled, onActivate = row.onActivate })
    end
end

function PlotComponent:_buildFooter()
    local footer = Config.Footer
    label(self.canvas, "SlotsText", self.model.slotsText, footer.TextRect, footer.TextSize, Colors.White, {
        zIndex = self.zContent,
    })
    StudUI.progress(self.canvas, "SlotsProgress", footer.ProgressRect, self.model.slotsProgress, nil, self.zContent)

    -- Milestone: gold plate; a button while there is something to buy
    local milestone = footer.Milestone
    local model = self.model.milestone
    local r = milestone.Rect
    local plate = StudUI.card(
        self.canvas,
        "Milestone",
        r,
        model.enabled and Colors.Gold or Colors.Disabled,
        milestone.Radius,
        Colors.Ink,
        model.onActivate,
        self.zContent
    )
    label(
        plate,
        "Label",
        model.text,
        { 12, 9, r[3] - 24, r[4] - 18 },
        milestone.TextSize,
        model.enabled and Colors.Ink or Colors.White,
        centered()
    )
end

function PlotComponent.new(panel, layer, model)
    local self = setmetatable({ model = model }, PlotComponent)
    self.canvas, self.stopCanvas = StudUI.newCanvas(panel, layer)
    self.zContent = StudUI.shell(self.canvas, Colors.Red, Config.Title)
    self:_buildStats()
    local tabs = Config.Tabs
    StudUI.tab(
        self.canvas,
        "SlotsTab",
        { tabs.Slots.X, tabs.Y, tabs.Slots.Width, tabs.Height },
        tabs.Slots.Label,
        model.tab ~= "upgrades",
        function()
            model.onTab("slots")
        end,
        self.zContent
    )
    StudUI.tab(
        self.canvas,
        "UpgradesTab",
        { tabs.Upgrades.X, tabs.Y, tabs.Upgrades.Width, tabs.Height },
        tabs.Upgrades.Label,
        model.tab == "upgrades",
        function()
            model.onTab("upgrades")
        end,
        self.zContent
    )
    StudUI.button(
        self.canvas,
        "EquipBestButton",
        { tabs.EquipBest.X, tabs.Y, tabs.EquipBest.Width, tabs.Height },
        Colors.Blue,
        tabs.EquipBest.Label,
        { onActivate = model.onEquipBest, zIndex = self.zContent }
    )
    self:_buildContent()
    self:_buildUpgrades()
    self:_buildFooter()
    return self
end

function PlotComponent:Destroy()
    self.stopCanvas()
    self.canvas:Destroy()
end

return PlotComponent
