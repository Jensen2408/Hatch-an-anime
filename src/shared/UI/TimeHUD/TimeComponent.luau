-- ReplicatedStorage.TimeHUD.TimeComponent  (ModuleScript, client)
-- The Day / Night event HUD. Builds both mode trees once; afterwards only text and visibility change.
-- Display only: it knows nothing about the night cycle. GameHUD (section 9) feeds it the server's state.
--
--   TimeHUD (Frame, UIScale)
--   ├── DayEventHUD / NightEventHUD (one visible at a time)
--   │   ├── MainPanel
--   │   │   ├── DayCardTop / NightCardTop (ImageLabel, 9-slice)
--   │   │   ├── LeftSunIcon / LeftMoonIcon
--   │   │   ├── CountdownText (TextLabel + outline copies)
--   │   │   └── RightSunIcon / RightMoonIcon
--   │   └── MultiplierPanel
--   │       ├── MultiplierBackground (DAY-CARD / NIGHT-CARD, 9-slice)
--   │       └── MultiplierContent (UIListLayout)
--   │           ├── CashMultiplier, Separator1, HatchMultiplier, Separator2, LuckMultiplier
--
--   local hud = TimeComponent.new(screenGui)
--   hud:SetMode("Night")                 -- "Day" | "Night"
--   hud:SetRemainingTime(248)            --> "NIGHT EVENT IN 04:08"
--   hud:SetMultipliers({ Cash = 3, Hatch = 2, Luck = 3 })
--   hud:SetVisible(true)
local TextService = game:GetService("TextService")

local Config = require(script.Parent:WaitForChild("TimeConfig"))

local TimeComponent = {}
TimeComponent.__index = TimeComponent

-- "MM:SS", rounded up, never negative
function TimeComponent.FormatClock(seconds)
    seconds = math.max(0, math.ceil(seconds))
    return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

-- 3 -> "3x", 1.5 -> "1.5x"
local function formatMultiplier(value)
    return (value % 1 == 0 and string.format("%d", value) or string.format("%.1f", value)) .. "x"
end

-- Converts a reference-pixel box into Position / Size scales inside `parentBox` (both in the same reference).
local function place(instance, box, parentBox)
    instance.Position = UDim2.fromScale((box[1] - parentBox[1]) / parentBox[3], (box[2] - parentBox[2]) / parentBox[4])
    instance.Size = UDim2.fromScale(box[3] / parentBox[3], box[4] / parentBox[4])
end

local function newFrame(name, parent)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.BackgroundTransparency = 1
    frame.Parent = parent
    return frame
end

local function newImage(name, image, zIndex, parent)
    local label = Instance.new("ImageLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Image = image
    label.ScaleType = Enum.ScaleType.Fit -- icons keep their aspect ratio
    label.ResampleMode = Enum.ResamplerMode.Pixelated
    label.ZIndex = zIndex
    label.Parent = parent
    return label
end

-- 9-slice card filling its parent; `heightPx` = the card's height in root pixels, so the border pixels are
-- drawn at the same scale as the reference and only the flat middle stretches.
local function newCard(name, cardConfig, heightPx, zIndex, parent)
    local label = newImage(name, cardConfig.Image, zIndex, parent)
    label.Size = UDim2.fromScale(1, 1)
    label.ScaleType = Enum.ScaleType.Slice
    label.SliceCenter = cardConfig.SliceCenter
    label.SliceScale = heightPx / cardConfig.ImageSize.Y
    return label
end

-- A Press Start 2P label with a pixel outline: black copies at the 8 integer offsets (and the same row again
-- `depth` px lower), a `depthColor` copy `depth` px lower, then the label itself on top.
local function newOutlinedText(name, color, depthColor, outline, zIndex, parent)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.FontFace = Config.Font
    label.TextColor3 = color
    label.ZIndex = zIndex
    label.Parent = parent
    local thickness, depth = outline.Thickness, outline.Depth
    local layers = {}
    local function addCopy(offset, copyColor, copyZIndex)
        local copy = Instance.new("TextLabel")
        copy.Name = "Outline"
        copy.BackgroundTransparency = 1
        copy.FontFace = Config.Font
        copy.TextColor3 = copyColor
        copy.Position = UDim2.fromOffset(offset.X, offset.Y)
        copy.Size = UDim2.fromScale(1, 1)
        copy.ZIndex = copyZIndex
        copy.Parent = label
        table.insert(layers, copy)
    end
    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                addCopy(Vector2.new(dx * thickness, dy * thickness), Config.Colors.Outline, zIndex - 2)
            end
        end
    end
    if depth > 0 then
        for dx = -1, 1 do
            addCopy(Vector2.new(dx * thickness, thickness + depth), Config.Colors.Outline, zIndex - 2)
        end
        addCopy(Vector2.new(0, depth), depthColor, zIndex - 1)
    end
    return { Label = label, Layers = layers }
end

-- applies `apply(textLabel)` to a label and all of its outline layers
local function eachLayer(text, apply)
    apply(text.Label)
    for _, layer in text.Layers do
        apply(layer)
    end
end

-- returns whether the text changed
local function setText(text, value)
    if text.Label.Text == value then
        return false
    end
    eachLayer(text, function(label)
        label.Text = value
    end)
    return true
end

function TimeComponent:_buildMode(modeName)
    local mode = Config.Modes[modeName]
    local rootPx = Config.RootSize
    local toRootPx = rootPx.X / mode.RefWidth -- reference pixels -> root pixels
    local rootBox = { 0, 0, mode.RefWidth, rootPx.Y / toRootPx }
    local boxes = mode.Boxes
    local z = Config.ZIndex

    local hud = newFrame(modeName .. "EventHUD", self.Root)
    hud.Size = UDim2.fromScale(1, 1)
    hud.Visible = false

    local mainPanel = newFrame("MainPanel", hud)
    place(mainPanel, boxes.MainPanel, rootBox)
    newCard(modeName .. "CardTop", mode.MainCard, boxes.MainPanel[4] * toRootPx, z.MainCard, mainPanel)
    local leftIcon = newImage(mode.IconNames[1], mode.LeftIcon, z.Icon, mainPanel)
    place(leftIcon, boxes.LeftIcon, boxes.MainPanel)
    local countdown =
        newOutlinedText("CountdownText", Config.Colors.Title, mode.TitleDepth, Config.Outline.Title, z.Title, mainPanel)
    place(countdown.Label, boxes.CountdownText, boxes.MainPanel)
    eachLayer(countdown, function(label)
        label.TextScaled = true -- fits the title box without clipping
    end)
    local rightIcon = newImage(mode.IconNames[2], mode.RightIcon, z.Icon, mainPanel)
    place(rightIcon, boxes.RightIcon, boxes.MainPanel)

    local multiplierPanel = newFrame("MultiplierPanel", hud)
    place(multiplierPanel, boxes.MultiplierPanel, rootBox)
    multiplierPanel.Visible = mode.ShowMultipliers ~= false
    newCard(
        "MultiplierBackground",
        mode.MultiplierCard,
        boxes.MultiplierPanel[4] * toRootPx,
        z.MultiplierCard,
        multiplierPanel
    )
    local content = newFrame("MultiplierContent", multiplierPanel)
    place(content, boxes.MultiplierContent, boxes.MultiplierPanel)
    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = content

    local multipliers, separators = {}, {}
    for index, spec in Config.Multipliers do
        if index > 1 then
            local separator = newImage("Separator" .. (index - 1), mode.Separator, z.Separator, content)
            separator.LayoutOrder = index * 2 - 1
            table.insert(separators, separator)
        end
        local text = newOutlinedText(
            spec.Name,
            spec.Color,
            Config.MultiplierDepth[spec.Key],
            Config.Outline.Multiplier,
            z.Multiplier,
            content
        )
        text.Label.LayoutOrder = index * 2
        text.Label.Size = UDim2.fromScale(0, 1) -- width set by _layoutRow
        multipliers[spec.Key] = text
    end

    local separatorSize = mode.SeparatorSize * toRootPx
    layout.Padding = UDim.new(0, mode.Gap * toRootPx)
    for _, separator in separators do
        separator.Size = UDim2.fromOffset(separatorSize, separatorSize)
    end
    return {
        Hud = hud,
        Mode = mode,
        Countdown = countdown,
        Multipliers = multipliers,
        ContentWidth = boxes.MultiplierContent[3] * toRootPx,
        SeparatorWidth = separatorSize * #separators,
        ToRootPx = toRootPx,
        LayoutVersion = 0,
    }
end

-- Sizes the multiplier labels so the row (text + separators + gaps) fills MultiplierContent's width. Each label
-- gets a share of the free width in proportion to its text (measured with TextService), and its text is
-- TextScaled inside that box, so it can never spill onto a separator at any UIScale. Separators and gaps keep
-- their reference size. Root pixels throughout; TextService yields, so the newest call wins.
function TimeComponent:_layoutRow(state)
    state.LayoutVersion += 1
    local version = state.LayoutVersion
    task.spawn(function()
        local mode = state.Mode
        local maxSize = mode.MaxTextSize * state.ToRootPx
        local outlinePad = Config.Outline.Multiplier.Thickness * 2
        local widths, total = {}, 0
        for key, text in state.Multipliers do
            local params = Instance.new("GetTextBoundsParams")
            params.Text = text.Label.Text
            params.Font = Config.Font
            params.Size = maxSize
            params.Width = math.huge
            local ok, bounds = pcall(TextService.GetTextBoundsAsync, TextService, params)
            widths[key] = ok and bounds.X or #params.Text * maxSize
            total += widths[key]
        end
        if version ~= state.LayoutVersion or total <= 0 then
            return
        end
        local gaps = mode.Gap * state.ToRootPx * (#Config.Multipliers * 2 - 2)
        local free = state.ContentWidth - state.SeparatorWidth - gaps - outlinePad * #Config.Multipliers
        local textWidth = math.min(free, total) -- never wider than the text at MaxTextSize
        for key, text in state.Multipliers do
            eachLayer(text, function(label)
                label.TextScaled = true
            end)
            text.Label.Size = UDim2.new(0, widths[key] / total * textWidth + outlinePad, 1, 0)
        end
    end)
end

function TimeComponent.new(parent)
    local self = setmetatable({}, TimeComponent)
    local root = newFrame("TimeHUD", nil)
    root.Size = UDim2.fromOffset(Config.RootSize.X, Config.RootSize.Y)
    self.Root = root
    self.Scale = Instance.new("UIScale")
    self.Scale.Parent = root
    self.Modes = { Day = self:_buildMode("Day"), Night = self:_buildMode("Night") }
    self.RemainingTime = 0
    self.MultiplierValues = { Cash = 1, Hatch = 1, Luck = 1 }
    self:SetMode("Night")
    root.Parent = parent
    return self
end

-- Writes the countdown and multiplier text of the visible mode (unchanged text is skipped).
function TimeComponent:_refresh()
    local state = self.Modes[self.ModeName]
    setText(state.Countdown, state.Mode.TitlePrefix .. TimeComponent.FormatClock(self.RemainingTime))
    local multipliersChanged = false
    for _, spec in Config.Multipliers do
        local value = self.MultiplierValues[spec.Key] or 1
        multipliersChanged = setText(state.Multipliers[spec.Key], formatMultiplier(value) .. " " .. spec.Label)
            or multipliersChanged
    end
    if multipliersChanged then
        self:_layoutRow(state)
    end
end

function TimeComponent:SetMode(modeName)
    assert(Config.Modes[modeName], 'TimeComponent:SetMode expects "Day" or "Night"')
    if modeName == self.ModeName then
        return
    end
    self.ModeName = modeName
    for name, state in self.Modes do
        state.Hud.Visible = name == modeName
    end
    self:_refresh()
end

function TimeComponent:SetRemainingTime(seconds)
    self.RemainingTime = seconds
    self:_refresh()
end

function TimeComponent:SetMultipliers(values)
    for key, value in values do
        self.MultiplierValues[key] = value
    end
    self:_refresh()
end

function TimeComponent:SetVisible(visible)
    self.Root.Visible = visible
end

function TimeComponent:Destroy()
    self.Root:Destroy()
end

return TimeComponent
