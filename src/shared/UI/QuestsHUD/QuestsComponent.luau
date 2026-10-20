-- ReplicatedStorage.QuestsHUD.QuestsComponent  (ModuleScript, client)
-- The collapsible quest tracker. Builds its instances once (rows come from a fixed pool of QuestsConfig.MaxRows)
-- and afterwards only changes text, fill widths, visibility and the collapse tween. Display only: the quest data
-- comes from the server through FigmaSkin's tracker loop (GameMenu GetState "quests").
-- Its ScreenGui uses Sibling ZIndexBehavior: art = ZIndex 1, text / bars / chevron = 2, later rows above earlier.
--
--   QuestsHUD (Frame, UIScale)
--   └── QuestContainer
--       ├── HeaderButton (ImageButton, transparent, covers the header)
--       │   ├── HeaderBackground, TitleText, ChevronIcon
--       └── CollapsibleContent (ClipsDescendants)
--           └── QuestList
--               └── QuestRow1..N: RowBackground, DescriptionText, ProgressTrack > ProgressFill, ProgressText
--
--   local hud = QuestsComponent.new(screenGui)
--   hud:SetQuests({ { id = "place2", title = "Place 2 characters", progress = 1, target = 2 }, ... })
--   hud:UpdateQuest("place2", 2, 2)
--   hud:ToggleExpanded() / hud:SetExpanded(false)
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent:WaitForChild("QuestsConfig"))

local QuestsComponent = {}
QuestsComponent.__index = QuestsComponent

-- reference pixels -> root pixels (keeps TextSize under Roblox's 100 cap; UIScale does the rest)
local U = Config.Unit
local W = Config.Width * U

local function boxPlace(instance, box)
    instance.Position = UDim2.fromOffset(box[1] * U, box[2] * U)
    instance.Size = UDim2.fromOffset(box[3] * U, box[4] * U)
end

local function newFrame(name, parent)
    local frame = Instance.new("Frame")
    frame.Name = name
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.Parent = parent
    return frame
end

-- 9-slice image; sliceScale = how big one image pixel of the border is drawn (root pixels)
local function newSlicedImage(name, asset, sliceCenter, sliceScale, parent)
    local image = Instance.new("ImageLabel")
    image.Name = name
    image.BackgroundTransparency = 1
    image.Image = asset.Image
    image.ScaleType = Enum.ScaleType.Slice
    image.SliceCenter = sliceCenter
    image.SliceScale = sliceScale
    image.Size = UDim2.fromScale(1, 1)
    image.Parent = parent
    return image
end

-- Press Start 2P label with a black pixel outline (copies at the 8 integer offsets, drawn first)
local function newOutlinedText(name, box, alignment, outline, parent)
    local holder = newFrame(name, parent)
    boxPlace(holder, box)
    holder.ZIndex = 2
    local labels = {}
    local offsets = {}
    for dy = -1, 1 do
        for dx = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                table.insert(offsets, Vector2.new(dx * outline * U, dy * outline * U))
            end
        end
    end
    table.insert(offsets, Vector2.zero) -- the white label itself, last = on top (sibling order)
    for index, offset in offsets do
        local label = Instance.new("TextLabel")
        label.Name = index == #offsets and "Text" or "Outline"
        label.BackgroundTransparency = 1
        label.FontFace = Config.Font
        label.TextScaled = true
        label.TextXAlignment = alignment
        label.TextColor3 = index == #offsets and Config.Colors.Text or Config.Colors.Outline
        label.Position = UDim2.fromOffset(offset.X, offset.Y)
        label.Size = UDim2.fromScale(1, 1)
        label.ZIndex = index == #offsets and 2 or 1
        label.Parent = holder
        table.insert(labels, label)
    end
    return {
        Holder = holder,
        Set = function(text)
            if labels[1].Text == text then
                return
            end
            for _, label in labels do
                label.Text = text
            end
        end,
    }
end

local function contentHeight(rowCount)
    if rowCount <= 0 then
        return 0
    end
    local rows = Config.Rows
    return ((rowCount - 1) * rows.Pitch + rows.Height) * U
end

function QuestsComponent:_buildRow(index, parent)
    local rows = Config.Rows
    local rowScale = W / Config.Assets.Row.ImageSize.X
    local row = newFrame("QuestRow" .. index, parent)
    row.Position = UDim2.fromOffset(0, (index - 1) * rows.Pitch * U)
    row.Size = UDim2.fromOffset(W, rows.Height * U)
    row.ZIndex = index -- later rows draw their top border over the previous row's bottom border
    row.Visible = false
    newSlicedImage("RowBackground", Config.Assets.Row, Config.SliceCenter.Row, rowScale, row)
    local description =
        newOutlinedText("DescriptionText", rows.Description, Enum.TextXAlignment.Left, Config.Outline.Description, row)
    local track = newFrame("ProgressTrack", row)
    boxPlace(track, rows.Track)
    track.ZIndex = 2
    newSlicedImage(
        "TrackImage",
        Config.Assets.Track,
        Config.SliceCenter.Track,
        rows.Track[4] * U / Config.Assets.Track.ImageSize.Y,
        track
    )
    -- the fill image keeps its full width inside a clipping frame, so a partial bar is cut off cleanly instead
    -- of squashing the pixel-art end caps
    local fill = newFrame("ProgressFill", track)
    fill.ClipsDescendants = true
    fill.ZIndex = 2 -- over the track art
    fill.Position = UDim2.fromOffset(rows.Fill[1] * U, rows.Fill[2] * U)
    fill.Size = UDim2.fromOffset(0, rows.Fill[4] * U)
    local fillImage = newSlicedImage(
        "FillImage",
        Config.Assets.Fill,
        Config.SliceCenter.Fill,
        rows.Fill[4] * U / Config.Assets.Fill.ImageSize.Y,
        fill
    )
    fillImage.Size = UDim2.fromOffset(rows.Fill[3] * U, rows.Fill[4] * U)
    local count = newOutlinedText("ProgressText", rows.Count, Enum.TextXAlignment.Right, Config.Outline.Count, row)
    return { Frame = row, Description = description, Fill = fill, Count = count, Ratio = nil, QuestId = nil }
end

function QuestsComponent.new(parent)
    local self = setmetatable({}, QuestsComponent)
    local headerConfig = Config.Header
    local root = newFrame("QuestsHUD", nil)
    root.Size = UDim2.fromOffset(W, headerConfig.Height * U)
    self.Scale = Instance.new("UIScale")
    self.Scale.Parent = root
    local container = newFrame("QuestContainer", root)
    container.Size = UDim2.fromScale(1, 1)

    -- the whole header is the toggle; its art sits inside the transparent button
    local header = Instance.new("ImageButton")
    header.Name = "HeaderButton"
    header.BackgroundTransparency = 1
    header.ImageTransparency = 1
    header.AutoButtonColor = false
    header.Size = UDim2.fromOffset(W, headerConfig.Height * U)
    header.Parent = container
    newSlicedImage(
        "HeaderBackground",
        Config.Assets.Header,
        Config.SliceCenter.Header,
        W / Config.Assets.Header.ImageSize.X,
        header
    )
    local title =
        newOutlinedText("TitleText", headerConfig.Title, Enum.TextXAlignment.Left, Config.Outline.Title, header)
    title.Set("QUESTS")
    local chevron = Instance.new("ImageLabel")
    chevron.Name = "ChevronIcon"
    chevron.BackgroundTransparency = 1
    chevron.Image = Config.Assets.Chevron
    chevron.ScaleType = Enum.ScaleType.Fit
    boxPlace(chevron, headerConfig.Chevron)
    chevron.ZIndex = 2
    chevron.Parent = header

    -- rows live below the header; the clip frame's height is what collapses
    local content = newFrame("CollapsibleContent", container)
    content.ClipsDescendants = true
    content.Position = UDim2.fromOffset(0, Config.Rows.Top * U)
    content.Size = UDim2.fromOffset(W, 0)
    content.ZIndex = 2
    local list = newFrame("QuestList", content)
    list.Size = UDim2.fromOffset(W, contentHeight(Config.MaxRows))
    self.Rows = {}
    for index = 1, Config.MaxRows do
        self.Rows[index] = self:_buildRow(index, list)
    end

    self.Root, self.Header, self.Chevron, self.Content = root, header, chevron, content
    self.IsExpanded = true
    self.RowCount = 0
    self.Tweens = {}
    header.Activated:Connect(function()
        self:ToggleExpanded()
    end)
    self:_applyHeight(false)
    root.Parent = parent
    return self
end

-- Root and clip heights for the current state; animated = tween, else snap. A running tween is replaced.
function QuestsComponent:_applyHeight(animated)
    local rowsHeight = self.IsExpanded and contentHeight(self.RowCount) or 0
    local rootHeight = rowsHeight > 0 and Config.Rows.Top * U + rowsHeight or Config.Header.Height * U
    local goals = {
        [self.Content] = { Size = UDim2.fromOffset(W, rowsHeight) },
        [self.Root] = { Size = UDim2.fromOffset(W, rootHeight) },
        [self.Chevron] = { Rotation = self.IsExpanded and 0 or 180 }, -- down = expanded, up = collapsed
    }
    for instance, goal in goals do
        if self.Tweens[instance] then
            self.Tweens[instance]:Cancel()
            self.Tweens[instance] = nil
        end
        if animated then
            local tween = TweenService:Create(
                instance,
                TweenInfo.new(Config.CollapseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                goal
            )
            self.Tweens[instance] = tween
            tween:Play()
        else
            for property, value in goal do
                instance[property] = value
            end
        end
    end
end

function QuestsComponent:SetExpanded(expanded)
    if self.IsExpanded == expanded then
        return
    end
    self.IsExpanded = expanded
    self:_applyHeight(true)
end

function QuestsComponent:ToggleExpanded()
    self:SetExpanded(not self.IsExpanded)
end

function QuestsComponent:_setRow(row, current, target)
    local ratio = math.clamp(current / math.max(target, 1), 0, 1)
    row.Count.Set(string.format("%s/%s", QuestsComponent.FormatCount(current), QuestsComponent.FormatCount(target)))
    if row.Ratio == ratio then
        return
    end
    local goal = { Size = UDim2.fromOffset(Config.Rows.Fill[3] * U * ratio, Config.Rows.Fill[4] * U) }
    if row.FillTween then
        row.FillTween:Cancel()
    end
    if row.Ratio == nil then -- first value for this row: no animation
        row.Fill.Size = goal.Size
    else
        row.FillTween = TweenService:Create(row.Fill, TweenInfo.new(Config.FillTime, Enum.EasingStyle.Quad), goal)
        row.FillTween:Play()
    end
    row.Ratio = ratio
end

-- 1500 -> "1.5K" (truncated), small numbers as they are
function QuestsComponent.FormatCount(amount)
    amount = math.floor(amount)
    for _, unit in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
        if amount >= unit[1] then
            return string.format("%g", math.floor(amount / unit[1] * 10) / 10) .. unit[2]
        end
    end
    return tostring(amount)
end

-- Shows these quests (in order, at most MaxRows): { { id, title, progress, target }, ... }. Rows are reused;
-- a row keeps its fill when the same quest stays in the same slot, so progress animates instead of jumping.
function QuestsComponent:SetQuests(quests)
    local count = math.min(#quests, Config.MaxRows)
    for index, row in self.Rows do
        local quest = quests[index]
        if index <= count and quest then
            if row.QuestId ~= quest.id then
                row.QuestId = quest.id
                row.Ratio = nil
            end
            row.Description.Set(quest.title or "")
            self:_setRow(row, quest.progress or 0, quest.target or 1)
            row.Frame.Visible = true
        else
            row.QuestId = nil
            row.Ratio = nil
            row.Frame.Visible = false
        end
    end
    if count ~= self.RowCount then
        self.RowCount = count
        self:_applyHeight(true)
    end
end

-- Updates one shown quest's progress (no-op if it is not shown).
function QuestsComponent:UpdateQuest(questId, current, target)
    for _, row in self.Rows do
        if row.QuestId == questId then
            self:_setRow(row, current, target)
            return
        end
    end
end

function QuestsComponent:SetVisible(visible)
    self.Root.Visible = visible
end

function QuestsComponent:Destroy()
    self.Root:Destroy()
end

return QuestsComponent
